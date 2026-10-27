import 'attachment_model.dart';

/// 附件在应用内预览与交给其他应用打开的统一边界。
abstract final class AttachmentPreviewPolicy {
  static const int maxInlineTextPreviewBytes = 512 * 1024;
  static const int largeExternalOpenWarningBytes = 10 * 1024 * 1024;

  static bool canPreviewTextInApp(AttachmentModel attachment) =>
      attachment.mimeType == 'text/plain' &&
      attachment.plainSize <= maxInlineTextPreviewBytes;

  static bool needsLargeExternalOpenWarning(AttachmentModel attachment) =>
      attachment.plainSize >= largeExternalOpenWarningBytes;
}
