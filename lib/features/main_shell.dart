import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../core/theme/anch_colors.dart';
import '../core/app_guidance_manager.dart';
import '../core/security/app_lock_controller.dart';
import 'home/home_page.dart';
import 'member/member_page.dart';
import 'type/type_page.dart';
import 'mine/mine_page.dart';
import '../app/dependency_provider.dart';
import '../app/main_shell_controller.dart';
import '../core/widgets/anch_adaptive_layout.dart';
import 'privacy/screen_protection_scope.dart';
import 'mine/data_management_page.dart';

/// 安册主壳层：底部导航 + 四个主入口页面。
///
/// 底部导航项：首页 / 成员 / 类型 / 设置
/// 新增资料不作为底部 Tab，而作为首页主操作。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  MainShellController? _tabController;
  AppLockController? _appLockController;
  bool _guidanceScheduled = false;
  bool _guidanceRunning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DependencyProvider.of(context).mainShellController;
    if (_tabController == controller) return;
    _tabController?.removeListener(_handleTabControllerChanged);
    _tabController = controller;
    _currentIndex = controller.value;
    controller.addListener(_handleTabControllerChanged);

    final appLockController = DependencyProvider.of(
      context,
    ).appLockBundle?.appLockController;
    if (_appLockController != appLockController) {
      _appLockController?.removeListener(_handleAppLockChanged);
      _appLockController = appLockController;
      _appLockController?.addListener(_handleAppLockChanged);
    }
    _scheduleGuidanceIfReady();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabControllerChanged);
    _appLockController?.removeListener(_handleAppLockChanged);
    super.dispose();
  }

  void _handleAppLockChanged() {
    _scheduleGuidanceIfReady();
  }

  void _scheduleGuidanceIfReady() {
    if (_guidanceScheduled || _guidanceRunning) return;
    if (_appLockController != null &&
        !_appLockController!.value.canShowProtectedContent) {
      return;
    }
    _guidanceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guidanceScheduled = false;
      if (mounted) _runGuidance();
    });
  }

  Future<void> _runGuidance() async {
    if (_guidanceRunning) return;
    _guidanceRunning = true;
    try {
      final provider = DependencyProvider.of(context);
      final guidance = await provider.appGuidanceManager.load();
      if (!mounted) return;
      if (!guidance.firstUseAcknowledged) {
        await _showFirstUseNotice();
        await provider.appGuidanceManager.acknowledgeFirstUse();
        return;
      }

      final activeItemCount = await provider.itemRepo.getActiveItemCount();
      final history = await provider.backupHistoryManager.load();
      if (!mounted) return;
      final kind = const BackupReminderPolicy().evaluate(
        now: provider.timeDomainSource.now(),
        hasSavedItems: activeItemCount > 0,
        guidance: guidance,
        lastBackupAt: history?.savedAt,
      );
      if (kind == BackupReminderKind.none) return;

      final now = provider.timeDomainSource.now().millisecondsSinceEpoch;
      await provider.appGuidanceManager.recordBackupReminderShown(now);
      if (!mounted) return;
      final message = kind == BackupReminderKind.neverBackedUp
          ? '当前资料还没有可用备份，建议导出一份。'
          : '上次备份已超过 30 天，建议更新备份。';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 8),
            persist: false,
            action: SnackBarAction(
              label: '去备份',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const DataManagementPage()),
              ),
            ),
          ),
        );
    } finally {
      _guidanceRunning = false;
    }
  }

  Future<void> _showFirstUseNotice() {
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          scrollable: true,
          title: const Text('使用安册前请确认'),
          content: const Text(
            '• 资料只保存在本机，不会自动云同步。\n'
            '• 卸载安册或清除应用数据会删除本机资料。\n'
            '• 备份密码不会被保存，忘记后无法找回。\n'
            '• 不要保存支付密码、登录密码、验证码、CVV、私钥或助记词。',
            style: TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('我已了解'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTabControllerChanged() {
    if (!mounted || _tabController == null) return;
    setState(() {
      _currentIndex = _tabController!.value;
    });
  }

  void _selectTab(int index) {
    _tabController?.selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;

    return ScreenProtectionScope(
      sensitive: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expanded =
              AnchLayoutBreakpoints.forWindowWidth(constraints.maxWidth) ==
              AnchWindowWidthClass.expanded;
          const icons = [
            AnchIcons.homeNavigation,
            AnchIcons.memberNavigation,
            AnchIcons.documentNavigation,
            AnchIcons.settingsNavigation,
          ];
          const labels = ['首页', '成员', '分类', '设置'];
          return Scaffold(
            backgroundColor: colors.background,
            body: Row(
              children: [
                SizedBox(
                  width: expanded ? 96 : 0,
                  child: expanded
                      ? SafeArea(
                          child: NavigationRail(
                            scrollable: true,
                            selectedIndex: _currentIndex,
                            onDestinationSelected: _selectTab,
                            backgroundColor: colors.surface,
                            indicatorColor: colors.accentSoft,
                            labelType: NavigationRailLabelType.all,
                            destinations: [
                              for (var i = 0; i < labels.length; i++)
                                NavigationRailDestination(
                                  icon: AnchIcon(
                                    icons[i].normal,
                                    size: 24,
                                    color: colors.textSecondary,
                                  ),
                                  selectedIcon: AnchIcon(
                                    icons[i].selected,
                                    size: 24,
                                    color: colors.accent,
                                  ),
                                  label: Text(labels[i]),
                                ),
                            ],
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      HomePage(isActive: _currentIndex == 0),
                      MemberPage(isActive: _currentIndex == 1),
                      TypePage(isActive: _currentIndex == 2),
                      const MinePage(),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: expanded
                ? null
                : _AnchBottomNav(
                    currentIndex: _currentIndex,
                    onTap: _selectTab,
                  ),
          );
        },
      ),
    );
  }
}

/// 安册底部导航栏
class _AnchBottomNav extends StatelessWidget {
  const _AnchBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final navBackground = colors.surface;

    return Container(
      decoration: BoxDecoration(
        color: navBackground,
        border: Border(top: BorderSide(color: colors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _NavItem(
                navigationIcon: AnchIcons.homeNavigation,
                label: '首页',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                navigationIcon: AnchIcons.memberNavigation,
                label: '成员',
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                navigationIcon: AnchIcons.documentNavigation,
                label: '分类',
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                navigationIcon: AnchIcons.settingsNavigation,
                label: '设置',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.navigationIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final AnchNavigationIconData navigationIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final colors = context.anchColors;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: GestureDetector(
          onTap: () => onTap(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28,
                  child: Center(
                    child: AnchIcon(
                      isSelected
                          ? navigationIcon.selected
                          : navigationIcon.normal,
                      size: 22,
                      color: isSelected ? colors.accent : colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? colors.accent : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
