import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'attachment_encrypted_file_writer.dart';
import 'attachment_thumbnail_cache.dart';
import 'image_dimension_reader.dart';

typedef AttachmentThumbnailSaver =
    Future<void> Function({
      required String attachmentFileName,
      required Uint8List sourceBytes,
      required String mimeType,
      required Future<Directory> Function() documentsDirectoryProvider,
    });

typedef AttachmentThumbnailEncoder =
    Future<Uint8List> Function(
      Uint8List source,
      ImagePixelSize size,
      String mimeType,
    );

/// 在附件导入或用户主动查看图片时生成低分辨率加密缩略图。
abstract final class AttachmentThumbnailService {
  static const int thumbnailLongSide = 256;

  static Future<void> generateAndStore({
    required String attachmentFileName,
    required Uint8List sourceBytes,
    required String mimeType,
    required Future<Directory> Function() documentsDirectoryProvider,
    AttachmentThumbnailEncoder? encode,
  }) async {
    if (!mimeType.toLowerCase().startsWith('image/')) return;
    final encoder = encode ?? _encodeWithPlatform;
    final sourceSize = ImageDimensionReader.read(sourceBytes);

    Uint8List? thumbnail;
    try {
      thumbnail = await encoder(
        sourceBytes,
        sourceSize ??
            const ImagePixelSize(
              width: thumbnailLongSide,
              height: thumbnailLongSide,
            ),
        mimeType,
      );
      if (thumbnail.isEmpty) return;

      // HEIC 等格式没有稳定的纯 Dart 文件头解析路径。先让原生编解码器生成
      // 一份小图；若仍超过目标长边，再根据输出 JPEG／PNG 的文件头收一次尺寸。
      final thumbnailSize = ImageDimensionReader.read(thumbnail);
      if (sourceSize == null &&
          thumbnailSize != null &&
          thumbnailSize.longSide > thumbnailLongSide) {
        final normalized = await encoder(thumbnail, thumbnailSize, mimeType);
        if (!identical(normalized, thumbnail)) {
          clearAttachmentPlaintext(thumbnail);
        }
        thumbnail = normalized;
        if (thumbnail.isEmpty) return;
      }

      await AttachmentThumbnailCache.write(
        attachmentFileName,
        thumbnail,
        documentsDirectoryProvider: documentsDirectoryProvider,
      );
    } catch (_) {
      // 缩略图为派生缓存；任何失败都不能阻断原附件导入或预览。
    } finally {
      if (thumbnail != null) clearAttachmentPlaintext(thumbnail);
    }
  }

  static Future<Uint8List> _encodeWithPlatform(
    Uint8List source,
    ImagePixelSize size,
    String mimeType,
  ) {
    final target = _targetSize(size);
    return FlutterImageCompress.compressWithList(
      source,
      minWidth: target.width,
      minHeight: target.height,
      quality: 85,
      format: mimeType.toLowerCase() == 'image/png'
          ? CompressFormat.png
          : CompressFormat.jpeg,
      keepExif: false,
    );
  }

  static ImagePixelSize _targetSize(ImagePixelSize size) {
    final longSide = size.longSide < thumbnailLongSide
        ? size.longSide
        : thumbnailLongSide;
    if (size.width >= size.height) {
      return ImagePixelSize(
        width: longSide,
        height: (size.height * longSide / size.width).round(),
      );
    }
    return ImagePixelSize(
      width: (size.width * longSide / size.height).round(),
      height: longSide,
    );
  }
}
