import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../core/theme/anch_colors.dart';
import '../core/theme/anch_spacing.dart';
import 'card_contract/anch_card_model.dart';
import '../core/service/policy/item_expiry_status_policy.dart';

/// 只消费展示数据的资料行；契约提取器可读取 title 与 description。
class AnchUnifiedDataCard extends StatelessWidget {
  const AnchUnifiedDataCard({
    super.key,
    required this.model,
    required this.onTap,
    this.onLongPress,
    this.titleSpan,
    this.descriptionSpan,
    this.grouped = false,
  });

  final AnchCardModel model;
  final bool grouped;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 可选的高亮富文本（由 AnchSearchHighlighter 产出，仅搜索页使用）
  final InlineSpan? titleSpan;
  final InlineSpan? descriptionSpan;

  // ─── 测试兼容 Getters（供 ContractExtractor 使用）────────────────────────

  String get title => model.title;
  String get description => model.description;

  /// 是否有高亮段落（由 titleSpan / descriptionSpan 非空判断）
  bool get hasHighlight => titleSpan != null || descriptionSpan != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final tag = grouped && model.tag == '置顶' ? null : model.tag;

    return Material(
      color: colors.surface,
      elevation: 0,
      shape: grouped
          ? Border(bottom: BorderSide(color: colors.divider))
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 左侧图标
                SizedBox(
                  key: const Key('anch_record_leading_icon_slot'),
                  width: 28,
                  height: 40,
                  child: AnchIcon(
                    model.icon,
                    size: 24,
                    color: colors.documentIcon,
                  ),
                ),
                const SizedBox(width: AnchSpacing.md),
                // 标题 + 描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          titleSpan != null
                              ? Text.rich(
                                  titleSpan!,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                )
                              : Text(
                                  model.title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                          if (tag != null)
                            Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      if (model.statusLabel != null ||
                          model.expiryBadgeText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (model.statusLabel != null)
                                Text(
                                  model.statusLabel!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textMuted,
                                  ),
                                ),
                              if (model.expiryBadgeText != null)
                                Builder(
                                  builder: (context) {
                                    final urgent =
                                        model.expiryStatus ==
                                            ItemExpiryStatus.expired ||
                                        model.expiryStatus ==
                                            ItemExpiryStatus.today ||
                                        (model.daysUntilExpiry != null &&
                                            model.daysUntilExpiry! <= 7);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: urgent
                                            ? colors.dangerSoft
                                            : colors.warningSoft,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        model.expiryBadgeText!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: urgent
                                              ? colors.danger
                                              : colors.warning,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      if (model.billDayBadge != null ||
                          model.repaymentDayBadge != null) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          key: const Key('bank_card_day_badges'),
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (model.billDayBadge != null)
                              Text(
                                model.billDayBadge!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.accentDeep,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (model.repaymentDayBadge != null)
                              Text(
                                model.repaymentDayBadge!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.danger,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      // 描述行
                      descriptionSpan != null
                          ? Text.rich(
                              descriptionSpan!,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            )
                          : Text(
                              model.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                    ],
                  ),
                ),
                // 右侧箭头
                if (model.showArrow) ...[
                  const SizedBox(width: AnchSpacing.sm),
                  AnchIcon(
                    AnchIcons.chevronRight,
                    size: 20,
                    color: colors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 石墨资料册中的平面资料行名称；保留旧组件名以兼容现有页面与测试契约。
typedef AnchRecordRow = AnchUnifiedDataCard;
