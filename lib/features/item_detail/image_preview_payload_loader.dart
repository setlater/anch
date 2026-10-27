import 'dart:typed_data';

import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/core/attachment/attachment_payload_reader.dart';
import 'package:anch/core/attachment/attachment_preview_cache.dart';
import 'package:anch/core/attachment/attachment_thumbnail_service.dart';
import 'package:anch/core/attachment/image_dimension_reader.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// 图片预览实际使用的明文，以及它是否为可替代的缓存预览。
class ImagePreviewPayload {
  const ImagePreviewPayload({
    required this.bytes,
    required this.usesPreview,
    this.invalidatePreview,
  });

  final Uint8List bytes;
  final bool usesPreview;
  final Future<void> Function()? invalidatePreview;
}

typedef ImagePayloadRead = Future<Uint8List> Function(AttachmentModel);
typedef CachedPreviewRead = Future<Uint8List?> Function(AttachmentModel);
typedef CachedPreviewWrite =
    Future<void> Function(AttachmentModel attachment, Uint8List previewBytes);
typedef CachedPreviewInvalidate = Future<void> Function(AttachmentModel);
typedef ImagePreviewEncode =
    Future<Uint8List> Function(
      Uint8List source,
      ImagePixelSize size,
      String mimeType,
    );
typedef ImageThumbnailStore =
    Future<void> Function(AttachmentModel attachment, Uint8List sourceBytes);

/// 仅在用户主动打开图片时按需生成预览；首次失败始终回退到原图。
class ImagePreviewPayloadLoader {
  static const int previewLongSide = 2560;

  ImagePreviewPayloadLoader({
    ImagePayloadRead? readOriginal,
    CachedPreviewRead? readCachedPreview,
    CachedPreviewWrite? writeCachedPreview,
    CachedPreviewInvalidate? invalidateCachedPreview,
    ImagePreviewEncode? encodePreview,
    ImageThumbnailStore? saveThumbnail,
  }) : _readOriginal = readOriginal ?? AttachmentPayloadReader.readInBackground,
       _readCachedPreview = readCachedPreview ?? AttachmentPreviewCache.read,
       _writeCachedPreview = writeCachedPreview ?? AttachmentPreviewCache.write,
       _invalidateCachedPreview = invalidateCachedPreview ?? _deletePreview,
       _encodePreview = encodePreview ?? _encodeWithPlatform,
       _saveThumbnail = saveThumbnail ?? _storeThumbnail;

  final ImagePayloadRead _readOriginal;
  final CachedPreviewRead _readCachedPreview;
  final CachedPreviewWrite _writeCachedPreview;
  final CachedPreviewInvalidate _invalidateCachedPreview;
  final ImagePreviewEncode _encodePreview;
  final ImageThumbnailStore _saveThumbnail;

  Future<ImagePreviewPayload> load(
    AttachmentModel attachment, {
    required bool forceOriginal,
    void Function()? onPreparingPreview,
    bool Function()? shouldStorePreview,
  }) async {
    if (!forceOriginal) {
      final cachedPreview = await _readCachedPreview(attachment);
      if (cachedPreview != null) {
        await _saveThumbnail(attachment, cachedPreview);
        return ImagePreviewPayload(
          bytes: cachedPreview,
          usesPreview: true,
          invalidatePreview: () => _invalidateCachedPreview(attachment),
        );
      }
    }

    final original = await _readOriginal(attachment);
    if (forceOriginal) {
      return ImagePreviewPayload(bytes: original, usesPreview: false);
    }

    final dimensions = ImageDimensionReader.read(original);
    if (dimensions == null || dimensions.longSide <= previewLongSide) {
      if (dimensions != null) await _saveThumbnail(attachment, original);
      return ImagePreviewPayload(bytes: original, usesPreview: false);
    }

    Uint8List? preview;
    try {
      onPreparingPreview?.call();
      preview = await _encodePreview(original, dimensions, attachment.mimeType);
      if (preview.isEmpty ||
          (shouldStorePreview != null && !shouldStorePreview())) {
        preview.fillRange(0, preview.length, 0);
        return ImagePreviewPayload(bytes: original, usesPreview: false);
      }
      await _writeCachedPreview(attachment, preview);
      await _saveThumbnail(attachment, preview);
      original.fillRange(0, original.length, 0);
      return ImagePreviewPayload(
        bytes: preview,
        usesPreview: true,
        invalidatePreview: () => _invalidateCachedPreview(attachment),
      );
    } catch (_) {
      // 预览属于派生缓存；生成失败绝不能影响原图查看。
      preview?.fillRange(0, preview.length, 0);
      return ImagePreviewPayload(bytes: original, usesPreview: false);
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
      quality: 90,
      format: mimeType.toLowerCase() == 'image/png'
          ? CompressFormat.png
          : CompressFormat.jpeg,
      keepExif: false,
    );
  }

  static Future<void> _deletePreview(AttachmentModel attachment) =>
      AttachmentPreviewCache.deleteForFileName(attachment.fileName);

  static ImagePixelSize _targetSize(ImagePixelSize size) {
    if (size.width >= size.height) {
      return ImagePixelSize(
        width: previewLongSide,
        height: (size.height * previewLongSide / size.width).round(),
      );
    }
    return ImagePixelSize(
      width: (size.width * previewLongSide / size.height).round(),
      height: previewLongSide,
    );
  }

  static Future<void> _storeThumbnail(
    AttachmentModel attachment,
    Uint8List sourceBytes,
  ) {
    return AttachmentThumbnailService.generateAndStore(
      attachmentFileName: attachment.fileName,
      sourceBytes: sourceBytes,
      mimeType: attachment.mimeType,
      documentsDirectoryProvider: getApplicationDocumentsDirectory,
    );
  }
}
