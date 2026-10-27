import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';

class AppLockSetupPlaceholderPage extends StatelessWidget {
  final AppLockController controller;
  final VoidCallback? onOpenPinSetup;

  const AppLockSetupPlaceholderPage({
    super.key,
    required this.controller,
    this.onOpenPinSetup,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '设置应用锁',
        backgroundColor: Colors.transparent,
        onBack: () => Navigator.pop(context),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnchIcon(AnchIcons.lockOpen, size: 64, color: colors.warning),
              const SizedBox(height: 24),
              Text(
                '应用锁尚未配置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                onOpenPinSetup != null
                    ? '请先设置应用锁 PIN，再继续使用安册。'
                    : '当前无法打开应用锁设置，请重新打开安册后再试。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(height: 32),
              if (onOpenPinSetup != null)
                ElevatedButton(
                  onPressed: onOpenPinSetup,
                  child: const Text('设置应用锁 PIN'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
