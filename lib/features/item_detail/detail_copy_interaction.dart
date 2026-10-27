import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/repository/models/item_with_fields.dart';
import '../../core/security/sensitive_clipboard_controller.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_icons.dart';
import '../../core/widgets/anch_bottom_sheet.dart';
import '../../core/widgets/anch_centered_notice.dart';

class DetailCopyInteraction {
  DetailCopyInteraction({required this.sensitiveClipboard});

  factory DetailCopyInteraction.system() {
    return DetailCopyInteraction(
      sensitiveClipboard: SensitiveClipboardController(
        clipboard: const SystemSensitiveClipboardPort(),
      ),
    );
  }

  final SensitiveClipboardController sensitiveClipboard;

  void copyValue(BuildContext context, String value) {
    unawaited(_copyValueSafely(context, value));
  }

  Future<void> _copyValueSafely(BuildContext context, String value) async {
    try {
      await sensitiveClipboard.copy(value);
      if (context.mounted) {
        AnchCenteredNotice.showSuccess(context, '复制成功');
      }
    } catch (_) {
      // 允许在无 Clipboard Channel 的测试环境中继续。
    }
  }

  void confirmHeaderCopy(BuildContext context, String value) {
    showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            '确认复制敏感字段？',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.anchColors.textPrimary,
            ),
          ),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.anchColors.surfaceSoft,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: context.anchColors.divider),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: context.anchColors.textSecondary,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '取消',
                style: TextStyle(
                  color: context.anchColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                '确认复制',
                style: TextStyle(
                  color: context.anchColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        copyValue(context, value);
      }
    });
  }

  void _showCopyOptionsBottomSheet(
    BuildContext context,
    List<_DetailCopyMenuOption> options,
  ) {
    showAnchBottomSheet<void>(
      context: context,
      builder: (sheetContext) => AnchBottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnchBottomSheetHeader(title: '复制内容'),
            AnchBottomSheetOptionGroup(
              children: [
                for (final option in options)
                  AnchBottomSheetOption(
                    icon: option.icon,
                    title: option.title,
                    description: option.description,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      option.onTap();
                    },
                  ),
              ],
            ),
            AnchBottomSheetDismissAction(
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void showDebitCardCopyMenu(BuildContext context, ItemWithFields item) {
    String? cardNo;
    String? accountName;
    String? bankName;
    String? branchName;

    for (final field in item.fields) {
      if (field.fieldKey == 'card_number') cardNo = field.valueText;
      if (field.fieldKey == 'account_name') accountName = field.valueText;
      if (field.fieldKey == 'bank_name') bankName = field.valueText;
      if (field.fieldKey == 'branch_name') branchName = field.valueText;
    }

    _showCopyOptionsBottomSheet(context, [
      _DetailCopyMenuOption(
        icon: AnchIcons.copy,
        title: '仅复制卡号',
        description: '只复制卡号字段',
        onTap: () {
          if (cardNo != null && cardNo.isNotEmpty) {
            confirmHeaderCopy(context, cardNo);
          }
        },
      ),
      _DetailCopyMenuOption(
        icon: AnchIcons.document,
        title: '复制完整信息',
        description: '复制已填写的转账信息',
        onTap: () {
          final buffer = StringBuffer();
          if (accountName != null && accountName.trim().isNotEmpty) {
            buffer.writeln('户名：${accountName.trim()}');
          }
          if (cardNo != null && cardNo.trim().isNotEmpty) {
            buffer.writeln('卡号：${cardNo.trim()}');
          }
          if (bankName != null && bankName.trim().isNotEmpty) {
            buffer.writeln('银行：${bankName.trim()}');
          }
          if (branchName != null && branchName.trim().isNotEmpty) {
            buffer.writeln('开户行：${branchName.trim()}');
          }

          final transferInfo = buffer.toString().trim();
          if (transferInfo.isNotEmpty) {
            confirmHeaderCopy(context, transferInfo);
          }
        },
      ),
    ]);
  }

  void showCreditCardCopyMenu(BuildContext context, ItemWithFields item) {
    String? cardNo;
    String? accountName;
    String? bankName;

    for (final field in item.fields) {
      if (field.fieldKey == 'card_number') cardNo = field.valueText;
      if (field.fieldKey == 'account_name') accountName = field.valueText;
      if (field.fieldKey == 'bank_name') bankName = field.valueText;
    }

    _showCopyOptionsBottomSheet(context, [
      _DetailCopyMenuOption(
        icon: AnchIcons.copy,
        title: '仅复制卡号',
        description: '只复制卡号字段',
        onTap: () {
          if (cardNo != null && cardNo.isNotEmpty) {
            confirmHeaderCopy(context, cardNo);
          }
        },
      ),
      _DetailCopyMenuOption(
        icon: AnchIcons.document,
        title: '复制完整信息',
        description: '复制已填写的卡片信息',
        onTap: () {
          final buffer = StringBuffer();
          if (accountName != null && accountName.trim().isNotEmpty) {
            buffer.writeln('户名：${accountName.trim()}');
          }
          if (cardNo != null && cardNo.trim().isNotEmpty) {
            buffer.writeln('卡号：${cardNo.trim()}');
          }
          if (bankName != null && bankName.trim().isNotEmpty) {
            buffer.writeln('银行：${bankName.trim()}');
          }
          final cardInfo = buffer.toString().trim();
          if (cardInfo.isNotEmpty) {
            confirmHeaderCopy(context, cardInfo);
          }
        },
      ),
    ]);
  }

  void dispose() {
    sensitiveClipboard.dispose();
    AnchCenteredNotice.dismiss();
  }
}

class _DetailCopyMenuOption {
  const _DetailCopyMenuOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final AnchIconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
}

class SystemSensitiveClipboardPort implements SensitiveClipboardPort {
  const SystemSensitiveClipboardPort();

  @override
  Future<String?> readText() async {
    return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  }

  @override
  Future<void> writeText(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }
}
