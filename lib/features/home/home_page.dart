import '../item_entry/item_entry_flow_page.dart';
import '../../widgets/item_summary_card.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_model.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_motion.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_bottom_sheet.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_page_header.dart';
import '../../core/widgets/anch_header_action.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/widgets/anch_centered_notice.dart';
import '../../core/widgets/anch_section_header.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import '../item_detail/item_detail_page.dart';
import '../all_items/all_items_page.dart';
import '../search/search_page.dart';
import '../../core/service/item_expiry_overview_service.dart';
import '../expiry/expiry_items_page.dart';
import '../../core/service/policy/item_expiry_status_policy.dart';

/// 安册首页：紧凑标题、搜索、置顶与最近资料，摘要仅展示低敏信息。
class HomePage extends StatefulWidget {
  final bool isActive;
  const HomePage({super.key, this.isActive = true});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ItemModel> _items = const [];
  int _activeItemCount = 0;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _hasLoadedData = false;
  int _loadRequest = 0;

  ItemExpiryOverviewResult? _overviewResult;
  Map<String, String> _memberMap = const {};
  Map<String, ItemModel> _itemById = const {};
  ItemGlobalRegistry? _registry;
  bool _hasLoaded = false;

  @override
  void dispose() {
    _registry?.removeListener(_handleRegistryChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) reloadItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = DependencyProvider.of(context).itemUseCaseService.registry;
    if (_registry != registry) {
      _registry?.removeListener(_handleRegistryChanged);
      _registry = registry;
      _registry?.addListener(_handleRegistryChanged);
    }
    if (widget.isActive && !_hasLoaded) reloadItems();
  }

  void _handleRegistryChanged() {
    if (widget.isActive) reloadItems();
  }

  Future<void> reloadItems() async {
    final request = ++_loadRequest;
    setState(() {
      _loadFailed = false;
      if (!_hasLoadedData) _isLoading = true;
    });
    _hasLoaded = true;
    final itemRepo = DependencyProvider.of(context).itemRepo;
    final memberRepo = DependencyProvider.of(context).memberRepo;
    final timeDomainSource = DependencyProvider.of(context).timeDomainSource;

    try {
      final results = await Future.wait([
        memberRepo.getActiveMembers(),
        itemRepo.getActiveItems(),
      ]);
      final members = results[0] as List;
      final activeItems = results[1] as List<ItemModel>;
      final memberMap = <String, String>{for (final m in members) m.id: m.name};

      // 首页预览与到期概览共用同一批活跃资料，避免重复读取数据库。
      final previewItems = activeItems.take(20).toList();

      final summaries = previewItems
          .map((item) => item.toListSummary())
          .toList(growable: false);

      final now = timeDomainSource.now();
      final overview = ItemExpiryOverviewService.calculate(activeItems, now);

      if (mounted && request == _loadRequest) {
        setState(() {
          _hasLoadedData = true;
          _items = summaries;
          _activeItemCount = activeItems.length;
          _overviewResult = overview;
          _memberMap = memberMap;
          _itemById = {
            for (final item in activeItems) item.id: item.toListSummary(),
          };
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _goToEntry() async {
    final result = await ItemEntryFlowPage.open(context);
    if (!mounted) return;
    if (result != null && result is String) {
      await ItemSummaryCard.openDetail(context, result);
    }
  }

  Future<void> _goToDetail(String itemId) async {
    final di = DependencyProvider.of(context);
    final prefetchedItem = di.itemRepo.getItemWithFields(itemId);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailPage(
          itemId: itemId,
          prefetchedItem: prefetchedItem,
          privacyShieldCoordinator: DependencyProvider.maybeOf(
            context,
          )?.privacyShieldBundle?.coordinator,
        ),
      ),
    );
  }

  Future<void> _goToAllItems() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllItemsPage()),
    );
  }

  Future<void> _showItemQuickActions(String itemId) async {
    final item = _itemById[itemId];
    if (item == null) return;

    await showAnchBottomSheet<void>(
      context: context,
      builder: (sheetContext) => AnchBottomSheetFrame(
        key: Key('home_item_actions_$itemId'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnchBottomSheetHeader(title: '资料操作'),
            AnchBottomSheetOptionGroup(
              children: [
                AnchBottomSheetOption(
                  icon: AnchIcons.success,
                  title: item.isPinned ? '取消置顶' : '设为置顶',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _updateItemPinned(item);
                  },
                ),
                AnchBottomSheetOption(
                  icon: AnchIcons.edit,
                  title: '编辑',
                  onTap: () => _dismissSheetThenEdit(sheetContext, itemId),
                ),
              ],
            ),
            AnchBottomSheetOptionGroup(
              children: [
                AnchBottomSheetOption(
                  icon: AnchIcons.delete,
                  title: '删除',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmDeleteItem(itemId);
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

  Future<void> _dismissSheetThenEdit(
    BuildContext sheetContext,
    String itemId,
  ) async {
    final sheetRoute = ModalRoute.of(sheetContext);
    Navigator.of(sheetContext).pop();
    await sheetRoute?.completed;
    if (mounted) await _editItem(itemId);
  }

  Future<void> _updateItemPinned(ItemModel item) async {
    final result = await DependencyProvider.of(
      context,
    ).itemUseCaseService.updateItemPinned(item.id, isPinned: !item.isPinned);
    if (!mounted) return;
    if (result.success) {
      AnchCenteredNotice.showSuccess(
        context,
        item.isPinned ? '已取消置顶' : '已设为置顶',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('操作未完成'),
        content: const Text('当前无法更新资料状态，请返回后重试。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _editItem(String itemId) async {
    await ItemEntryFlowPage.open(context, existingItemId: itemId);
  }

  void _confirmDeleteItem(String itemId) {
    final service = DependencyProvider.of(context).itemUseCaseService;
    showModalBottomSheet<OperationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.anchColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AnchRadius.lg),
        ),
      ),
      sheetAnimationStyle: AnchMotion.bottomSheetAnimationStyle(context),
      builder: (_) => DeleteRecordSheet(itemId: itemId, service: service),
    ).then((result) {
      if (!mounted || result?.success != true) return;
      AnchCenteredNotice.showSuccess(context, '已移入最近删除');
    });
  }

  Widget _buildHeader() => AnchPageHeader(
    title: '安册',
    titleTrailingText: '$_activeItemCount 份资料',
    trailing: AnchHeaderAction(
      key: const Key('home_add_item'),
      icon: AnchIcons.add,
      label: '新增',
      semanticLabel: '新增资料',
      onTap: _goToEntry,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    if (_loadFailed && !_hasLoadedData) {
      return AnchAppScaffold(
        body: Column(
          children: [
            _buildHeader(),
            if (RuntimeScope.of(context).isDevMode)
              const AnchSecurityBanner(
                message: AnchSecurityBanner.devModeMessage,
                type: AnchBannerType.warning,
              ),
            Expanded(child: AnchEmptyState.loadError(onRetry: reloadItems)),
          ],
        ),
      );
    }
    final hasExpiry =
        _overviewResult != null &&
        _overviewResult!.actionableEntries.isNotEmpty;

    return AnchAppScaffold(
      body: RefreshIndicator(
        color: colors.accent,
        backgroundColor: colors.surface,
        onRefresh: () async => reloadItems(),
        child: ListView(
          children: [
            // 1. 顶部标题
            _buildHeader(),
            if (_loadFailed && _hasLoadedData)
              AnchEmptyState.loadError(onRetry: reloadItems, hasContent: true),

            // 2. 开发验证模式提示（不删除）
            if (RuntimeScope.of(context).isDevMode)
              const AnchSecurityBanner(
                message: AnchSecurityBanner.devModeMessage,
                type: AnchBannerType.warning,
              ),

            const SizedBox(height: AnchSpacing.sm),

            // 3. 搜索入口（静态样式）
            _SearchEntry(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchPage()),
                );
              },
            ),

            const SizedBox(height: AnchSpacing.sm),

            // 5. 本次运行已保存资料
            _RecentSection(
              expiryAction: hasExpiry
                  ? Builder(
                      builder: (context) {
                        final hasError =
                            _overviewResult!.expiredCount > 0 ||
                            _overviewResult!.todayCount > 0 ||
                            _overviewResult!.actionableEntries.any(
                              (e) =>
                                  e.statusResult.status ==
                                      ItemExpiryStatus.upcoming &&
                                  e.statusResult.daysUntilExpiry != null &&
                                  e.statusResult.daysUntilExpiry! <= 7,
                            );

                        return _ExpiryOverviewCard(
                          key: const Key('expiry_overview_card'),
                          totalCount: _overviewResult!.actionableEntries.length,
                          expiredCount: _overviewResult!.expiredCount,
                          todayCount: _overviewResult!.todayCount,
                          upcomingCount: _overviewResult!.upcomingCount,
                          hasError: hasError,
                          onTap: () async {
                            final di = DependencyProvider.of(context);
                            final now = di.timeDomainSource.now();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExpiryItemsPage(
                                  items: _overviewResult!.actionableEntries
                                      .map((e) => e.item)
                                      .toList(),
                                  memberNameById: _memberMap,
                                  now: now,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : null,
              items: _items,
              memberNames: _memberMap,
              totalCount: _activeItemCount,
              isLoading: _isLoading && widget.isActive,
              onTapItem: _goToDetail,
              onLongPressItem: _showItemQuickActions,
              onAddFirst: _goToEntry,
              onViewAll: _goToAllItems,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── 搜索入口 ────────────────────────────────────────────────────────────────

/// 首页搜索入口，点击进入完整搜索页
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
      child: GestureDetector(
        key: const Key('home_search_entry'),
        onTap: onTap,
        child: Container(
          key: const Key('home_search_surface'),
          height: 52,
          decoration: BoxDecoration(
            color: context.anchColors.surface,
            borderRadius: BorderRadius.circular(AnchRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.lg),
          child: Row(
            children: [
              AnchIcon(
                AnchIcons.search,
                size: 20,
                color: context.anchColors.textMuted,
              ),
              const SizedBox(width: AnchSpacing.sm),
              Expanded(
                child: Text(
                  '搜索资料、成员或备注',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.anchColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 本次运行已保存区块 ──────────────────────────────────────────────────────

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.items,
    required this.memberNames,
    required this.totalCount,
    required this.isLoading,
    required this.onTapItem,
    required this.onLongPressItem,
    required this.onAddFirst,
    required this.onViewAll,
    this.expiryAction,
  });

  final List<ItemModel> items;
  final Map<String, String> memberNames;
  final int totalCount;
  final bool isLoading;
  final ValueChanged<String> onTapItem;
  final ValueChanged<String> onLongPressItem;
  final VoidCallback onAddFirst;
  final VoidCallback onViewAll;
  final Widget? expiryAction;

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xl),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.anchColors.accent,
          ),
        ),
      );
    }

    final list = items;
    if (list.isEmpty) {
      return AnchEmptyState(
        title: '暂无资料',
        description: '通过搜索或添加资料开始使用',
        actionLabel: '去添加资料',
        onAction: onAddFirst,
      );
    }

    final preview = list.take(5).toList();
    final pinned = preview.where((item) => item.isPinned).toList();
    final others = preview.where((item) => !item.isPinned).toList();
    Widget group(List<ItemModel> entries) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AnchRadius.lg),
        child: Column(
          children: [
            for (final item in entries)
              ItemSummaryCard(
                item: item,
                grouped: true,
                memberName: memberNames[item.memberId] ?? '家庭',
                onTap: () => onTapItem(item.id),
                onLongPress: () => onLongPressItem(item.id),
              ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnchSectionHeader(
          title: pinned.isEmpty ? '全部资料' : '置顶 · ${pinned.length}',
          trailing: expiryAction,
        ),
        if (pinned.isNotEmpty) group(pinned),
        if (pinned.isNotEmpty && others.isNotEmpty)
          AnchSectionHeader(title: '其他资料'),
        if (others.isNotEmpty) group(others),

        // 超过 5 条时显示"查看更多"
        if (list.length > 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AnchSpacing.page,
              0,
              AnchSpacing.page,
              AnchSpacing.sm,
            ),
            child: TextButton(
              key: const Key('all_saved_items_entry'),
              onPressed: onViewAll,
              child: const Text('查看全部已保存资料'),
            ),
          ),
      ],
    );
  }
}

// ─── 到期概览卡片 ─────────────────────────────────────────────────────────────

class _ExpiryOverviewCard extends StatelessWidget {
  final int totalCount;
  final int expiredCount;
  final int todayCount;
  final int upcomingCount;
  final bool hasError;
  final VoidCallback onTap;

  const _ExpiryOverviewCard({
    super.key,
    required this.totalCount,
    required this.expiredCount,
    required this.todayCount,
    required this.upcomingCount,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return TextButton.icon(
      onPressed: onTap,
      icon: AnchIcon(AnchIcons.time, size: 16),
      style: TextButton.styleFrom(
        foregroundColor: hasError ? colors.danger : colors.textSecondary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: const TextStyle(fontSize: 13),
      ),
      label: Text(
        hasError
            ? _buildExpiryDescription(expiredCount, todayCount, upcomingCount)
            : '$totalCount 份将到期',
      ),
    );
  }

  static String _buildExpiryDescription(
    int expiredCount,
    int todayCount,
    int upcomingCount,
  ) {
    final parts = <String>[];
    if (expiredCount > 0) parts.add('已过期 $expiredCount 条');
    if (todayCount > 0) parts.add('今日到期 $todayCount 条');
    if (upcomingCount > 0) parts.add('30 天内到期 $upcomingCount 条');
    return parts.join('，');
  }
}
