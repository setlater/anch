import 'dart:io';
import 'dart:typed_data';

import 'package:anch/core/attachment/android_saf_attachment_file_read_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_image_crop_page.dart';
import 'attachment_image_selection.dart';

class ImportedAttachment {
  const ImportedAttachment({
    required this.bytes,
    required this.originalName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String originalName;
  final String mimeType;
}

class AttachmentImportException implements Exception {
  const AttachmentImportException(this.message);

  final String message;
}

/// 仅负责本地系统选择与图片处理；不写数据库或文件，不持有处理后的数据。
class AttachmentImportController {
  AttachmentImportController({AttachmentFileReadService? fileReadService})
    : _fileReadService =
          fileReadService ?? AndroidSafAttachmentFileReadService();

  static const int maxImportBytes = 20 * 1024 * 1024;
  static const int maxAttachmentCount = 12;

  static int remainingAttachmentSlots(int existingCount) =>
      existingCount >= maxAttachmentCount
      ? 0
      : maxAttachmentCount - existingCount;

  final AttachmentFileReadService _fileReadService;

  /// 目录引用仅由 Android 宿主短暂保留，用于同一编辑会话连续选择文件。
  Future<void> clearFilePickerSessionLocation() =>
      _fileReadService.clearSessionPickerLocation();

  Future<ImportedAttachment?> pickImage(
    NavigatorState navigator, {
    required ImageSource source,
  }) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return null;
    final croppedFile = await cropPickedImage(navigator, file);
    if (croppedFile == null) return null;
    try {
      final bytes = await croppedFile.readAsBytes();
      if (bytes.isEmpty) return null;
      return ImportedAttachment(
        bytes: Uint8List.fromList(bytes),
        originalName: file.name,
        mimeType: 'image/jpeg',
      );
    } finally {
      await _deleteTemporaryFile(croppedFile.path);
    }
  }

  /// 对已由系统选择的图片执行压缩和可选裁剪。
  ///
  /// 用户在裁剪页直接确认时保留完整图片；取消则返回 null。返回的临时文件由调用方消费后删除。
  Future<XFile?> cropPickedImage(
    NavigatorState navigator,
    XFile pickedFile, {
    bool retainSourceWhenCancelled = false,
  }) async {
    XFile? croppedFile;
    try {
      croppedFile = await _cropImagePath(navigator, source: pickedFile);
      return croppedFile;
    } finally {
      if (croppedFile != null || !retainSourceWhenCancelled) {
        await _deleteTemporaryFile(pickedFile.path);
      }
    }
  }

  /// 未裁剪的图片保留原始字节，只校验应用附件大小限制。
  Future<XFile> prepareUncroppedImage(XFile pickedFile) async {
    if (await pickedFile.length() > maxImportBytes) {
      throw const AttachmentImportException('附件不能超过 20 MB。');
    }
    return pickedFile;
  }

  /// 将多选预览中确认的一张图片规范化后读入内存。
  ///
  /// 调用方完成加密写入后应立即清空返回字节。
  Future<ImportedAttachment?> importImageSelection(
    AttachmentImageSelection selection,
  ) async {
    final file = selection.wasCropped
        ? selection.file
        : await prepareUncroppedImage(selection.file);
    try {
      final bytes = await file.readAsBytes();
      try {
        if (bytes.isEmpty) return null;
        return ImportedAttachment(
          bytes: Uint8List.fromList(bytes),
          originalName: file.name,
          mimeType: _mimeTypeForUncroppedImage(file),
        );
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } finally {
      await _deleteTemporaryFile(file.path);
    }
  }

  Future<ImportedAttachment?> pickFile({
    NavigatorState? navigator,
    Future<AttachmentFileReadResult?> Function(
      Future<AttachmentFileReadResult?> Function() readFile,
    )?
    systemPickerGuard,
  }) async {
    final AttachmentFileReadResult? file;
    try {
      file = systemPickerGuard == null
          ? await _fileReadService.readFile()
          : await systemPickerGuard(_fileReadService.readFile);
    } on AttachmentFileReadException catch (error) {
      throw AttachmentImportException(error.message);
    }
    if (file == null) return null;
    if (file.bytes.lengthInBytes > maxImportBytes) {
      throw const AttachmentImportException('附件不能超过 20 MB。');
    }
    final bytes = file.bytes;
    if (bytes.isEmpty) return null;
    final mimeType = _supportedMimeType(file.mimeType, file.originalName);
    if (mimeType == null) {
      throw const AttachmentImportException('请选择图片、PDF 或常见文档。');
    }
    if (!mimeType.startsWith('image/')) {
      return ImportedAttachment(
        bytes: bytes,
        originalName: file.originalName,
        mimeType: mimeType,
      );
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final temporaryFile = File(
      p.join(
        temporaryDirectory.path,
        'attachment-import-${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    try {
      await temporaryFile.writeAsBytes(bytes, flush: true);
      final croppedFile = await _cropImagePath(
        navigator,
        source: XFile(
          temporaryFile.path,
          name: file.originalName,
          mimeType: mimeType,
        ),
      );
      if (croppedFile == null) return null;
      try {
        final bytes = await croppedFile.readAsBytes();
        if (bytes.isEmpty) return null;
        return ImportedAttachment(
          bytes: Uint8List.fromList(bytes),
          originalName: file.originalName,
          mimeType: 'image/jpeg',
        );
      } finally {
        await _deleteTemporaryFile(croppedFile.path);
      }
    } finally {
      try {
        await temporaryFile.delete();
      } catch (_) {}
    }
  }

  static String? _supportedMimeType(String mimeType, String originalName) {
    const supportedMimeTypes = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
      'text/plain',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    if (supportedMimeTypes.contains(mimeType)) return mimeType;
    final extension = p.extension(originalName).replaceFirst('.', '');
    final inferredMimeType = mimeTypeForExtension(extension);
    return supportedMimeTypes.contains(inferredMimeType)
        ? inferredMimeType
        : null;
  }

  static String _mimeTypeForUncroppedImage(XFile file) {
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }
    final inferred = mimeTypeForExtension(
      p.extension(file.name).replaceFirst('.', ''),
    );
    return inferred.startsWith('image/') ? inferred : 'image/jpeg';
  }

  Future<XFile?> _cropImagePath(
    NavigatorState? navigator, {
    required XFile source,
  }) async {
    if (await source.length() > maxImportBytes) {
      throw const AttachmentImportException('附件不能超过 20 MB。');
    }
    try {
      if (navigator == null) {
        throw const AttachmentImportException('无法打开图片裁剪页，请重试。');
      }
      return await navigator.push<XFile>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AttachmentImageCropPage(source: source),
        ),
      );
    } on AttachmentImportException {
      rethrow;
    } catch (_) {
      throw const AttachmentImportException('无法处理图片，请重试。');
    }
  }

  Future<void> _deleteTemporaryFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  static String mimeTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
