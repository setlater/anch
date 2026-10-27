import 'package:image_picker/image_picker.dart';

/// 用户在多选图片预览中确认的一张图片。
class AttachmentImageSelection {
  const AttachmentImageSelection({
    required this.file,
    required this.wasCropped,
  });

  final XFile file;
  final bool wasCropped;
}
