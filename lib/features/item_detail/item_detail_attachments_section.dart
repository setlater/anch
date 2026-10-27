import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../../core/attachment/attachment_model.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/encrypted_attachment_thumbnail.dart';

class ItemDetailAttachmentsSection extends StatelessWidget {
  const ItemDetailAttachmentsSection({
    super.key,
    required this.attachments,
    this.showAddAttachment = true,
    required this.onAddAttachment,
    required this.onPreviewImages,
    required this.onOpenFileAttachment,
  });

  final List<AttachmentModel> attachments;
  final bool showAddAttachment;
  final VoidCallback onAddAttachment;
  final void Function(List<AttachmentModel> attachments, int initialIndex)
  onPreviewImages;
  final ValueChanged<AttachmentModel> onOpenFileAttachment;

  bool _isImageAttachment(AttachmentModel attachment) {
    return attachment.mimeType.startsWith('image/');
  }

  @override
  Widget build(BuildContext context) {
    final addButton = GestureDetector(
      key: const Key('add_attachment_button'),
      onTap: onAddAttachment,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: context.anchColors.divider,
          borderRadius: 10,
          dashLength: 4,
          gap: 3,
          strokeWidth: 1.2,
        ),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: AnchIcon(
            AnchIcons.add,
            size: 22,
            color: context.anchColors.textMuted,
          ),
        ),
      ),
    );

    if (attachments.isEmpty) {
      return Container(
        key: const Key('attachments_card'),
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: AnchSpacing.sectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '附件',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.anchColors.textSecondary,
              ),
            ),
            const SizedBox(height: AnchSpacing.sm),
            Row(
              children: [
                addButton,
                const SizedBox(width: AnchSpacing.sm),
                Expanded(
                  child: Text(
                    '添加照片、PDF 或文件',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.anchColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final imageAttachments = attachments
        .where(_isImageAttachment)
        .toList(growable: false);
    final thumbs = <Widget>[];
    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      final isImage = _isImageAttachment(attachment);
      thumbs.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            key: Key('attachment_item_$index'),
            onTap: isImage
                ? () => onPreviewImages(
                    imageAttachments,
                    imageAttachments.indexOf(attachment),
                  )
                : () => onOpenFileAttachment(attachment),
            child: Container(
              key: Key('attachment_tile_$index'),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.anchColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.anchColors.divider, width: 1),
              ),
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: EncryptedAttachmentThumbnail(
                        fileName: attachment.fileName,
                      ),
                    )
                  : _FileAttachmentTile(mimeType: attachment.mimeType),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('attachments_card'),
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: AnchSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${imageAttachments.length == attachments.length ? '附件照片' : '附件'} · ${attachments.length}${imageAttachments.length == attachments.length ? '张' : ' 个'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.anchColors.textSecondary,
                ),
              ),
              if (imageAttachments.isNotEmpty)
                GestureDetector(
                  onTap: () => onPreviewImages(imageAttachments, 0),
                  child: Text(
                    '查看图片',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.anchColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AnchSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [...thumbs, if (showAddAttachment) addButton]),
          ),
        ],
      ),
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({required this.mimeType});

  final String mimeType;

  @override
  Widget build(BuildContext context) {
    final isPdf = mimeType == 'application/pdf';
    return Semantics(
      label: isPdf ? 'PDF 附件' : '文件附件',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnchIcon(
            isPdf ? AnchIcons.pdf : AnchIcons.file,
            color: context.anchColors.textMuted,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            isPdf ? 'PDF' : '文件',
            style: TextStyle(
              color: context.anchColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashLength,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double dashLength;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(
            distance,
            end > metric.length ? metric.length : end,
          ),
          paint,
        );
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
