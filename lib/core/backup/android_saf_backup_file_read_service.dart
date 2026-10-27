import 'package:flutter/services.dart';
import 'backup_file_codec.dart';
import 'backup_file_policy.dart';
import 'backup_file_read_service.dart';

/// Android 平台 SAF 物理文件读取服务。
class AndroidSafBackupFileReadService implements BackupFileReadService {
  static const _channel = MethodChannel('anch/backup_file_read');

  @override
  Future<BackupFileReadResult> readBackupFile() async {
    try {
      final Map<Object?, Object?>? rawResult = await _channel
          .invokeMethod<Map<Object?, Object?>>('openBackupDocumentAndRead');

      if (rawResult == null || rawResult['success'] != true) {
        throw BackupFileReadException(
          BackupFileReadErrorType.unknown,
          '读取备份文件返回空结果',
        );
      }

      final dynamic rawBytes = rawResult['bytes'];
      if (rawBytes is! Uint8List) {
        throw BackupFileReadException(
          BackupFileReadErrorType.invalidFile,
          '读取到的备份包格式不正确，数据内容损坏',
        );
      }

      final Uint8List bytes = rawBytes;

      // 1. 前置大小防空与超载二次把关校验
      if (bytes.isEmpty) {
        throw BackupFileReadException(
          BackupFileReadErrorType.invalidFile,
          '备份文件数据为空',
        );
      }

      if (bytes.length > BackupFileCodec.maxBackupFileBytes) {
        throw BackupFileReadException(
          BackupFileReadErrorType.fileTooLarge,
          '备份文件体积超载，无法加载',
        );
      }

      final int readAt =
          (rawResult['readAt'] as int?) ??
          DateTime.now().millisecondsSinceEpoch;
      final String sizeLabel = BackupFilePolicy.formatBytes(bytes.length);

      // 2. 返回脱敏读取结果，displaySource 固定为 `'系统选择的文件'`
      return BackupFileReadResult(
        bytes: bytes,
        sizeBytes: bytes.length,
        sizeLabel: sizeLabel,
        readAt: readAt,
        displaySource: '系统选择的文件', // ⚠️ 统一脱敏要求
      );
    } on PlatformException catch (e) {
      // 3. 将 PlatformException 的 code 映射为 BackupFileReadErrorType
      final errorType = _mapErrorCode(e.code);
      throw BackupFileReadException(
        errorType,
        // message 仅为固定脱敏中文字句，严禁拼接底层异常原文以防泄露
        _mapErrorMessage(errorType),
      );
    } on BackupFileReadException {
      rethrow;
    } catch (e) {
      throw BackupFileReadException(
        BackupFileReadErrorType.unknown,
        '备份读取遇到未知错误',
      );
    }
  }

  BackupFileReadErrorType _mapErrorCode(String code) {
    switch (code) {
      case 'userCancelled':
        return BackupFileReadErrorType.userCancelled;
      case 'permissionDenied':
        return BackupFileReadErrorType.permissionDenied;
      case 'fileUnavailable':
        return BackupFileReadErrorType.fileUnavailable;
      case 'fileTooLarge':
        return BackupFileReadErrorType.fileTooLarge;
      case 'systemPickerUnavailable':
        return BackupFileReadErrorType.systemPickerUnavailable;
      case 'readFailed':
        return BackupFileReadErrorType.readFailed;
      case 'invalidFile':
        return BackupFileReadErrorType.invalidFile;
      case 'streamV2Selected':
        return BackupFileReadErrorType.streamingV2Selected;
      default:
        return BackupFileReadErrorType.unknown;
    }
  }

  String _mapErrorMessage(BackupFileReadErrorType type) {
    switch (type) {
      case BackupFileReadErrorType.userCancelled:
        return '已取消选择备份文件';
      case BackupFileReadErrorType.permissionDenied:
        return '系统未授予读取权限，无法打开文件';
      case BackupFileReadErrorType.fileUnavailable:
        return '备份文件暂不可用';
      case BackupFileReadErrorType.fileTooLarge:
        return '备份文件体积超出 50MB 规格限制';
      case BackupFileReadErrorType.systemPickerUnavailable:
        return '当前设备无法打开系统文件选择器';
      case BackupFileReadErrorType.readFailed:
        return '备份文件读取失败';
      case BackupFileReadErrorType.invalidFile:
        return '备份文件内容已损坏';
      case BackupFileReadErrorType.streamingV2Selected:
        return '已选择流式备份文件';
      default:
        return '读取未完成，未知错误';
    }
  }
}
