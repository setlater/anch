import 'package:flutter/services.dart';

import 'backup_file_policy.dart';
import 'backup_file_read_service.dart';
import 'backup_file_save_service.dart';
import 'backup_v2_format.dart';

/// Android SAF 的 V2 分块写入会话。
///
/// 原生端只保留系统选择器打开的输出流；Dart 每次跨平台传递至多一个 V2 帧，因此不会再把整份备份复制到
/// MethodChannel 的单一 `ByteArray`。中断时只关闭流，不删除用户选择位置上可能出现的未提交文件。
class AndroidSafBackupV2WriteSession implements BackupV2ByteSink {
  static const _channel = MethodChannel('anch/backup_stream_v2');

  final String fileName;
  final String mimeType;
  bool _closed = false;
  int _writtenBytes = 0;

  AndroidSafBackupV2WriteSession._({
    required this.fileName,
    required this.mimeType,
  });

  static Future<AndroidSafBackupV2WriteSession> begin({
    required String fileName,
    required String mimeType,
  }) async {
    if (!BackupFilePolicy.isLikelyBackupFileName(fileName) ||
        mimeType != BackupFilePolicy.defaultMimeType) {
      throw BackupFileSaveException(
        BackupFileSaveErrorType.invalidPackage,
        '备份文件参数不正确。',
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'beginStreamingBackupDocument',
        <String, Object>{'fileName': fileName, 'mimeType': mimeType},
      );
      if (raw == null || raw['success'] != true) {
        throw BackupFileSaveException(
          BackupFileSaveErrorType.targetWriteFailed,
          '备份文件写入失败，未确认生成可用文件。',
        );
      }
      return AndroidSafBackupV2WriteSession._(
        fileName: fileName,
        mimeType: mimeType,
      );
    } on PlatformException catch (error) {
      throw BackupFileSaveException(
        _mapErrorCode(error.code),
        _mapErrorMessage(_mapErrorCode(error.code)),
      );
    }
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (_closed ||
        bytes.isEmpty ||
        bytes.length > BackupV2Format.framePlaintextLimit) {
      throw BackupFileSaveException(
        BackupFileSaveErrorType.writeFailed,
        '备份文件写入失败，未确认生成可用文件。',
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'writeStreamingBackupChunk',
        <String, Object>{'bytes': bytes},
      );
      if (raw == null || raw['success'] != true) {
        throw BackupFileSaveException(
          BackupFileSaveErrorType.writeFailed,
          '备份文件写入失败，未确认生成可用文件。',
        );
      }
      _writtenBytes += bytes.length;
    } on PlatformException catch (error) {
      throw BackupFileSaveException(
        _mapWriteErrorCode(error.code, hasWrittenBytes: _writtenBytes > 0),
        _mapErrorMessage(
          _mapWriteErrorCode(error.code, hasWrittenBytes: _writtenBytes > 0),
        ),
      );
    }
  }

  Future<BackupFileSaveResult> finish({required int expectedSizeBytes}) async {
    if (_closed) {
      throw BackupFileSaveException(
        BackupFileSaveErrorType.writeFailed,
        '备份文件写入失败，未确认生成可用文件。',
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'finishStreamingBackupDocument',
      );
      _closed = true;
      if (raw == null || raw['success'] != true) {
        throw BackupFileSaveException(
          BackupFileSaveErrorType.finalizationFailed,
          '备份文件写入失败，未确认生成可用文件。',
        );
      }
      final actualSize = raw['sizeBytes'];
      if (actualSize is! int || actualSize != expectedSizeBytes) {
        throw BackupFileSaveException(
          BackupFileSaveErrorType.finalizationFailed,
          '备份文件写入失败，未确认生成可用文件。',
        );
      }
      return BackupFileSaveResult(
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: actualSize,
        savedAt:
            (raw['savedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        displayLocation: '系统选择的位置',
        isSuccess: true,
      );
    } on PlatformException catch (error) {
      _closed = true;
      throw BackupFileSaveException(
        _mapFinalizationErrorCode(error.code),
        _mapErrorMessage(_mapFinalizationErrorCode(error.code)),
      );
    }
  }

  Future<void> abort() async {
    if (_closed) return;
    _closed = true;
    try {
      await _channel.invokeMethod<void>('abortStreamingBackupDocument');
    } catch (_) {
      // 中止后的原生流只可能是无提交帧的残留，不向调用者泄露平台异常。
    }
  }

  static BackupFileSaveErrorType _mapErrorCode(String code) {
    switch (code) {
      case 'userCancelled':
        return BackupFileSaveErrorType.userCancelled;
      case 'permissionDenied':
        return BackupFileSaveErrorType.permissionDenied;
      case 'storageUnavailable':
        return BackupFileSaveErrorType.storageUnavailable;
      case 'insufficientSpace':
        return BackupFileSaveErrorType.insufficientSpace;
      case 'targetWriteFailed':
        return BackupFileSaveErrorType.targetWriteFailed;
      case 'operationInProgress':
        return BackupFileSaveErrorType.operationInProgress;
      case 'writeInterrupted':
        return BackupFileSaveErrorType.writeInterrupted;
      case 'systemPickerUnavailable':
        return BackupFileSaveErrorType.systemPickerUnavailable;
      case 'finalizationFailed':
        return BackupFileSaveErrorType.finalizationFailed;
      case 'writeFailed':
        return BackupFileSaveErrorType.writeFailed;
      default:
        return BackupFileSaveErrorType.unknown;
    }
  }

  static BackupFileSaveErrorType _mapWriteErrorCode(
    String code, {
    required bool hasWrittenBytes,
  }) {
    final mapped = _mapErrorCode(code);
    if (mapped == BackupFileSaveErrorType.writeFailed && !hasWrittenBytes) {
      return BackupFileSaveErrorType.targetWriteFailed;
    }
    return mapped;
  }

  static BackupFileSaveErrorType _mapFinalizationErrorCode(String code) {
    final mapped = _mapErrorCode(code);
    return mapped == BackupFileSaveErrorType.writeFailed
        ? BackupFileSaveErrorType.finalizationFailed
        : mapped;
  }

  static String _mapErrorMessage(BackupFileSaveErrorType type) {
    switch (type) {
      case BackupFileSaveErrorType.userCancelled:
        return '导出已取消，未写入备份文件。';
      case BackupFileSaveErrorType.insufficientSpace:
        return '保存位置空间不足，未确认生成可用备份。';
      case BackupFileSaveErrorType.permissionDenied:
        return '系统未授予写入权限，导出未完成。';
      case BackupFileSaveErrorType.storageUnavailable:
        return '保存服务不可用。';
      case BackupFileSaveErrorType.targetWriteFailed:
        return '无法开始写入所选保存位置。';
      case BackupFileSaveErrorType.operationInProgress:
        return '上一次文件操作尚未结束。';
      case BackupFileSaveErrorType.writeInterrupted:
        return '系统保存写入被中断。';
      case BackupFileSaveErrorType.finalizationFailed:
        return '文件写入后无法完成确认。';
      case BackupFileSaveErrorType.systemPickerUnavailable:
        return '当前设备无法打开系统文件选择器。';
      default:
        return '备份文件写入失败，未确认生成可用文件。';
    }
  }
}

/// 已由普通 SAF 选择流程识别出的 V2 文件读取会话。
///
/// 选择动作仍只发生一次：原有读取通道检测到 V2 魔数后保留原生输入流，本类只读取该已选文件的有限分块。
class AndroidSafBackupV2ReadSession implements BackupV2ByteSource {
  static const _channel = MethodChannel('anch/backup_stream_v2');

  final int? sizeBytes;
  bool _closed = false;

  AndroidSafBackupV2ReadSession._({required this.sizeBytes});

  static Future<AndroidSafBackupV2ReadSession> openSelected() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getSelectedStreamingBackupInfo',
      );
      if (raw == null || raw['success'] != true) {
        throw BackupFileReadException(
          BackupFileReadErrorType.readFailed,
          '备份文件读取失败。',
        );
      }
      final rawSize = raw['sizeBytes'];
      return AndroidSafBackupV2ReadSession._(
        sizeBytes: rawSize is int && rawSize >= 0 ? rawSize : null,
      );
    } on PlatformException catch (error) {
      throw BackupFileReadException(
        _mapReadErrorCode(error.code),
        _mapReadErrorMessage(_mapReadErrorCode(error.code)),
      );
    }
  }

  @override
  Future<Uint8List?> readChunk() async {
    if (_closed) return null;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'readSelectedStreamingBackupChunk',
      );
      if (raw == null || raw['success'] != true) {
        throw BackupFileReadException(
          BackupFileReadErrorType.readFailed,
          '备份文件读取失败。',
        );
      }
      if (raw['eof'] == true) {
        return null;
      }
      final bytes = raw['bytes'];
      if (bytes is! Uint8List || bytes.isEmpty) {
        throw BackupFileReadException(
          BackupFileReadErrorType.invalidFile,
          '备份文件内容已损坏。',
        );
      }
      return bytes;
    } on PlatformException catch (error) {
      throw BackupFileReadException(
        _mapReadErrorCode(error.code),
        _mapReadErrorMessage(_mapReadErrorCode(error.code)),
      );
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _channel.invokeMethod<void>('closeSelectedStreamingBackupRead');
    } catch (_) {
      // 输入流只保存外部加密字节；关闭失败不向 UI 暴露底层细节。
    }
  }

  /// 密码认证失败后重新打开当前前台会话选择的同一只读文件，不再次弹出文件选择器。
  Future<void> restart() async {
    if (_closed) {
      throw BackupFileReadException(
        BackupFileReadErrorType.readFailed,
        '备份文件读取失败。',
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'restartSelectedStreamingBackupRead',
      );
      if (raw == null || raw['success'] != true) {
        throw BackupFileReadException(
          BackupFileReadErrorType.readFailed,
          '备份文件读取失败。',
        );
      }
    } on PlatformException catch (error) {
      throw BackupFileReadException(
        _mapReadErrorCode(error.code),
        _mapReadErrorMessage(_mapReadErrorCode(error.code)),
      );
    }
  }

  static BackupFileReadErrorType _mapReadErrorCode(String code) {
    switch (code) {
      case 'userCancelled':
        return BackupFileReadErrorType.userCancelled;
      case 'permissionDenied':
        return BackupFileReadErrorType.permissionDenied;
      case 'fileUnavailable':
        return BackupFileReadErrorType.fileUnavailable;
      case 'systemPickerUnavailable':
        return BackupFileReadErrorType.systemPickerUnavailable;
      case 'invalidFile':
        return BackupFileReadErrorType.invalidFile;
      default:
        return BackupFileReadErrorType.readFailed;
    }
  }

  static String _mapReadErrorMessage(BackupFileReadErrorType type) {
    switch (type) {
      case BackupFileReadErrorType.userCancelled:
        return '已取消选择备份文件。';
      case BackupFileReadErrorType.permissionDenied:
        return '系统未授予读取权限，无法打开文件。';
      case BackupFileReadErrorType.fileUnavailable:
        return '备份文件暂不可用。';
      case BackupFileReadErrorType.systemPickerUnavailable:
        return '当前设备无法打开系统文件选择器。';
      case BackupFileReadErrorType.invalidFile:
        return '备份文件内容已损坏。';
      default:
        return '备份文件读取失败。';
    }
  }
}
