import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../security/app_startup_failure.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_theme.dart';

/// 当启动过程中遇到关键异常时，用以承载整个应用树的顶级 App
class AnchStartupFailureApp extends StatelessWidget {
  final AppStartupException failure;
  final VoidCallback? onRetry;

  const AnchStartupFailureApp({super.key, required this.failure, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '安册',
      debugShowCheckedModeBanner: false,
      theme: AnchTheme.light,
      darkTheme: AnchTheme.dark,
      themeMode: ThemeMode.system,
      home: AnchStartupFailurePage(failure: failure, onRetry: onRetry),
    );
  }
}

/// 具体的启动失败呈现界面
class AnchStartupFailurePage extends StatelessWidget {
  final AppStartupException failure;
  final VoidCallback? onRetry;

  const AnchStartupFailurePage({
    super.key,
    required this.failure,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final failureName = getSanitizedTypeName(failure.type);
    final colors = context.anchColors;
    final screenProtectionUnavailable =
        failure.type == AppStartupFailureType.screenProtectionUnavailable;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部安全校验 Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: colors.warningSoft,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: colors.warning),
                      ),
                      child: Row(
                        children: [
                          AnchIcon(AnchIcons.warning, color: colors.warning),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              screenProtectionUnavailable
                                  ? '屏幕保护暂不可用，已停止显示资料。'
                                  : '安全保护已生效，安册未继续打开本机资料。',
                              style: TextStyle(
                                color: colors.warning,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    // 墨青色标题
                    Text(
                      screenProtectionUnavailable
                          ? '无法启用屏幕保护'
                          : failure.type ==
                                AppStartupFailureType.formalSecurityModeBlocked
                          ? '安全配置异常'
                          : '无法打开本机资料',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      screenProtectionUnavailable
                          ? '为避免内容暴露，资料与操作已暂时隐藏。本机资料未被删除。'
                          : failure.type ==
                                AppStartupFailureType.formalSecurityModeBlocked
                          ? '当前版本的安全配置不完整，安册已停止启动。'
                          : '安册未能安全打开本机加密资料。为避免数据损坏，本次启动已停止。',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 15.0,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Text(
                      '建议措施：',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      failure.type ==
                              AppStartupFailureType.formalSecurityModeBlocked
                          ? '• 请重新安装来源可信的正式版本。\n'
                                '• 不要清除应用数据；如需恢复，请保留已有备份文件。'
                          : '• 请完全退出安册后重新打开。\n'
                                '• 如果问题持续，请勿清除应用数据；保留现有备份文件后再处理。',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14.0,
                        height: 1.6,
                      ),
                    ),
                    const Spacer(flex: 3),
                    if (screenProtectionUnavailable && onRetry != null) ...[
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('重试屏幕保护'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 只读异常类型标签 (脱敏处理，绝不含 key、绝对路径或底层报错堆栈)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '错误类型',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              failureName,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13.0,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
