import '../../widgets/item_summary_card.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_model.dart';
import '../../core/runtime/runtime_scope.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../../core/widgets/anch_security_banner.dart';
import 'archived_items_page.dart';

/// 已保存的全部活跃资料列表，仅展示卡片允许的低敏摘要。
class AllItemsPage extends StatefulWidget {
  const AllItemsPage({super.key});

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> {
  List<ItemModel> _items = const [];
  Map<String, String> _memberNames = const {};
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _hasLoadedData = false;
  int _loadRequest = 0;

  int _archivedCount = 0;
  ItemGlobalRegistry? _registry;
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = DependencyProvider.of(context).itemUseCaseService.registry;
    if (_registry != registry) {
      _registry?.removeListener(_handleRegistryChanged);
      _registry = registry;
      _registry?.addListener(_handleRegistryChanged);
    }
    if (!_hasLoaded) reloadItems();
  }

  @override
  void dispose() {
    _registry?.removeListener(_handleRegistryChanged);
    super.dispose();
  }

  void _handleRegistryChanged() => reloadItems();

  Future<void> reloadItems() async {
    final request = ++_loadRequest;
    setState(() {
      _loadFailed = false;
      if (!_hasLoadedData) _isLoading = true;
    });
    _hasLoaded = true;
    final di = DependencyProvider.of(context);
    try {
      final results = await Future.wait([
        di.memberRepo.getActiveMembers(),
        di.itemRepo.getActiveItems(),
        di.itemRepo.getArchivedItemCount(),
      ]);
      final members = results[0] as List;
      final items = results[1] as List<ItemModel>;
      final archivedCount = results[2] as int;
      final memberMap = <String, String>{
        for (final member in members) member.id: member.name,
      };
      final summaries = items
          .map((item) => item.toListSummary())
          .toList(growable: false);

      if (mounted && request == _loadRequest) {
        setState(() {
          _hasLoadedData = true;
          _items = summaries;
          _memberNames = memberMap;
          _isLoading = false;
          _archivedCount = archivedCount;
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

  @override
  Widget build(BuildContext context) {
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '全部资料',
        onBack: () => Navigator.pop(context),
        actions: [
          if (_hasLoadedData)
            Padding(
              padding: const EdgeInsets.only(right: AnchSpacing.page),
              child: Center(
                child: Text(
                  '${_items.length} 条',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.anchColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (RuntimeScope.of(context).isDevMode)
            const AnchSecurityBanner(
              message: AnchSecurityBanner.devModeMessage,
              type: AnchBannerType.warning,
            ),
          const SizedBox(height: AnchSpacing.sm),
          if (_loadFailed && _hasLoadedData)
            AnchEmptyState.loadError(onRetry: reloadItems, hasContent: true),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loadFailed && !_hasLoadedData) {
      return AnchEmptyState.loadError(onRetry: reloadItems);
    }

    if (_isLoading && _items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: context.anchColors.accentDeep,
          strokeWidth: 2,
        ),
      );
    }

    final prefix = <Widget>[
      if (_archivedCount > 0)
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
          ),
          leading: const AnchIcon(AnchIcons.archive),
          title: const Text('已归档资料'),
          trailing: Text('$_archivedCount 条'),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const ArchivedItemsPage()),
          ),
        ),
      if (_items.isEmpty)
        const AnchEmptyState(title: '暂无当前资料', description: '通过搜索或添加资料开始使用'),
    ];
    return RefreshIndicator(
      color: context.anchColors.accent,
      backgroundColor: context.anchColors.surface,
      onRefresh: () async => reloadItems(),
      child: ListView.builder(
        itemCount: prefix.length + _items.length + 1,
        itemBuilder: (context, index) {
          if (index < prefix.length) return prefix[index];
          final itemIndex = index - prefix.length;
          if (itemIndex < _items.length) {
            return _buildItemCard(_items[itemIndex]);
          }
          return const SizedBox(height: AnchSpacing.xxl);
        },
      ),
    );
  }

  Widget _buildItemCard(ItemModel item) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: AnchSpacing.xs,
      ),
      child: ItemSummaryCard(
        item: item,
        memberName: _memberNames[item.memberId] ?? '家庭',
      ),
    );
  }
}
