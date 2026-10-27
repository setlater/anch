import '../../widgets/item_summary_card.dart';
import 'package:flutter/material.dart';

import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_model.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';

class ArchivedItemsPage extends StatefulWidget {
  const ArchivedItemsPage({super.key, this.keyword});

  final String? keyword;

  @override
  State<ArchivedItemsPage> createState() => _ArchivedItemsPageState();
}

class _ArchivedItemsPageState extends State<ArchivedItemsPage> {
  List<ItemModel> _items = const [];
  Map<String, String> _memberNames = const {};
  bool _hasLoadedData = false;
  bool _loadFailed = false;
  int _loadRequest = 0;
  ItemGlobalRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = DependencyProvider.of(context).itemUseCaseService.registry;
    if (_registry != registry) {
      _registry?.removeListener(_reload);
      _registry = registry;
      registry.addListener(_reload);
      _reload();
    }
  }

  @override
  void dispose() {
    _registry?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_loadRequest;
    setState(() => _loadFailed = false);
    final di = DependencyProvider.of(context);
    try {
      final results = await Future.wait<Object>([
        di.itemRepo.getArchivedItems(keyword: widget.keyword),
        di.memberRepo.getActiveMembers(),
      ]);
      if (!mounted || request != _loadRequest) return;
      final items = results[0] as List<ItemModel>;
      final members = results[1] as List;
      setState(() {
        _items = items
            .map((item) => item.toListSummary())
            .toList(growable: false);
        _memberNames = {for (final member in members) member.id: member.name};
        _hasLoadedData = true;
      });
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() => _loadFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKeyword = widget.keyword?.trim().isNotEmpty == true;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '已归档资料',
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          const SizedBox(height: AnchSpacing.sm),
          if (_loadFailed && _hasLoadedData)
            AnchEmptyState.loadError(onRetry: _reload, hasContent: true),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loadFailed && !_hasLoadedData) {
                  return SingleChildScrollView(
                    child: AnchEmptyState.loadError(onRetry: _reload),
                  );
                }
                if (!_hasLoadedData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.anchColors.accentDeep,
                      strokeWidth: 2,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  color: context.anchColors.accent,
                  backgroundColor: context.anchColors.surface,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.isEmpty ? 1 : _items.length,
                    itemBuilder: (context, index) {
                      if (_items.isEmpty) {
                        return AnchEmptyState(
                          title: hasKeyword ? '归档中无匹配资料' : '暂无已归档资料',
                          description: hasKeyword
                              ? '返回搜索页修改关键词'
                              : '归档后的资料会显示在这里',
                        );
                      }
                      final item = _items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AnchSpacing.page,
                          vertical: AnchSpacing.xs,
                        ),
                        child: ItemSummaryCard(
                          item: item,
                          memberName: _memberNames[item.memberId] ?? '家庭',
                          onDetailClosed: () {
                            if (mounted) _reload();
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
