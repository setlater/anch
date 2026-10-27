import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/attachment/attachment_model.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_bottom_action_bar.dart';
import '../../core/widgets/encrypted_attachment_thumbnail.dart';

class ItemEntrySupplementSection extends StatelessWidget {
  const ItemEntrySupplementSection({
    super.key,
    required this.attachments,
    this.showAddAttachment = true,
    required this.onAddAttachment,
    required this.onDeleteAttachment,
    required this.noteInput,
    required this.householdMemberSection,
    required this.expiryPreview,
    required this.isKeyboardVisible,
    required this.existingItemId,
    required this.isSaving,
    required this.onSave,
  });

  final List<AttachmentModel> attachments;
  final bool showAddAttachment;
  final VoidCallback onAddAttachment;
  final ValueChanged<AttachmentModel> onDeleteAttachment;
  final Widget noteInput;
  final Widget? householdMemberSection;
  final Widget? expiryPreview;
  final bool isKeyboardVisible;
  final String? existingItemId;
  final bool isSaving;
  final VoidCallback onSave;

  @visibleForTesting
  static double attachmentSlotWidthFor(double availableWidth) {
    return math.max(0, (availableWidth - AnchSpacing.md) / 2);
  }

  Widget _buildFilledSlot(
    BuildContext context,
    AttachmentModel attachment, {
    required double width,
  }) {
    final isImage = attachment.mimeType.startsWith('image/');
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 155 / 110,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                color: context.anchColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AnchRadius.md),
                border: Border.all(color: context.anchColors.divider, width: 1),
              ),
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AnchRadius.md - 1),
                      child: EncryptedAttachmentThumbnail(
                        fileName: attachment.fileName,
                        showProgressIndicator: true,
                      ),
                    )
                  : _FileAttachmentDraftTile(mimeType: attachment.mimeType),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onDeleteAttachment(attachment),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: AnchIcon(
                    AnchIcons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emptySlot = GestureDetector(
      onTap: onAddAttachment,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: context.anchColors.divider,
          borderRadius: AnchRadius.md,
          dashLength: 5,
          gap: 4,
          strokeWidth: 1.2,
        ),
        child: Container(
          width: double.infinity,
          height: 80,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnchIcon(
                AnchIcons.image,
                size: 20,
                color: context.anchColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                '添加附件或照片',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.anchColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final attachmentSection = Column(
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
        if (attachments.isNotEmpty) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth =
                  ItemEntrySupplementSection.attachmentSlotWidthFor(
                    constraints.maxWidth,
                  );
              return Wrap(
                spacing: AnchSpacing.md,
                runSpacing: AnchSpacing.md,
                children: [
                  for (final attachment in attachments)
                    _buildFilledSlot(context, attachment, width: slotWidth),
                ],
              );
            },
          ),
          if (showAddAttachment) const SizedBox(height: AnchSpacing.md),
        ],
        if (showAddAttachment) emptySlot,
      ],
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AnchSpacing.page,
              AnchSpacing.md,
              AnchSpacing.page,
              AnchSpacing.xxl,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AnchSpacing.md,
                  top: AnchSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '补充附件与备注',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.anchColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AnchSpacing.xs),
                    Text(
                      '附件保存在应用内部，不进入系统相册',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.anchColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (householdMemberSection != null) ...[
                householdMemberSection!,
                const SizedBox(height: AnchSpacing.lg),
              ],
              _SupplementGroupCard(
                key: const Key('supplement_group_card'),
                children: [
                  attachmentSection,
                  const SizedBox(height: AnchSpacing.lg),
                  noteInput,
                ],
              ),
              if (expiryPreview != null) ...[
                const SizedBox(height: AnchSpacing.lg),
                expiryPreview!,
              ],
              const SizedBox(height: AnchSpacing.lg),
            ],
          ),
        ),
        AnchBottomActionBar(
          key: const Key('flow_button_save'),
          primaryLabel: existingItemId != null ? '保存修改' : '保存资料',
          compactWhenKeyboardVisible: true,
          compactPrimaryLabel: existingItemId != null ? '保存' : '保存资料',
          isKeyboardVisible: isKeyboardVisible,
          flat: true,
          onPrimary: isSaving ? null : onSave,
          isLoading: isSaving,
        ),
      ],
    );
  }
}

class _FileAttachmentDraftTile extends StatelessWidget {
  const _FileAttachmentDraftTile({required this.mimeType});

  final String mimeType;

  @override
  Widget build(BuildContext context) {
    final isPdf = mimeType == 'application/pdf';
    final isText = mimeType == 'text/plain';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnchIcon(
          isPdf
              ? AnchIcons.pdf
              : isText
              ? AnchIcons.document
              : AnchIcons.file,
          size: 30,
          color: context.anchColors.textMuted,
        ),
        const SizedBox(height: 6),
        Text(
          isPdf
              ? 'PDF'
              : isText
              ? 'TXT'
              : '文件',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.anchColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SupplementGroupCard extends StatelessWidget {
  const _SupplementGroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AnchSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.anchColors.divider),
            bottom: BorderSide(color: context.anchColors.divider),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AnchSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
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
          Offset.zero & size,
          Radius.circular(borderRadius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
