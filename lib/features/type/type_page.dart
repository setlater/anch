import '../item_entry/item_entry_flow_page.dart';
import '../../core/runtime/runtime_scope.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../widgets/item_summary_card.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_model.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_adaptive_layout.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_page_header.dart';
import '../../core/widgets/anch_header_action.dart';
import '../../core/widgets/anch_category_index_item.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/template/type_definition.dart';
import '../../core/template/template_registry.dart';

class TypePage extends StatefulWidget {
  final bool isActive;

  const TypePage({super.key, this.isActive = true});

  @override
  State<TypePage> createState() => _TypePageState();
}

class _TypePageState extends State<TypePage> {
  Map<String, int>? _typeCounts;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _hasLoadedData = false;
  int _loadRequest = 0;

  ItemGlobalRegistry? _registry;
  bool _hasLoaded = false;

  @override
  void dispose() {
    _registry?.removeListener(_handleRegistryChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TypePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadCount();
    }
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
    if (widget.isActive && !_hasLoaded) _loadCount();
  }

  void _handleRegistryChanged() {
    if (widget.isActive) _loadCount();
  }

  Future<void> _loadCount() async {
    final request = ++_loadRequest;
    setState(() {
      _loadFailed = false;
      if (!_hasLoadedData) _isLoading = true;
    });
    _hasLoaded = true;
    final itemRepo = DependencyProvider.of(context).itemRepo;
    try {
      final map = await itemRepo.getActiveTypeCounts();
      if (mounted && request == _loadRequest) {
        setState(() {
          _hasLoadedData = true;
          _typeCounts = map;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() {
          _loadFailed = true;
          if (!_hasLoadedData) _typeCounts = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _goToEntry() async {
    final result = await ItemEntryFlowPage.open(context);
    if (!mounted) return;
    if (result is String) await ItemSummaryCard.openDetail(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final countMap = _typeCounts ?? {};
    final types = [
      for (final entry in countMap.entries)
        if (entry.value > 0)
          TemplateRegistry.getTemplate(entry.key) ??
              TypeDefinition(
                typeKey: entry.key,
                label: '历史资料',
                categoryKey: 'other',
                fields: const [],
                isAvailableForCreation: false,
              ),
    ];

    return AnchAppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnchPageHeader(
            title: '分类',
            trailing: AnchHeaderAction(
              icon: AnchIcons.add,
              label: '新增',
              semanticLabel: '新增资料',
              onTap: _goToEntry,
            ),
          ),

          if (RuntimeScope.of(context).isDevMode)
            const AnchSecurityBanner(
              message: AnchSecurityBanner.devModeMessage,
              type: AnchBannerType.warning,
            ),
          const SizedBox(height: AnchSpacing.sm),
          if (_loadFailed && _hasLoadedData)
            AnchEmptyState.loadError(onRetry: _loadCount, hasContent: true),
          Expanded(child: _buildContent(types)),
        ],
      ),
    );
  }

  Widget _buildContent(List<TypeDefinition> types) {
    if (_isLoading && _typeCounts == null) {
      if (!widget.isActive) return const SizedBox.shrink();
      return Center(
        child: CircularProgressIndicator(
          color: context.anchColors.accentDeep,
          strokeWidth: 2,
        ),
      );
    }

    if (_typeCounts == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AnchSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnchIcon(
                AnchIcons.error,
                color: context.anchColors.textMuted,
                size: 48,
              ),
              const SizedBox(height: AnchSpacing.md),
              Text(
                '加载分类失败，请稍后重试',
                style: TextStyle(
                  fontSize: 14,
                  color: context.anchColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AnchSpacing.lg),
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                    });
                  }
                  _loadCount();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.anchColors.accent,
                  foregroundColor: context.anchColors.accentInk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    if (types.isEmpty) {
      return AnchEmptyState(
        title: '暂无分类资料',
        description: '通过添加资料开始使用',
        actionLabel: '去添加资料',
        onAction: () async {
          await ItemEntryFlowPage.open(context);
        },
      );
    }

    final countMap = _typeCounts ?? {};

    return RefreshIndicator(
      color: context.anchColors.accent,
      backgroundColor: context.anchColors.surface,
      onRefresh: () async => _loadCount(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const horizontalPadding = AnchSpacing.page * 2;
          const spacing = AnchSpacing.md;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final largeText = textScale >= 1.5;
          final tileExtent = largeText
              ? 160.0
              : 88.0 + ((textScale - 1).clamp(0.0, 1.0) * 40.0);
          final columns = AnchAdaptiveGrid.columnCountFor(
            availableWidth: constraints.maxWidth - horizontalPadding,
            minTileWidth: largeText ? 280 : 144,
            spacing: spacing,
            maxColumns: 3,
          );
          return GridView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AnchSpacing.page,
              vertical: AnchSpacing.xs,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: tileExtent,
            ),
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              final count = countMap[type.typeKey] ?? 0;
              return _TypeCard(
                type: type,
                itemCount: count,
                onTap: () => _goToTypeItems(type),
              );
            },
          );
        },
      ),
    );
  }

  void _goToTypeItems(TypeDefinition type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TypeItemsPage(type: type)),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.itemCount,
    required this.onTap,
  });

  final TypeDefinition type;
  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnchCategoryIndexItem(
      icon: AnchIcons.forTypeKey(type.typeKey),
      title: type.label,
      itemCount: itemCount,
      onTap: onTap,
    );
  }
}

class TypeItemsPage extends StatefulWidget {
  const TypeItemsPage({super.key, required this.type});

  final TypeDefinition type;

  @override
  State<TypeItemsPage> createState() => _TypeItemsPageState();
}

class _TypeItemsPageState extends State<TypeItemsPage> {
  List<ItemModel> _items = const [];
  Map<String, String> _memberNames = const {};
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _hasLoadedData = false;
  int _loadRequest = 0;

  ItemGlobalRegistry? _registry;
  bool _hasLoaded = false;

  @override
  void dispose() {
    _registry?.removeListener(_handleRegistryChanged);
    super.dispose();
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
    if (!_hasLoaded) reloadItems();
  }

  void _handleRegistryChanged() => reloadItems();

  Future<void> reloadItems() async {
    final request = ++_loadRequest;
    setState(() {
      _loadFailed = false;
      if (!_hasLoadedData) _isLoading = true;
    });
    _hasLoaded = true;
    final itemRepo = DependencyProvider.of(context).itemRepo;
    final memberRepo = DependencyProvider.of(context).memberRepo;

    try {
      final results = await Future.wait([
        memberRepo.getActiveMembers(),
        itemRepo.getActiveItems(typeKey: widget.type.typeKey),
      ]);
      final members = results[0] as List;
      final list = results[1] as List<ItemModel>;
      final memberMap = <String, String>{for (final m in members) m.id: m.name};

      final summaries = list
          .map((item) => item.toListSummary())
          .toList(growable: false);

      if (mounted && request == _loadRequest) {
        setState(() {
          _hasLoadedData = true;
          _items = summaries;
          _memberNames = memberMap;
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

  @override
  Widget build(BuildContext context) {
    return AnchAppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnchPageHeader(
            title: widget.type.label,
            titleTrailingText: _isLoading ? null : '[${_items.length}条]',
            onBack: () => Navigator.pop(context),
          ),

          if (RuntimeScope.of(context).isDevMode)
            const AnchSecurityBanner(
              message: AnchSecurityBanner.devModeMessage,
              type: AnchBannerType.warning,
            ),
          const SizedBox(height: AnchSpacing.sm),
          if (_loadFailed && _hasLoadedData)
            AnchEmptyState.loadError(onRetry: reloadItems, hasContent: true),
          Expanded(child: _buildItemsContent()),
        ],
      ),
    );
  }

  Widget _buildItemsContent() {
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

    final list = _items;

    if (list.isEmpty) {
      return AnchEmptyState(
        title: '暂无资料',
        description: '通过搜索或添加资料开始使用',
        actionLabel: '去添加资料',
        onAction: () async {
          final result = await ItemEntryFlowPage.open(context);
          if (!mounted) return;
          if (result != null && result is String) {
            await ItemSummaryCard.openDetail(context, result);
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.anchColors.accent,
        onPressed: () async {
          final result = await ItemEntryFlowPage.open(context);
          if (!mounted) return;
          if (result != null && result is String) {
            await ItemSummaryCard.openDetail(context, result);
          }
        },
        child: AnchIcon(AnchIcons.add, color: context.anchColors.accentInk),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          return Padding(
            key: Key('type_item_card_spacing_${item.id}'),
            padding: const EdgeInsets.only(bottom: AnchSpacing.sm),
            child: ItemSummaryCard(
              item: item,
              memberName: _memberNames[item.memberId] ?? '家庭',
            ),
          );
        },
      ),
    );
  }
}
