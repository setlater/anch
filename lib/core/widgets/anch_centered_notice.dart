import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';

/// 安册统一的居中短通知，用于非阻断的成功和失败反馈。
abstract final class AnchCenteredNotice {
  AnchCenteredNotice._();

  static const _maxWidth = 360.0;
  static const noticeKey = ValueKey('anch-centered-notice');

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message: message,
      icon: AnchIcons.check,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: AnchIcons.info,
      duration: const Duration(seconds: 2),
    );
  }

  static void dismiss() {
    _removeCurrent();
  }

  static void _show(
    BuildContext context, {
    required String message,
    required AnchIconData icon,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    assert((actionLabel == null) == (onAction == null));
    _removeCurrent();
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final notice = SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Material(
                  key: noticeKey,
                  color: scheme.inverseSurface,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(AnchRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AnchSpacing.md,
                      vertical: AnchSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnchIcon(
                          icon,
                          color: scheme.onInverseSurface,
                          size: 18,
                        ),
                        const SizedBox(width: AnchSpacing.sm),
                        Flexible(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: scheme.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (actionLabel != null) ...[
                          const SizedBox(width: AnchSpacing.xs),
                          TextButton(
                            onPressed: () {
                              _removeCurrent();
                              onAction!();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.onInverseSurface,
                              minimumSize: const Size(48, 48),
                            ),
                            child: Text(actionLabel),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return actionLabel == null ? IgnorePointer(child: notice) : notice;
      },
    );
    _currentEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, () {
      if (identical(_currentEntry, entry)) _removeCurrent();
    });
  }

  static void _removeCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}
