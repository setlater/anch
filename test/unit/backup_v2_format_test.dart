@Tags(['security'])
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/backup/backup_v2_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V2 流式备份容器', () {
    test('大于单帧的虚构附件可完整往返，附件不进入 manifest', () async {
      final attachmentBytes = Uint8List.fromList(
        List<int>.generate(
          BackupV2Format.framePlaintextLimit + 37,
          (index) => index % 251,
        ),
      );
      final payload = _payload(encryptedSize: attachmentBytes.length);
      final sink = _MemorySink();
      final password = _ephemeralPassword();

      final written = await BackupV2Format.encodeToSink(
        plan: BackupV2ExportPlan(
          manifestPayload: payload,
          attachmentSourcesById: {
            payload.data.attachments.single.id: BackupV2AttachmentSource(
              attachment: payload.data.attachments.single,
              openEncryptedStream: () => Stream<List<int>>.fromIterable([
                attachmentBytes.sublist(0, 1024),
                attachmentBytes.sublist(1024),
              ]),
            ),
          },
        ),
        backupPassword: password,
        sink: sink,
        iterations: 2,
        createdAtForTest: 1,
        saltForTest: List<int>.filled(16, 7),
        noncePrefixForTest: List<int>.filled(8, 9),
      );
      final staging = _MemoryStaging();
      final decoded = await BackupV2Format.decodeAndStage(
        source: _ChunkedMemorySource(sink.bytes, maxChunk: 997),
        backupPassword: password,
        stagingFactory: (payload, attachmentEncoding) async => staging,
      );

      expect(written, sink.bytes.length);
      expect(decoded.payload.data.attachments.single.encryptedData, isEmpty);
      expect(decoded.attachmentBytes, attachmentBytes.length);
      expect(staging.completeCalled, isTrue);
      expect(staging.bytesByAttachment[0], attachmentBytes);
    });

    test('认证 manifest 后可先预览恢复范围，不读取附件帧或创建 staging', () async {
      final attachmentBytes = Uint8List.fromList(
        List<int>.filled(BackupV2Format.framePlaintextLimit * 4, 7),
      );
      final payload = _payload(encryptedSize: attachmentBytes.length);
      final sink = _MemorySink();
      final password = _ephemeralPassword();
      await BackupV2Format.encodeToSink(
        plan: BackupV2ExportPlan(
          manifestPayload: payload,
          attachmentSourcesById: {
            payload.data.attachments.single.id: BackupV2AttachmentSource(
              attachment: payload.data.attachments.single,
              openEncryptedStream: () =>
                  Stream<List<int>>.value(attachmentBytes),
            ),
          },
        ),
        backupPassword: password,
        sink: sink,
        iterations: 2,
      );

      final source = _ChunkedMemorySource(sink.bytes, maxChunk: 97);
      final preview = await BackupV2Format.decodeManifestPreview(
        source: source,
        backupPassword: password,
      );

      expect(preview.data.attachments, hasLength(1));
      expect(
        preview.data.attachments.single.encryptedSize,
        attachmentBytes.length,
      );
      expect(source.bytesRead, lessThan(sink.bytes.length));
    });

    test('缺少最终提交帧时拒绝恢复并清理 staging', () async {
      final attachmentBytes = Uint8List.fromList(List<int>.filled(10, 3));
      final payload = _payload(encryptedSize: attachmentBytes.length);
      final sink = _MemorySink();
      final password = _ephemeralPassword();
      await BackupV2Format.encodeToSink(
        plan: BackupV2ExportPlan(
          manifestPayload: payload,
          attachmentSourcesById: {
            payload.data.attachments.single.id: BackupV2AttachmentSource(
              attachment: payload.data.attachments.single,
              openEncryptedStream: () =>
                  Stream<List<int>>.value(attachmentBytes),
            ),
          },
        ),
        backupPassword: password,
        sink: sink,
        iterations: 2,
      );
      final staging = _MemoryStaging();

      await expectLater(
        BackupV2Format.decodeAndStage(
          source: _ChunkedMemorySource(
            Uint8List.sublistView(sink.bytes, 0, sink.bytes.length - 24),
          ),
          backupPassword: password,
          stagingFactory: (payload, attachmentEncoding) async => staging,
        ),
        throwsA(
          isA<BackupV2FormatException>().having(
            (error) => error.type,
            'type',
            BackupV2FormatErrorType.incompleteCommit,
          ),
        ),
      );
      expect(staging.abortCalled, isTrue);
      expect(staging.completeCalled, isFalse);
    });

    test('认证帧被篡改时拒绝恢复并清理 staging', () async {
      final attachmentBytes = Uint8List.fromList(List<int>.filled(128, 5));
      final payload = _payload(encryptedSize: attachmentBytes.length);
      final sink = _MemorySink();
      final password = _ephemeralPassword();
      await BackupV2Format.encodeToSink(
        plan: BackupV2ExportPlan(
          manifestPayload: payload,
          attachmentSourcesById: {
            payload.data.attachments.single.id: BackupV2AttachmentSource(
              attachment: payload.data.attachments.single,
              openEncryptedStream: () =>
                  Stream<List<int>>.value(attachmentBytes),
            ),
          },
        ),
        backupPassword: password,
        sink: sink,
        iterations: 2,
      );
      final corrupted = Uint8List.fromList(sink.bytes);
      corrupted[corrupted.length - 100] ^= 0x01;
      final staging = _MemoryStaging();

      await expectLater(
        BackupV2Format.decodeAndStage(
          source: _ChunkedMemorySource(corrupted),
          backupPassword: password,
          stagingFactory: (payload, attachmentEncoding) async => staging,
        ),
        throwsA(
          isA<BackupV2FormatException>().having(
            (error) => error.type,
            'type',
            BackupV2FormatErrorType.invalidPasswordOrCorruptedData,
          ),
        ),
      );
      expect(staging.abortCalled, isTrue);
    });

    test('导出前估算涵盖全部附件字节与帧开销', () async {
      final attachmentBytes = Uint8List.fromList(List<int>.filled(2, 8));
      final payload = _payload(encryptedSize: attachmentBytes.length);
      final plan = BackupV2ExportPlan(
        manifestPayload: payload,
        attachmentSourcesById: {
          payload.data.attachments.single.id: BackupV2AttachmentSource(
            attachment: payload.data.attachments.single,
            openEncryptedStream: () => Stream<List<int>>.value(attachmentBytes),
          ),
        },
      );
      final preflight = await BackupV2Format.preflight(plan);

      expect(preflight.attachmentBytes, attachmentBytes.length);
      expect(preflight.attachmentCount, 1);
      expect(
        preflight.estimatedOutputBytes,
        greaterThan(attachmentBytes.length),
      );
    });

    test('碎片化附件流跨读取块固定组帧，进度以完整长度结束', () async {
      final attachmentBytes = Uint8List.fromList(
        List<int>.generate(
          BackupV2Format.framePlaintextLimit + 17,
          (index) => index % 251,
        ),
      );
      final payload = _payload(encryptedSize: attachmentBytes.length);
      final sink = _MemorySink();
      final progress = <({int written, int total})>[];
      final fragments = <Uint8List>[];
      for (
        var offset = 0;
        offset < attachmentBytes.length;
        offset += 64 * 1024
      ) {
        fragments.add(
          Uint8List.sublistView(
            attachmentBytes,
            offset,
            min(offset + 64 * 1024, attachmentBytes.length),
          ),
        );
      }

      final written = await BackupV2Format.encodeToSink(
        plan: BackupV2ExportPlan(
          manifestPayload: payload,
          attachmentSourcesById: {
            payload.data.attachments.single.id: BackupV2AttachmentSource(
              attachment: payload.data.attachments.single,
              openEncryptedStream: () =>
                  Stream<List<int>>.fromIterable(fragments),
            ),
          },
        ),
        backupPassword: _ephemeralPassword(),
        sink: sink,
        iterations: 2,
        createdAtForTest: 1,
        saltForTest: List<int>.filled(16, 7),
        noncePrefixForTest: List<int>.filled(8, 9),
        onProgress: (writtenBytes, totalBytes) {
          progress.add((written: writtenBytes, total: totalBytes));
        },
      );

      expect(progress, isNotEmpty);
      expect(progress.first.written, 0);
      expect(progress.every((event) => event.total == written), isTrue);
      expect(progress.last, (written: written, total: written));
      for (var index = 1; index < progress.length; index++) {
        expect(
          progress[index].written,
          greaterThan(progress[index - 1].written),
        );
      }
    });

    test('附件来源按 ID 与排序后的 manifest 对齐，不依赖查询返回顺序', () async {
      final attachmentA = _attachment(
        id: 'attachment-a',
        itemId: 'item-a',
        fileName: 'a.enc',
        encryptedSize: 2,
      );
      final attachmentB = _attachment(
        id: 'attachment-b',
        itemId: 'item-b',
        fileName: 'b.enc',
        encryptedSize: 2,
      );
      final payload = _payloadWithAttachments([
        attachmentB,
        attachmentA,
      ]);
      final bytesA = Uint8List.fromList(const [1, 2]);
      final bytesB = Uint8List.fromList(const [3, 4]);
      final sink = _MemorySink();
      final password = _ephemeralPassword();

      await BackupV2Format.encodeToSink(
        plan: BackupV2ExportPlan(
          manifestPayload: payload,
          attachmentSourcesById: {
            attachmentB.id: BackupV2AttachmentSource(
              attachment: attachmentB,
              openEncryptedStream: () => Stream<List<int>>.value(bytesB),
            ),
            attachmentA.id: BackupV2AttachmentSource(
              attachment: attachmentA,
              openEncryptedStream: () => Stream<List<int>>.value(bytesA),
            ),
          },
        ),
        backupPassword: password,
        sink: sink,
        iterations: 2,
      );
      final staging = _MemoryStaging();
      await BackupV2Format.decodeAndStage(
        source: _ChunkedMemorySource(sink.bytes),
        backupPassword: password,
        stagingFactory: (payload, attachmentEncoding) async => staging,
      );

      // 清单规范化为 attachment-a、attachment-b；输入列表和来源 map 的顺序均不影响归属。
      expect(staging.bytesByAttachment[0], bytesA);
      expect(staging.bytesByAttachment[1], bytesB);
    });

    test('缺少对应 ID 的附件来源时在选择保存位置前安全失败', () async {
      final payload = _payload(encryptedSize: 2);
      final source = payload.data.attachments.single;

      await expectLater(
        BackupV2Format.preflight(
          BackupV2ExportPlan(
            manifestPayload: payload,
            attachmentSourcesById: {
              'unrelated-attachment': BackupV2AttachmentSource(
                attachment: source,
                openEncryptedStream: () =>
                    Stream<List<int>>.value(Uint8List.fromList(const [1, 2])),
              ),
            },
          ),
        ),
        throwsA(
          isA<BackupV2FormatException>().having(
            (error) => error.type,
            'type',
            BackupV2FormatErrorType.sourceUnavailable,
          ),
        ),
      );
    });

    test('附件来源长度不完整时整体失败，绝不静默跳过', () async {
      final payload = _payload(encryptedSize: 3);
      final sink = _MemorySink();

      await expectLater(
        BackupV2Format.encodeToSink(
          plan: BackupV2ExportPlan(
            manifestPayload: payload,
            attachmentSourcesById: {
              payload.data.attachments.single.id: BackupV2AttachmentSource(
                attachment: payload.data.attachments.single,
                openEncryptedStream: () =>
                    Stream<List<int>>.value(Uint8List.fromList(const [1, 2])),
              ),
            },
          ),
          backupPassword: _ephemeralPassword(),
          sink: sink,
          iterations: 2,
        ),
        throwsA(
          isA<BackupV2FormatException>().having(
            (error) => error.type,
            'type',
            BackupV2FormatErrorType.sourceUnavailable,
          ),
        ),
      );
    });

    test('附件流读取异常时标记为不可读取而非保存写入失败', () async {
      final payload = _payload(encryptedSize: 1);
      final sink = _MemorySink();

      await expectLater(
        BackupV2Format.encodeToSink(
          plan: BackupV2ExportPlan(
            manifestPayload: payload,
            attachmentSourcesById: {
              payload.data.attachments.single.id: BackupV2AttachmentSource(
                attachment: payload.data.attachments.single,
                openEncryptedStream: () =>
                    Stream<List<int>>.error(StateError('virtual read error')),
              ),
            },
          ),
          backupPassword: _ephemeralPassword(),
          sink: sink,
          iterations: 2,
        ),
        throwsA(
          isA<BackupV2FormatException>()
              .having(
                (error) => error.type,
                'type',
                BackupV2FormatErrorType.sourceUnavailable,
              )
              .having(
                (error) => error.unavailableAttachments.single.reason.name,
                'reason',
                'fileUnreadable',
              ),
        ),
      );
    });
  });
}

BackupPayloadV1 _payload({required int encryptedSize}) {
  return _payloadWithAttachments([
    _attachment(
      id: 'attachment',
      itemId: 'item',
      fileName: 'fictional.bin',
      encryptedSize: encryptedSize,
    ),
  ]);
}

BackupPayloadV1 _payloadWithAttachments(List<BackupAttachmentV1> attachments) {
  return BackupPayloadV1(
    exportedAt: 1,
    appVersion: 'test',
    schemaVersion: 8,
    source: BackupSourceInfo(appId: 'test', platform: 'test'),
    data: BackupDataV1(
      members: const [],
      items: const [],
      itemFields: const [],
      appSettings: const [],
      attachments: attachments,
      childEntries: const [],
      childFields: const [],
      itemEvents: const [],
      itemEventChanges: const [],
    ),
  );
}

BackupAttachmentV1 _attachment({
  required String id,
  required String itemId,
  required String fileName,
  required int encryptedSize,
}) {
  return BackupAttachmentV1(
    id: id,
    itemId: itemId,
    attachmentRole: 'other',
    fileName: fileName,
    mimeType: 'application/octet-stream',
    plainSize: encryptedSize,
    encryptedSize: encryptedSize,
    sortOrder: 0,
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
    encryptedData: '',
  );
}

String _ephemeralPassword() {
  final random = Random.secure();
  return List<String>.generate(
    20,
    (_) => String.fromCharCode(33 + random.nextInt(90)),
  ).join();
}

class _MemorySink implements BackupV2ByteSink {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List get bytes => _builder.toBytes();

  @override
  Future<void> write(Uint8List bytes) async {
    _builder.add(bytes);
  }
}

class _ChunkedMemorySource implements BackupV2ByteSource {
  final Uint8List bytes;
  final int maxChunk;
  var _offset = 0;

  int get bytesRead => _offset;

  _ChunkedMemorySource(this.bytes, {this.maxChunk = 173});

  @override
  Future<Uint8List?> readChunk() async {
    if (_offset == bytes.length) return null;
    final end = min(_offset + maxChunk, bytes.length);
    final result = Uint8List.sublistView(bytes, _offset, end);
    _offset = end;
    return result;
  }
}

class _MemoryStaging implements BackupV2AttachmentStaging {
  final Map<int, BytesBuilder> _builders = {};
  var completeCalled = false;
  var abortCalled = false;

  Map<int, Uint8List> get bytesByAttachment =>
      _builders.map((key, value) => MapEntry(key, value.toBytes()));

  @override
  Future<void> abort() async {
    abortCalled = true;
  }

  @override
  Future<void> complete() async {
    completeCalled = true;
  }

  @override
  Future<void> writeChunk({
    required int attachmentIndex,
    required Uint8List bytes,
  }) async {
    (_builders[attachmentIndex] ??= BytesBuilder(copy: false)).add(bytes);
  }
}
