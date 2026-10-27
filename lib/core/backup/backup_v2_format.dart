import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_crypto.dart';
import 'backup_file_save_service.dart';
import 'backup_payload.dart';
import 'backup_unavailable_attachment.dart';

/// V2 流式备份容器异常。
///
/// 异常文本只能用于脱敏的用户反馈；不得拼接密码、密钥、路径、附件名或载荷内容。
class BackupV2FormatException implements Exception {
  final BackupV2FormatErrorType type;
  final String message;
  final List<BackupUnavailableAttachment> unavailableAttachments;
  final Set<String> checkedAttachmentIds;

  const BackupV2FormatException(
    this.type,
    this.message, {
    this.unavailableAttachments = const [],
    this.checkedAttachmentIds = const <String>{},
  });

  @override
  String toString() => 'BackupV2FormatException[${type.name}]: $message';
}

enum BackupV2FormatErrorType {
  invalidFormat,
  unsupportedVersion,
  invalidPasswordOrCorruptedData,
  sourceUnavailable,
  incompleteCommit,
  invalidPayload,
  stagingFailed,
  attachmentNotRecoverable,
  unknown,
}

/// 备份容器中附件帧的编码方式。
///
/// 旧 V2 容器保留应用私有附件密文，离开原设备密钥后无法使用；V3 改为备份密码保护下的明文帧，恢复时以
/// 当前设备密钥重新加密为私有附件文件。
enum BackupV2AttachmentEncoding { sourceEncrypted, portablePlaintext }

/// 流式导出时单个附件的来源。
///
/// 来源只提供有限字节流，禁止向日志、UI 或异常暴露其物理路径。
class BackupV2AttachmentSource {
  final BackupAttachmentV1 attachment;
  final Stream<List<int>> Function() openPayloadStream;
  final int payloadSize;

  BackupV2AttachmentSource({
    required this.attachment,
    Stream<List<int>> Function()? openEncryptedStream,
    Stream<List<int>> Function()? openPayloadStream,
    int? payloadSize,
  }) : assert(openEncryptedStream != null || openPayloadStream != null),
       openPayloadStream = openPayloadStream ?? openEncryptedStream!,
       payloadSize = payloadSize ?? attachment.encryptedSize;
}

/// V2 导出计划：资料元数据与附件字节流分离，附件不再编码进 JSON／Base64。
class BackupV2ExportPlan {
  final BackupPayloadV1 manifestPayload;
  final Map<String, BackupV2AttachmentSource> attachmentSourcesById;
  final BackupV2AttachmentEncoding attachmentEncoding;

  BackupV2ExportPlan({
    required this.manifestPayload,
    required Map<String, BackupV2AttachmentSource> attachmentSourcesById,
    this.attachmentEncoding = BackupV2AttachmentEncoding.sourceEncrypted,
  }) : attachmentSourcesById = Map.unmodifiable(attachmentSourcesById);
}

/// V2 输出字节接收端。实现必须顺序写入，单次负荷不超过帧上限。
abstract interface class BackupV2ByteSink {
  Future<void> write(Uint8List bytes);
}

/// V2 输入字节来源。每次只返回一个有限分块；`null` 表示 EOF。
abstract interface class BackupV2ByteSource {
  Future<Uint8List?> readChunk();
}

/// 恢复时由调用方提供的附件 staging 接收端。
///
/// V2 解码完成前的写入只位于新的 staging 区；容器无最终提交帧或任一认证失败时必须 [abort]。
abstract interface class BackupV2AttachmentStaging {
  Future<void> writeChunk({
    required int attachmentIndex,
    required Uint8List bytes,
  });

  Future<void> complete();

  Future<void> abort();
}

typedef BackupV2AttachmentStagingFactory =
    Future<BackupV2AttachmentStaging> Function(
      BackupPayloadV1 payload,
      BackupV2AttachmentEncoding attachmentEncoding,
    );

/// V2 流式校验完成后返回的脱敏结果；载荷仅在应用内恢复流程继续使用，不能用于日志或 UI。
class BackupV2DecodedPayload {
  final BackupPayloadV1 payload;
  final int sizeBytes;
  final int attachmentBytes;
  final BackupV2AttachmentStaging staging;

  const BackupV2DecodedPayload({
    required this.payload,
    required this.sizeBytes,
    required this.attachmentBytes,
    required this.staging,
  });
}

/// V2 导出容量预检结果。
///
/// [estimatedOutputBytes] 是写入前依据附件精确长度和压缩后 manifest 得出的保守估算；SAF 的目标位置可能是
/// 云文档提供方，Android 无法可靠报告其可用空间，最终仍以流式写入结果为准。
class BackupV2ExportPreflight {
  final int estimatedOutputBytes;
  final int attachmentBytes;
  final int attachmentCount;

  const BackupV2ExportPreflight({
    required this.estimatedOutputBytes,
    required this.attachmentBytes,
    required this.attachmentCount,
  });
}

/// 版本化 V2 二进制容器。
///
/// 格式顺序固定为 `magic + header + manifest frames + attachment frames + commit frame`。每个帧均以独立、唯一
/// nonce 的 AES-256-GCM 加密，并将公开头与帧头作为 AAD。最终提交帧认证资料／附件累计长度和帧数；所以截断、
/// 重排、篡改或未写入提交帧的文件均不能进入恢复。
abstract final class BackupV2Format {
  BackupV2Format._();

  static const int framePlaintextLimit = 256 * 1024;
  static const int _headerLimit = 64 * 1024;
  static const int _manifestLimit = 64 * 1024 * 1024;
  static const int _gcmTagLength = 16;
  static const int _sentinelAttachmentIndex = 0xffffffff;
  static final Uint8List _magic = Uint8List.fromList(<int>[
    0x41,
    0x4e,
    0x43,
    0x48,
    0x42,
    0x4b,
    0x02,
    0x0a,
  ]);

  static const int _manifestFrame = 1;
  static const int _attachmentFrame = 2;
  static const int _commitFrame = 3;

  /// 对附件来源和 manifest 做导出前完整性检查，并计算保守容量估算。
  static Future<BackupV2ExportPreflight> preflight(
    BackupV2ExportPlan plan,
  ) async {
    final orderedSources = _orderedSources(plan);
    var attachmentBytes = 0;
    for (final source in orderedSources) {
      attachmentBytes += source.payloadSize;
    }

    final manifestBytes = _compressedManifest(plan.manifestPayload);
    final manifestFrames = _frameCount(manifestBytes.length);
    var attachmentFrames = 0;
    for (final source in orderedSources) {
      attachmentFrames += _frameCount(source.payloadSize);
    }

    // 公开 header 正常约数百字节；此处额外预留 1 KiB，确保在选择目标前不会低估。
    final estimated =
        _magic.length +
        4 +
        1024 +
        manifestBytes.length +
        (manifestFrames * _frameOverhead) +
        attachmentBytes +
        (attachmentFrames * _frameOverhead) +
        _commitPayloadMaxBytes +
        _frameOverhead;
    return BackupV2ExportPreflight(
      estimatedOutputBytes: estimated,
      attachmentBytes: attachmentBytes,
      attachmentCount: orderedSources.length,
    );
  }

  /// 仅在导出过程中发现附件读取失败后调用。已成功写入的附件不再重复读取；其余附件只读验证，收集全部
  /// 不可用项，避免用户每删除一个附件就重新发起一次导出。不会保留附件明文，也不会写入提交帧。
  static Future<List<BackupUnavailableAttachment>> auditRemainingAttachments({
    required BackupV2ExportPlan plan,
    required Set<String> alreadyCheckedAttachmentIds,
    void Function(int completedAttachments, int totalAttachments)?
    onAttachmentChecked,
  }) async {
    final unavailable = <BackupUnavailableAttachment>[];
    final orderedSources = _orderedSources(plan);
    var completedAttachments = orderedSources
        .where(
          (source) =>
              alreadyCheckedAttachmentIds.contains(source.attachment.id),
        )
        .length;
    onAttachmentChecked?.call(completedAttachments, orderedSources.length);
    for (final source in orderedSources) {
      if (alreadyCheckedAttachmentIds.contains(source.attachment.id)) {
        continue;
      }
      final result = await _auditAttachmentSource(plan: plan, source: source);
      if (result != null) {
        unavailable.add(result);
      }
      completedAttachments++;
      onAttachmentChecked?.call(completedAttachments, orderedSources.length);
    }
    return List.unmodifiable(unavailable);
  }

  static Future<BackupUnavailableAttachment?> _auditAttachmentSource({
    required BackupV2ExportPlan plan,
    required BackupV2AttachmentSource source,
  }) async {
    StreamIterator<List<int>>? iterator;
    try {
      iterator = _openAttachmentIterator(
        plan: plan,
        source: source,
        checkedAttachmentIds: {source.attachment.id},
      );
      var actualSize = 0;
      while (await _moveToNextAttachmentChunk(
        iterator: iterator,
        plan: plan,
        source: source,
        checkedAttachmentIds: {source.attachment.id},
      )) {
        actualSize += iterator.current.length;
        if (actualSize > source.payloadSize) {
          return _unavailableAttachment(
            plan,
            source.attachment,
            BackupUnavailableAttachmentReason.sourceChanged,
          );
        }
      }
      if (actualSize != source.payloadSize) {
        return _unavailableAttachment(
          plan,
          source.attachment,
          BackupUnavailableAttachmentReason.sourceChanged,
        );
      }
      return null;
    } on BackupV2FormatException catch (error) {
      return error.unavailableAttachments.isNotEmpty
          ? error.unavailableAttachments.first
          : _unavailableAttachment(
              plan,
              source.attachment,
              BackupUnavailableAttachmentReason.fileUnreadable,
            );
    } finally {
      if (iterator != null) {
        try {
          await iterator.cancel();
        } catch (_) {
          // 审计完成或失败后不再需要读取流；取消失败不改变附件原始故障结论。
        }
      }
    }
  }

  /// 将计划顺序写入目标。调用者只能在本方法成功返回后写入最终确认；异常时不得写入成功状态。
  static Future<int> encodeToSink({
    required BackupV2ExportPlan plan,
    required String backupPassword,
    required BackupV2ByteSink sink,
    int? iterations,
    int? createdAtForTest,
    List<int>? saltForTest,
    List<int>? noncePrefixForTest,
    void Function(int writtenBytes, int totalBytes)? onProgress,
  }) async {
    if (backupPassword.trim().isEmpty) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidPasswordOrCorruptedData,
        '备份密码不能为空。',
      );
    }
    final orderedSources = _orderedSources(plan);

    final actualIterations =
        iterations ?? BackupCryptoService.defaultIterations;
    if (actualIterations <= 0) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidFormat,
        '备份参数不正确。',
      );
    }
    final salt = Uint8List.fromList(saltForTest ?? _randomBytes(16));
    final noncePrefix = Uint8List.fromList(
      noncePrefixForTest ?? _randomBytes(8),
    );
    if (salt.length != 16 || noncePrefix.length != 8) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidFormat,
        '备份参数不正确。',
      );
    }
    final header = _encodeHeader(
      createdAt: createdAtForTest ?? DateTime.now().millisecondsSinceEpoch,
      iterations: actualIterations,
      salt: salt,
      noncePrefix: noncePrefix,
      attachmentEncoding: plan.attachmentEncoding,
    );
    final secretKey = await _deriveKey(
      backupPassword: backupPassword,
      salt: salt,
      iterations: actualIterations,
    );

    final manifestBytes = _compressedManifest(plan.manifestPayload);
    var attachmentBytesExpected = 0;
    var dataFramesExpected = _frameCount(manifestBytes.length);
    for (final source in orderedSources) {
      attachmentBytesExpected += source.payloadSize;
      dataFramesExpected += _frameCount(source.payloadSize);
    }
    final commit = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, int>{
          'dataFrames': dataFramesExpected,
          'manifestBytes': manifestBytes.length,
          'attachmentBytes': attachmentBytesExpected,
          'attachmentCount': orderedSources.length,
        }),
      ),
    );
    final totalBytes =
        _magic.length +
        4 +
        header.length +
        manifestBytes.length +
        attachmentBytesExpected +
        ((dataFramesExpected + 1) * _frameOverhead) +
        commit.length;

    var written = 0;
    Future<void> write(Uint8List bytes) async {
      await sink.write(bytes);
      written += bytes.length;
      onProgress?.call(written, totalBytes);
    }

    try {
      onProgress?.call(0, totalBytes);
      await write(_magic);
      await write(_uint32(header.length));
      await write(header);

      var sequence = 0;
      var dataFrames = 0;
      var attachmentBytes = 0;
      for (final chunk in _chunks(manifestBytes)) {
        await _writeFrame(
          sink: sink,
          header: header,
          secretKey: secretKey,
          noncePrefix: noncePrefix,
          type: _manifestFrame,
          sequence: sequence++,
          attachmentIndex: _sentinelAttachmentIndex,
          plaintext: chunk,
        );
        written += _frameOverhead + chunk.length;
        onProgress?.call(written, totalBytes);
        dataFrames++;
      }

      for (var index = 0; index < orderedSources.length; index++) {
        final source = orderedSources[index];
        final checkedAttachmentIds = orderedSources
            .take(index + 1)
            .map((source) => source.attachment.id)
            .toSet();
        var actualSize = 0;
        var bufferedSize = 0;
        var frameBuffer = BytesBuilder(copy: false);

        Future<void> writeAttachmentFrame(Uint8List chunk) async {
          await _writeFrame(
            sink: sink,
            header: header,
            secretKey: secretKey,
            noncePrefix: noncePrefix,
            type: _attachmentFrame,
            sequence: sequence++,
            attachmentIndex: index,
            plaintext: chunk,
          );
          written += _frameOverhead + chunk.length;
          onProgress?.call(written, totalBytes);
          dataFrames++;
        }

        final iterator = _openAttachmentIterator(
          plan: plan,
          source: source,
          checkedAttachmentIds: checkedAttachmentIds,
        );
        try {
          while (true) {
            final hasNext = await _moveToNextAttachmentChunk(
              iterator: iterator,
              plan: plan,
              source: source,
              checkedAttachmentIds: checkedAttachmentIds,
            );
            if (!hasNext) break;
            final sourceChunk = iterator.current;
            final bytes = Uint8List.fromList(sourceChunk);
            actualSize += bytes.length;
            if (actualSize > source.payloadSize) {
              throw BackupV2FormatException(
                BackupV2FormatErrorType.sourceUnavailable,
                '备份附件读取不完整，未生成可用备份。',
                unavailableAttachments: [
                  _unavailableAttachment(
                    plan,
                    source.attachment,
                    BackupUnavailableAttachmentReason.sourceChanged,
                  ),
                ],
                checkedAttachmentIds: checkedAttachmentIds,
              );
            }

            var offset = 0;
            while (offset < bytes.length) {
              final take = min(
                framePlaintextLimit - bufferedSize,
                bytes.length - offset,
              );
              frameBuffer.add(
                Uint8List.sublistView(bytes, offset, offset + take),
              );
              bufferedSize += take;
              offset += take;
              if (bufferedSize == framePlaintextLimit) {
                await writeAttachmentFrame(frameBuffer.takeBytes());
                frameBuffer = BytesBuilder(copy: false);
                bufferedSize = 0;
              }
            }
          }
        } finally {
          await iterator.cancel();
        }
        if (actualSize != source.payloadSize) {
          throw BackupV2FormatException(
            BackupV2FormatErrorType.sourceUnavailable,
            '备份附件读取不完整，未生成可用备份。',
            unavailableAttachments: [
              _unavailableAttachment(
                plan,
                source.attachment,
                BackupUnavailableAttachmentReason.sourceChanged,
              ),
            ],
            checkedAttachmentIds: checkedAttachmentIds,
          );
        }
        if (bufferedSize > 0) {
          await writeAttachmentFrame(frameBuffer.takeBytes());
        }
        attachmentBytes += actualSize;
      }

      if (dataFrames != dataFramesExpected ||
          attachmentBytes != attachmentBytesExpected) {
        throw const BackupV2FormatException(
          BackupV2FormatErrorType.sourceUnavailable,
          '备份附件读取不完整，未生成可用备份。',
        );
      }
      await _writeFrame(
        sink: sink,
        header: header,
        secretKey: secretKey,
        noncePrefix: noncePrefix,
        type: _commitFrame,
        sequence: sequence,
        attachmentIndex: _sentinelAttachmentIndex,
        plaintext: commit,
      );
      written += _frameOverhead + commit.length;
      onProgress?.call(written, totalBytes);
      return written;
    } on BackupV2FormatException {
      rethrow;
    } on BackupFileSaveException {
      rethrow;
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.unknown,
        '备份导出未完成，未确认生成可用文件。',
      );
    }
  }

  static Future<bool> _moveToNextAttachmentChunk({
    required StreamIterator<List<int>> iterator,
    required BackupV2ExportPlan plan,
    required BackupV2AttachmentSource source,
    required Set<String> checkedAttachmentIds,
  }) async {
    try {
      return await iterator.moveNext();
    } catch (_) {
      throw _attachmentUnreadableException(
        plan: plan,
        source: source,
        checkedAttachmentIds: checkedAttachmentIds,
      );
    }
  }

  static StreamIterator<List<int>> _openAttachmentIterator({
    required BackupV2ExportPlan plan,
    required BackupV2AttachmentSource source,
    required Set<String> checkedAttachmentIds,
  }) {
    try {
      return StreamIterator<List<int>>(source.openPayloadStream());
    } catch (_) {
      throw _attachmentUnreadableException(
        plan: plan,
        source: source,
        checkedAttachmentIds: checkedAttachmentIds,
      );
    }
  }

  static BackupV2FormatException _attachmentUnreadableException({
    required BackupV2ExportPlan plan,
    required BackupV2AttachmentSource source,
    required Set<String> checkedAttachmentIds,
  }) {
    return BackupV2FormatException(
      BackupV2FormatErrorType.sourceUnavailable,
      '备份附件读取不完整，未生成可用备份。',
      unavailableAttachments: [
        _unavailableAttachment(
          plan,
          source.attachment,
          BackupUnavailableAttachmentReason.fileUnreadable,
        ),
      ],
      checkedAttachmentIds: checkedAttachmentIds,
    );
  }

  /// 流式读取、逐帧认证并写入调用方提供的 staging。只有读到并验证最终提交帧时才返回成功。
  static Future<BackupV2DecodedPayload> decodeAndStage({
    required BackupV2ByteSource source,
    required String backupPassword,
    required BackupV2AttachmentStagingFactory stagingFactory,
    void Function(int bytesRead)? onProgress,
  }) async {
    if (backupPassword.trim().isEmpty) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidPasswordOrCorruptedData,
        '备份密码不正确，或备份文件已损坏。',
      );
    }
    final reader = _BackupV2Reader(source);
    BackupV2AttachmentStaging? staging;
    try {
      onProgress?.call(0);
      final magic = await reader.readExact(_magic.length);
      if (!_sameBytes(magic, _magic)) {
        throw const BackupV2FormatException(
          BackupV2FormatErrorType.invalidFormat,
          '备份文件格式不正确或已损坏。',
        );
      }
      final headerLength = _readUint32(await reader.readExact(4));
      if (headerLength <= 0 || headerLength > _headerLimit) {
        throw const BackupV2FormatException(
          BackupV2FormatErrorType.invalidFormat,
          '备份文件格式不正确或已损坏。',
        );
      }
      final headerBytes = await reader.readExact(headerLength);
      final header = _decodeHeader(headerBytes);
      final secretKey = await _deriveKey(
        backupPassword: backupPassword,
        salt: header.salt,
        iterations: header.iterations,
      );

      final manifestCompressed = BytesBuilder(copy: false);
      BackupPayloadV1? payload;
      var expectedSequence = 0;
      var expectedAttachmentIndex = 0;
      var attachmentBytes = 0;
      var dataFrames = 0;
      var manifestBytes = 0;
      var commitSeen = false;

      while (!commitSeen) {
        final frameHeader = await reader.readExact(_frameHeaderLength);
        final type = frameHeader[0];
        final sequence = _readUint32(frameHeader.sublist(1, 5));
        final attachmentIndex = _readUint32(frameHeader.sublist(5, 9));
        final plaintextLength = _readUint32(frameHeader.sublist(9, 13));
        if (sequence != expectedSequence ||
            plaintextLength > framePlaintextLimit ||
            (type != _manifestFrame &&
                type != _attachmentFrame &&
                type != _commitFrame)) {
          throw const BackupV2FormatException(
            BackupV2FormatErrorType.invalidFormat,
            '备份文件格式不正确或已损坏。',
          );
        }
        final cipherText = await reader.readExact(plaintextLength);
        final mac = await reader.readExact(_gcmTagLength);
        final plaintext = await _decryptFrame(
          secretKey: secretKey,
          noncePrefix: header.noncePrefix,
          sequence: sequence,
          header: headerBytes,
          frameHeader: frameHeader,
          cipherText: cipherText,
          mac: mac,
        );
        expectedSequence++;
        onProgress?.call(reader.bytesRead);

        if (type == _manifestFrame) {
          if (payload != null || attachmentIndex != _sentinelAttachmentIndex) {
            throw const BackupV2FormatException(
              BackupV2FormatErrorType.invalidFormat,
              '备份文件格式不正确或已损坏。',
            );
          }
          manifestCompressed.add(plaintext);
          manifestBytes += plaintext.length;
          if (manifestCompressed.length > _manifestLimit) {
            throw const BackupV2FormatException(
              BackupV2FormatErrorType.invalidFormat,
              '备份文件元数据过大，无法安全恢复。',
            );
          }
          dataFrames++;
          continue;
        }

        if (type == _attachmentFrame) {
          payload ??= _decodeManifest(manifestCompressed.takeBytes());
          staging ??= await stagingFactory(payload, header.attachmentEncoding);
          while (expectedAttachmentIndex < payload.data.attachments.length &&
              _attachmentPayloadSize(
                    payload.data.attachments[expectedAttachmentIndex],
                    header.attachmentEncoding,
                  ) ==
                  0) {
            expectedAttachmentIndex++;
          }
          if (attachmentIndex != expectedAttachmentIndex ||
              attachmentIndex >= payload.data.attachments.length) {
            throw const BackupV2FormatException(
              BackupV2FormatErrorType.invalidFormat,
              '备份文件附件顺序不正确。',
            );
          }
          final attachment = payload.data.attachments[attachmentIndex];
          final alreadyWritten = attachmentBytesForIndex(
            payload: payload,
            index: attachmentIndex,
            totalBeforeCurrent: attachmentBytes,
            attachmentEncoding: header.attachmentEncoding,
          );
          final expectedSize = _attachmentPayloadSize(
            attachment,
            header.attachmentEncoding,
          );
          if (alreadyWritten + plaintext.length > expectedSize) {
            throw const BackupV2FormatException(
              BackupV2FormatErrorType.invalidFormat,
              '备份文件附件长度不正确。',
            );
          }
          await staging.writeChunk(
            attachmentIndex: attachmentIndex,
            bytes: plaintext,
          );
          attachmentBytes += plaintext.length;
          if (alreadyWritten + plaintext.length == expectedSize) {
            expectedAttachmentIndex++;
          }
          dataFrames++;
          continue;
        }

        payload ??= _decodeManifest(manifestCompressed.takeBytes());
        if (attachmentIndex != _sentinelAttachmentIndex) {
          throw const BackupV2FormatException(
            BackupV2FormatErrorType.incompleteCommit,
            '备份文件未完成，不能用于恢复。',
          );
        }
        while (expectedAttachmentIndex < payload.data.attachments.length &&
            _attachmentPayloadSize(
                  payload.data.attachments[expectedAttachmentIndex],
                  header.attachmentEncoding,
                ) ==
                0) {
          expectedAttachmentIndex++;
        }
        if (expectedAttachmentIndex != payload.data.attachments.length) {
          throw const BackupV2FormatException(
            BackupV2FormatErrorType.incompleteCommit,
            '备份文件未完成，不能用于恢复。',
          );
        }
        _validateCommit(
          plaintext,
          dataFrames: dataFrames,
          manifestBytes: manifestBytes,
          attachmentBytes: attachmentBytes,
          attachmentCount: payload.data.attachments.length,
        );
        commitSeen = true;
      }

      if (await reader.readOneOrNull() != null) {
        throw const BackupV2FormatException(
          BackupV2FormatErrorType.invalidFormat,
          '备份文件格式不正确或已损坏。',
        );
      }
      onProgress?.call(reader.bytesRead);
      final resolvedPayload =
          payload ?? _decodeManifest(manifestCompressed.takeBytes());
      staging ??= await stagingFactory(
        resolvedPayload,
        header.attachmentEncoding,
      );
      await staging.complete();
      return BackupV2DecodedPayload(
        payload: resolvedPayload,
        sizeBytes: reader.bytesRead,
        attachmentBytes: attachmentBytes,
        staging: staging,
      );
    } on BackupV2FormatException {
      await staging?.abort();
      rethrow;
    } catch (_) {
      await staging?.abort();
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidPasswordOrCorruptedData,
        '备份密码不正确，或备份文件已损坏。',
      );
    }
  }

  /// 只读取并认证 V2 的加密 manifest，用于在用户确认覆盖前快速展示恢复范围。
  ///
  /// 该方法不会创建 staging，也不会读取、认证附件帧或最终提交帧；调用方必须在用户确认后重新从头执行
  /// [decodeAndStage]，完成整包校验后才允许写入数据库。
  static Future<BackupPayloadV1> decodeManifestPreview({
    required BackupV2ByteSource source,
    required String backupPassword,
  }) async {
    if (backupPassword.trim().isEmpty) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidPasswordOrCorruptedData,
        '备份密码不正确，或备份文件已损坏。',
      );
    }
    final reader = _BackupV2Reader(source);
    try {
      final magic = await reader.readExact(_magic.length);
      if (!_sameBytes(magic, _magic)) {
        throw const BackupV2FormatException(
          BackupV2FormatErrorType.invalidFormat,
          '备份文件格式不正确或已损坏。',
        );
      }
      final headerLength = _readUint32(await reader.readExact(4));
      if (headerLength <= 0 || headerLength > _headerLimit) {
        throw const BackupV2FormatException(
          BackupV2FormatErrorType.invalidFormat,
          '备份文件格式不正确或已损坏。',
        );
      }
      final headerBytes = await reader.readExact(headerLength);
      final header = _decodeHeader(headerBytes);
      final secretKey = await _deriveKey(
        backupPassword: backupPassword,
        salt: header.salt,
        iterations: header.iterations,
      );

      final manifestCompressed = BytesBuilder(copy: false);
      var expectedSequence = 0;
      var manifestFrames = 0;
      while (true) {
        final frameHeader = await reader.readExact(_frameHeaderLength);
        final type = frameHeader[0];
        final sequence = _readUint32(frameHeader.sublist(1, 5));
        final attachmentIndex = _readUint32(frameHeader.sublist(5, 9));
        final plaintextLength = _readUint32(frameHeader.sublist(9, 13));
        if (sequence != expectedSequence ||
            plaintextLength > framePlaintextLimit ||
            (type != _manifestFrame &&
                type != _attachmentFrame &&
                type != _commitFrame)) {
          throw const BackupV2FormatException(
            BackupV2FormatErrorType.invalidFormat,
            '备份文件格式不正确或已损坏。',
          );
        }

        if (type != _manifestFrame) {
          if (manifestFrames == 0) {
            throw const BackupV2FormatException(
              BackupV2FormatErrorType.invalidFormat,
              '备份文件格式不正确或已损坏。',
            );
          }
          return _decodeManifest(manifestCompressed.takeBytes());
        }
        if (attachmentIndex != _sentinelAttachmentIndex) {
          throw const BackupV2FormatException(
            BackupV2FormatErrorType.invalidFormat,
            '备份文件格式不正确或已损坏。',
          );
        }
        final cipherText = await reader.readExact(plaintextLength);
        final mac = await reader.readExact(_gcmTagLength);
        final plaintext = await _decryptFrame(
          secretKey: secretKey,
          noncePrefix: header.noncePrefix,
          sequence: sequence,
          header: headerBytes,
          frameHeader: frameHeader,
          cipherText: cipherText,
          mac: mac,
        );
        expectedSequence++;
        manifestFrames++;
        manifestCompressed.add(plaintext);
        if (manifestCompressed.length > _manifestLimit) {
          throw const BackupV2FormatException(
            BackupV2FormatErrorType.invalidFormat,
            '备份文件元数据过大，无法安全恢复。',
          );
        }
      }
    } on BackupV2FormatException {
      rethrow;
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidPasswordOrCorruptedData,
        '备份密码不正确，或备份文件已损坏。',
      );
    }
  }

  /// 计算指定附件此前已经写入的字节。仅使用已认证帧的累计字节，避免维护第二份可变数组。
  static int attachmentBytesForIndex({
    required BackupPayloadV1 payload,
    required int index,
    required int totalBeforeCurrent,
    BackupV2AttachmentEncoding attachmentEncoding =
        BackupV2AttachmentEncoding.sourceEncrypted,
  }) {
    var previousAttachmentsBytes = 0;
    for (var i = 0; i < index; i++) {
      previousAttachmentsBytes += _attachmentPayloadSize(
        payload.data.attachments[i],
        attachmentEncoding,
      );
    }
    return totalBeforeCurrent - previousAttachmentsBytes;
  }

  static Future<void> _writeFrame({
    required BackupV2ByteSink sink,
    required Uint8List header,
    required SecretKey secretKey,
    required Uint8List noncePrefix,
    required int type,
    required int sequence,
    required int attachmentIndex,
    required Uint8List plaintext,
  }) async {
    final frameHeader = _frameHeader(
      type: type,
      sequence: sequence,
      attachmentIndex: attachmentIndex,
      plaintextLength: plaintext.length,
    );
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: _nonce(noncePrefix, sequence),
      aad: Uint8List.fromList(<int>[...header, ...frameHeader]),
    );
    await sink.write(frameHeader);
    await sink.write(Uint8List.fromList(box.cipherText));
    await sink.write(Uint8List.fromList(box.mac.bytes));
  }

  static Future<Uint8List> _decryptFrame({
    required SecretKey secretKey,
    required Uint8List noncePrefix,
    required int sequence,
    required Uint8List header,
    required Uint8List frameHeader,
    required Uint8List cipherText,
    required Uint8List mac,
  }) async {
    try {
      final plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(
          cipherText,
          nonce: _nonce(noncePrefix, sequence),
          mac: Mac(mac),
        ),
        secretKey: secretKey,
        aad: Uint8List.fromList(<int>[...header, ...frameHeader]),
      );
      return Uint8List.fromList(plaintext);
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidPasswordOrCorruptedData,
        '备份密码不正确，或备份文件已损坏。',
      );
    }
  }

  static Uint8List _encodeHeader({
    required int createdAt,
    required int iterations,
    required Uint8List salt,
    required Uint8List noncePrefix,
    required BackupV2AttachmentEncoding attachmentEncoding,
  }) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object>{
          'format': 'anch.backup.stream',
          'version':
              attachmentEncoding == BackupV2AttachmentEncoding.portablePlaintext
              ? 3
              : 2,
          'payloadFormat': 'anch.backup.payload',
          'payloadVersion': 1,
          'createdAt': createdAt,
          'compression': 'gzip-manifest',
          'framePlaintextLimit': framePlaintextLimit,
          if (attachmentEncoding ==
              BackupV2AttachmentEncoding.portablePlaintext)
            'attachmentEncoding': 'portablePlaintext',
          'kdf': <String, Object>{
            'name': 'pbkdf2-hmac-sha256',
            'iterations': iterations,
            'salt': base64Url.encode(salt),
            'keyLength': 32,
          },
          'cipher': <String, Object>{
            'name': 'aes-256-gcm-framed',
            'noncePrefix': base64Url.encode(noncePrefix),
            'tagLength': _gcmTagLength,
          },
        }),
      ),
    );
  }

  static _BackupV2Header _decodeHeader(Uint8List bytes) {
    try {
      final raw = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (raw is! Map) throw const FormatException();
      final map = Map<String, Object?>.from(raw);
      final kdfRaw = map['kdf'];
      final cipherRaw = map['cipher'];
      final version = map['version'];
      final attachmentEncoding = switch (version) {
        2 when !map.containsKey('attachmentEncoding') =>
          BackupV2AttachmentEncoding.sourceEncrypted,
        3 when map['attachmentEncoding'] == 'portablePlaintext' =>
          BackupV2AttachmentEncoding.portablePlaintext,
        _ => throw const FormatException(),
      };
      if (map['format'] != 'anch.backup.stream' ||
          map['payloadFormat'] != 'anch.backup.payload' ||
          map['payloadVersion'] != 1 ||
          map['compression'] != 'gzip-manifest' ||
          map['framePlaintextLimit'] != framePlaintextLimit ||
          kdfRaw is! Map ||
          cipherRaw is! Map) {
        throw const FormatException();
      }
      final kdf = Map<String, Object?>.from(kdfRaw);
      final cipher = Map<String, Object?>.from(cipherRaw);
      final iterations = kdf['iterations'];
      final saltText = kdf['salt'];
      final noncePrefixText = cipher['noncePrefix'];
      if (kdf['name'] != 'pbkdf2-hmac-sha256' ||
          kdf['keyLength'] != 32 ||
          cipher['name'] != 'aes-256-gcm-framed' ||
          cipher['tagLength'] != _gcmTagLength ||
          iterations is! int ||
          iterations <= 0 ||
          saltText is! String ||
          noncePrefixText is! String) {
        throw const FormatException();
      }
      final salt = Uint8List.fromList(base64Url.decode(saltText));
      final noncePrefix = Uint8List.fromList(base64Url.decode(noncePrefixText));
      if (salt.length != 16 || noncePrefix.length != 8) {
        throw const FormatException();
      }
      return _BackupV2Header(
        iterations: iterations,
        salt: salt,
        noncePrefix: noncePrefix,
        attachmentEncoding: attachmentEncoding,
      );
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidFormat,
        '备份文件格式不正确或已损坏。',
      );
    }
  }

  static Uint8List _compressedManifest(BackupPayloadV1 payload) {
    final jsonMap = _manifestJson(payload);
    return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(jsonMap))));
  }

  static Map<String, dynamic> _manifestJson(BackupPayloadV1 payload) {
    final map = Map<String, dynamic>.from(payload.normalized().toJson());
    final data = Map<String, dynamic>.from(map['data'] as Map);
    final attachments = (data['attachments'] as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    for (final attachment in attachments) {
      attachment.remove('encryptedData');
    }
    data['attachments'] = attachments;
    map['data'] = data;
    return map;
  }

  static BackupPayloadV1 _decodeManifest(Uint8List compressed) {
    try {
      final decompressed = gzip.decode(compressed);
      if (decompressed.length > _manifestLimit) throw const FormatException();
      final raw = jsonDecode(utf8.decode(decompressed, allowMalformed: false));
      if (raw is! Map) throw const FormatException();
      final map = Map<String, dynamic>.from(raw);
      final dataRaw = map['data'];
      if (dataRaw is! Map) throw const FormatException();
      final data = Map<String, dynamic>.from(dataRaw);
      final attachmentsRaw = data['attachments'];
      if (attachmentsRaw is! List) throw const FormatException();
      final attachments = <Map<String, dynamic>>[];
      for (final attachmentRaw in attachmentsRaw) {
        if (attachmentRaw is! Map) throw const FormatException();
        final attachment = Map<String, dynamic>.from(attachmentRaw);
        attachment['encryptedData'] = '';
        attachments.add(attachment);
      }
      data['attachments'] = attachments;
      map['data'] = data;
      return BackupPayloadV1.fromJson(map);
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidPayload,
        '备份内容校验失败，未执行恢复。',
      );
    }
  }

  static int _attachmentPayloadSize(
    BackupAttachmentV1 attachment,
    BackupV2AttachmentEncoding attachmentEncoding,
  ) {
    return attachmentEncoding == BackupV2AttachmentEncoding.portablePlaintext
        ? attachment.plainSize
        : attachment.encryptedSize;
  }

  /// 按 manifest 的规范顺序解析来源。来源以附件 ID 绑定，而不是仓储查询偶然返回的列表位置，避免排序后将
  /// 一个附件的密文写入另一附件的位置。
  static List<BackupV2AttachmentSource> _orderedSources(
    BackupV2ExportPlan plan,
  ) {
    final attachments = plan.manifestPayload.normalized().data.attachments;
    final sources = <BackupV2AttachmentSource>[];
    final ids = <String>{};
    for (var index = 0; index < attachments.length; index++) {
      final metadata = attachments[index];
      final source = plan.attachmentSourcesById[metadata.id];
      if (!ids.add(metadata.id) ||
          source == null ||
          metadata.id != source.attachment.id ||
          metadata.fileName != source.attachment.fileName ||
          metadata.encryptedSize < 0 ||
          metadata.plainSize < 0 ||
          metadata.encryptedSize != source.attachment.encryptedSize ||
          source.payloadSize !=
              _attachmentPayloadSize(metadata, plan.attachmentEncoding)) {
        throw BackupV2FormatException(
          BackupV2FormatErrorType.sourceUnavailable,
          '备份附件读取不完整，未生成可用备份。',
          unavailableAttachments: [
            _unavailableAttachment(
              plan,
              metadata,
              BackupUnavailableAttachmentReason.metadataInconsistent,
            ),
          ],
        );
      }
      sources.add(source);
    }
    if (sources.length != plan.attachmentSourcesById.length) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.sourceUnavailable,
        '备份附件读取不完整，未生成可用备份。',
      );
    }
    return List<BackupV2AttachmentSource>.unmodifiable(sources);
  }

  static BackupUnavailableAttachment _unavailableAttachment(
    BackupV2ExportPlan plan,
    BackupAttachmentV1 attachment,
    BackupUnavailableAttachmentReason reason,
  ) {
    String? itemTitle;
    for (final item in plan.manifestPayload.data.items) {
      if (item.id == attachment.itemId) {
        itemTitle = item.title;
        break;
      }
    }
    return BackupUnavailableAttachment(
      itemId: attachment.itemId,
      itemTitle: itemTitle,
      originalName: attachment.originalName,
      reason: reason,
    );
  }

  static void _validateCommit(
    Uint8List bytes, {
    required int dataFrames,
    required int manifestBytes,
    required int attachmentBytes,
    required int attachmentCount,
  }) {
    try {
      final raw = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (raw is! Map ||
          raw['dataFrames'] != dataFrames ||
          raw['manifestBytes'] != manifestBytes ||
          raw['attachmentBytes'] != attachmentBytes ||
          raw['attachmentCount'] != attachmentCount) {
        throw const FormatException();
      }
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.incompleteCommit,
        '备份文件未完成，不能用于恢复。',
      );
    }
  }

  static Future<SecretKey> _deriveKey({
    required String backupPassword,
    required Uint8List salt,
    required int iterations,
  }) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(backupPassword)), nonce: salt);
  }

  static Uint8List _nonce(Uint8List prefix, int sequence) {
    if (sequence < 0 || sequence == _sentinelAttachmentIndex) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidFormat,
        '备份文件帧序号超出范围。',
      );
    }
    return Uint8List.fromList(<int>[...prefix, ..._uint32(sequence)]);
  }

  static Uint8List _frameHeader({
    required int type,
    required int sequence,
    required int attachmentIndex,
    required int plaintextLength,
  }) {
    return Uint8List.fromList(<int>[
      type,
      ..._uint32(sequence),
      ..._uint32(attachmentIndex),
      ..._uint32(plaintextLength),
    ]);
  }

  static Iterable<Uint8List> _chunks(Uint8List bytes) sync* {
    if (bytes.isEmpty) return;
    for (var offset = 0; offset < bytes.length; offset += framePlaintextLimit) {
      final end = min(offset + framePlaintextLimit, bytes.length);
      yield Uint8List.sublistView(bytes, offset, end);
    }
  }

  static int _frameCount(int bytes) {
    if (bytes == 0) return 0;
    return (bytes + framePlaintextLimit - 1) ~/ framePlaintextLimit;
  }

  static Uint8List _uint32(int value) {
    if (value < 0 || value > _sentinelAttachmentIndex) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.invalidFormat,
        '备份文件长度超出范围。',
      );
    }
    final bytes = ByteData(4)..setUint32(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  static int _readUint32(List<int> bytes) {
    if (bytes.length != 4) throw const FormatException();
    return ByteData.sublistView(
      Uint8List.fromList(bytes),
    ).getUint32(0, Endian.big);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static const int _frameHeaderLength = 13;
  static const int _frameOverhead = _frameHeaderLength + _gcmTagLength;
  static const int _commitPayloadMaxBytes = 128;
}

class _BackupV2Header {
  final int iterations;
  final Uint8List salt;
  final Uint8List noncePrefix;
  final BackupV2AttachmentEncoding attachmentEncoding;

  const _BackupV2Header({
    required this.iterations,
    required this.salt,
    required this.noncePrefix,
    required this.attachmentEncoding,
  });
}

class _BackupV2Reader {
  final BackupV2ByteSource source;
  Uint8List _buffer = Uint8List(0);
  var _offset = 0;
  var bytesRead = 0;

  _BackupV2Reader(this.source);

  Future<Uint8List> readExact(int length) async {
    if (length < 0) throw const FormatException();
    final result = Uint8List(length);
    var written = 0;
    while (written < length) {
      if (_offset == _buffer.length) {
        final next = await source.readChunk();
        if (next == null || next.isEmpty) {
          throw const BackupV2FormatException(
            BackupV2FormatErrorType.incompleteCommit,
            '备份文件未完成，不能用于恢复。',
          );
        }
        _buffer = next;
        _offset = 0;
      }
      final available = _buffer.length - _offset;
      final take = min(available, length - written);
      result.setRange(written, written + take, _buffer, _offset);
      _offset += take;
      written += take;
      bytesRead += take;
    }
    return result;
  }

  Future<int?> readOneOrNull() async {
    if (_offset < _buffer.length) {
      final byte = _buffer[_offset++];
      bytesRead++;
      return byte;
    }
    final next = await source.readChunk();
    if (next == null || next.isEmpty) return null;
    _buffer = next;
    _offset = 1;
    bytesRead++;
    return next.first;
  }
}
