import 'dart:io';
import 'dart:typed_data';

import 'package:anch/core/attachment/android_saf_attachment_file_read_service.dart';
import 'package:anch/features/item_detail/attachment_image_gallery_selection.dart';
import 'package:anch/features/item_detail/attachment_import_controller.dart';
import 'package:anch/features/item_detail/attachment_image_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

void main() {
  test('附件导入只为受支持的文件类型推断 MIME 类型', () {
    expect(
      AttachmentImportController.mimeTypeForExtension('JPG'),
      'image/jpeg',
    );
    expect(
      AttachmentImportController.mimeTypeForExtension('pdf'),
      'application/pdf',
    );
    expect(
      AttachmentImportController.mimeTypeForExtension('unknown'),
      'application/octet-stream',
    );
  });

  test('附件导入大小上限为 20 MB', () {
    expect(AttachmentImportController.maxImportBytes, 20 * 1024 * 1024);
  });

  test('详情与录入共用的附件数量上限为 12，且按已有数量计算名额', () {
    expect(AttachmentImportController.maxAttachmentCount, 12);
    expect(AttachmentImportController.remainingAttachmentSlots(0), 12);
    expect(AttachmentImportController.remainingAttachmentSlots(8), 4);
    expect(AttachmentImportController.remainingAttachmentSlots(12), 0);
    expect(AttachmentImportController.remainingAttachmentSlots(99), 0);
  });

  test('系统相册未限制超额选择时要求重新选择，不静默截断', () {
    expect(
      () => validateAttachmentGallerySelectionCount(selectedCount: 5, limit: 4),
      throwsA(
        isA<AttachmentImportException>().having(
          (error) => error.message,
          'message',
          '本次最多可添加 4 张图片，请重新选择。',
        ),
      ),
    );
  });

  test('只剩一个附件名额时使用单图选择接口', () async {
    final originalPlatform = ImagePickerPlatform.instance;
    final platform = _SingleImageOnlyPickerPlatform();
    ImagePickerPlatform.instance = platform;
    addTearDown(() => ImagePickerPlatform.instance = originalPlatform);
    var systemPickerGuardCalled = false;

    final selections = await pickAttachmentGalleryImages(
      _UnusedNavigatorState(),
      limit: 1,
      cropPickedImage:
          (navigator, file, {retainSourceWhenCancelled = false}) async => file,
      systemPickerGuard: (pickImages) async {
        systemPickerGuardCalled = true;
        return pickImages();
      },
    );

    expect(selections, isEmpty);
    expect(platform.singleImageRequested, isTrue);
    expect(platform.multiImageRequested, isFalse);
    expect(systemPickerGuardCalled, isTrue);
    expect(platform.singleImageOptions?.maxWidth, isNull);
    expect(platform.singleImageOptions?.maxHeight, isNull);
    expect(platform.singleImageOptions?.imageQuality, isNull);
  });

  test('多选相册不在系统选择阶段压缩图片', () async {
    final originalPlatform = ImagePickerPlatform.instance;
    final platform = _SingleImageOnlyPickerPlatform();
    ImagePickerPlatform.instance = platform;
    addTearDown(() => ImagePickerPlatform.instance = originalPlatform);

    final selections = await pickAttachmentGalleryImages(
      _UnusedNavigatorState(),
      limit: 2,
      cropPickedImage:
          (navigator, file, {retainSourceWhenCancelled = false}) async => file,
    );

    expect(selections, isEmpty);
    expect(platform.multiImageRequested, isTrue);
    expect(platform.multiImageOptions?.imageOptions.maxWidth, isNull);
    expect(platform.multiImageOptions?.imageOptions.maxHeight, isNull);
    expect(platform.multiImageOptions?.imageOptions.imageQuality, isNull);
  });

  test('多选预览已裁剪图片逐张转换为可加密保存的附件', () async {
    final directory = await Directory.systemTemp.createTemp('anch-import-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/selected.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final controller = AttachmentImportController();
    final attachment = await controller.importImageSelection(
      AttachmentImageSelection(
        file: XFile(source.path, name: 'selected.jpg', mimeType: 'image/jpeg'),
        wasCropped: true,
      ),
    );

    expect(attachment, isNotNull);
    expect(attachment!.bytes, Uint8List.fromList([1, 2, 3]));
    expect(attachment.originalName, 'selected.jpg');
    expect(attachment.mimeType, 'image/jpeg');
  });

  test('多选预览未裁剪图片保留原始字节和 MIME 类型', () async {
    final directory = await Directory.systemTemp.createTemp('anch-import-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/selected.png');
    await source.writeAsBytes([1, 2, 3]);
    final controller = AttachmentImportController();

    final attachment = await controller.importImageSelection(
      AttachmentImageSelection(
        file: XFile(source.path, name: 'selected.png', mimeType: 'image/png'),
        wasCropped: false,
      ),
    );

    expect(attachment, isNotNull);
    expect(attachment!.bytes, Uint8List.fromList([1, 2, 3]));
    expect(attachment.mimeType, 'image/png');
  });

  test('通用文件经 SAF 读取后保持字节和受支持 MIME 类型', () async {
    final controller = AttachmentImportController(
      fileReadService: _FakeAttachmentFileReadService(
        AttachmentFileReadResult(
          bytes: Uint8List.fromList([1, 2, 3]),
          originalName: 'document.pdf',
          mimeType: 'application/pdf',
        ),
      ),
    );

    final attachment = await controller.pickFile();

    expect(attachment, isNotNull);
    expect(attachment!.bytes, Uint8List.fromList([1, 2, 3]));
    expect(attachment.mimeType, 'application/pdf');
    expect(attachment.originalName, 'document.pdf');
  });

  test('SAF 返回不受支持的文件时不进入持久化流程', () async {
    final controller = AttachmentImportController(
      fileReadService: _FakeAttachmentFileReadService(
        AttachmentFileReadResult(
          bytes: Uint8List.fromList([1, 2, 3]),
          originalName: 'unknown.bin',
          mimeType: 'application/octet-stream',
        ),
      ),
    );

    expect(controller.pickFile(), throwsA(isA<AttachmentImportException>()));
  });
}

class _SingleImageOnlyPickerPlatform extends ImagePickerPlatform {
  bool singleImageRequested = false;
  bool multiImageRequested = false;
  ImagePickerOptions? singleImageOptions;
  MultiImagePickerOptions? multiImageOptions;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    singleImageRequested = true;
    singleImageOptions = options;
    return null;
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiImageRequested = true;
    multiImageOptions = options;
    return const [];
  }
}

class _UnusedNavigatorState extends NavigatorState {}

class _FakeAttachmentFileReadService implements AttachmentFileReadService {
  const _FakeAttachmentFileReadService(this.result);

  final AttachmentFileReadResult? result;

  @override
  Future<AttachmentFileReadResult?> readFile() async => result;

  @override
  Future<void> clearSessionPickerLocation() async {}
}
