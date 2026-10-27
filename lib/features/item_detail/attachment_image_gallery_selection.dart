import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'attachment_import_controller.dart';
import 'attachment_image_selection_preview_page.dart';

/// 在系统相册选择器展示期间执行图片选择，避免页面生命周期干扰选择流程。
typedef AttachmentGallerySystemPickerGuard =
    Future<List<XFile>> Function(Future<List<XFile>> Function() pickImages);

/// 旧系统的相册可能忽略选择数量，返回后必须显式要求用户重选。
void validateAttachmentGallerySelectionCount({
  required int selectedCount,
  required int limit,
}) {
  if (selectedCount <= limit) return;
  throw AttachmentImportException('本次最多可添加 $limit 张图片，请重新选择。');
}

/// 从系统相册选择多张图片，并在写入前完成本地预览与可选裁剪。
Future<List<AttachmentImageSelection>> pickAttachmentGalleryImages(
  NavigatorState navigator, {
  required int limit,
  required AttachmentImageCropper cropPickedImage,
  AttachmentGallerySystemPickerGuard? systemPickerGuard,
}) async {
  if (limit <= 0) return const [];

  final imagePickerImplementation = ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }
  final imagePicker = ImagePicker();
  Future<List<XFile>> pickImages() async {
    // image_picker 1.2.2 的多图接口要求 limit 至少为 2。最后一个名额
    // 改用单图接口，后续仍进入同一套预览和裁剪流程。
    if (limit == 1) {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      return pickedFile == null ? const [] : [pickedFile];
    }
    return imagePicker.pickMultiImage(limit: limit);
  }

  final pickedFiles = systemPickerGuard == null
      ? await pickImages()
      : await systemPickerGuard(pickImages);
  if (pickedFiles.isEmpty) return const [];

  validateAttachmentGallerySelectionCount(
    selectedCount: pickedFiles.length,
    limit: limit,
  );
  final selections = await navigator.push<List<AttachmentImageSelection>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AttachmentImageSelectionPreviewPage(
        files: pickedFiles,
        cropPickedImage: cropPickedImage,
      ),
    ),
  );
  return selections ?? const [];
}
