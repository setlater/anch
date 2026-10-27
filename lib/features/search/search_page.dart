import '../item_entry/item_entry_flow_page.dart';
import '../../widgets/item_summary_card.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_model.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/service/item_search_service.dart';
import '../../core/repository/models/member_model.dart';
import '../../core/template/template_registry.dart';
import '../../core/service/policy/item_expiry_status_policy.dart';
import '../all_items/archived_items_page.dart';

/// 安册真实搜寻列表页面。
///
/// 遵循墨青暖纸视觉体系。
/// 初始显示指引导向，并在输入时执行低敏搜索；支持卡片渲染与详情路由刷新。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<ItemModel> _items = const [];
  List<ItemModel> _matchedItems = const [];
  Map<String, String> _memberNames = const {};
  String? _memberFilterId;
  String? _typeFilterKey;
  bool _pinnedOnly = false;
  bool _expiredOnly = false;
  bool _filtersExpanded = false;
  String _keyword = '';
  String _debouncedKeyword = '';
  Timer? _debounceTimer;
  bool _isSearching = false;
  int _requestId = 0;
  int _archivedMatchCount = 0;
  Set<String> _expiredItemIds = const {};
  ItemGlobalRegistry? _registry;

  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode.addListener(_handleSearchFocusChanged);
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _registry?.removeListener(_handleRegistryChanged);
    _searchFocusNode
      ..removeListener(_handleSearchFocusChanged)
      ..dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final query = _searchController.text.trim();
      if (!ItemSearchService.isLikelyHighSensitiveIdentifier(query) &&
          !RegExp(r'^\d{12,19}$').hasMatch(query)) {
        return;
      }
      _searchController.clear();
      _onSearchChanged('');
    }
  }

  void _handleSearchFocusChanged() {
    if (!mounted) return;
    setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
  }

  void _handleRegistryChanged() {
    if (!mounted || _searchController.text.trim().isEmpty) return;
    reloadItems();
  }

  void _onSearchChanged(String val) {
    _requestId++;
    setState(() {
      _keyword = val;
      if (val.trim() != _debouncedKeyword.trim()) {
        _memberFilterId = null;
        _typeFilterKey = null;
        _pinnedOnly = false;
        _expiredOnly = false;
        _filtersExpanded = false;
      }
    });

    _debounceTimer?.cancel();
    final trimVal = val.trim();

    if (trimVal.isEmpty) {
      setState(() {
        _debouncedKeyword = val;
        _items = const [];
        _matchedItems = const [];
        _memberNames = const {};
        _isSearching = false;
        _archivedMatchCount = 0;
        _expiredItemIds = const {};
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      final currentRequestId = _requestId;

      setState(() {
        _debouncedKeyword = val;
        _isSearching = true;
      });

      try {
        final di = DependencyProvider.of(context);
        final service = di.itemUseCaseService;
        final memberRepo = di.memberRepo;

        final results = await Future.wait([
          service.searchItems(trimVal),
          memberRepo.getActiveMembers(),
          di.itemRepo.getArchivedItemCount(keyword: trimVal),
        ]);

        final list = results[0] as List<ItemModel>;
        final members = results[1] as List<MemberModel>;
        final memberMap = {for (final m in members) m.id: m.name};
        final archivedMatchCount = results[2] as int;
        final now = di.timeDomainSource.now();
        final expiredItemIds = <String>{
          for (final item in list)
            if (ItemExpiryStatusPolicy.calculate(
                  typeKey: item.typeKey,
                  templateVersion: item.templateVersion,
                  rawState: item.rawState,
                  primaryText: item.primaryText,
                  now: now,
                ).status ==
                ItemExpiryStatus.expired)
              item.id,
        };

        if (mounted && currentRequestId == _requestId) {
          setState(() {
            _matchedItems = list;
            _memberNames = memberMap;
            _expiredItemIds = expiredItemIds;
            _items = _composeFilteredItems();
            _isSearching = false;
            _archivedMatchCount = archivedMatchCount;
          });
        }
      } catch (e) {
        if (mounted && currentRequestId == _requestId) {
          setState(() {
            _isSearching = false;
          });
          showDialog<void>(
            context: context,
            useRootNavigator: false,
            builder: (context) => AlertDialog(
              title: const Text(
                '搜索失败',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: const Text(
                '搜索时遇到错误，请重试。',
                style: TextStyle(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  Future<void> reloadItems() async {
    _onSearchChanged(_searchController.text);
  }

  List<ItemModel> _composeFilteredItems() {
    final filtered = _matchedItems
        .where((item) {
          if (_memberFilterId != null && item.memberId != _memberFilterId) {
            return false;
          }
          if (_typeFilterKey != null && item.typeKey != _typeFilterKey) {
            return false;
          }
          if (_pinnedOnly && !item.isPinned) return false;
          if (_expiredOnly && !_expiredItemIds.contains(item.id)) return false;
          return true;
        })
        .toList(growable: false);
    return filtered;
  }

  void _updateFilters(VoidCallback update) {
    setState(() {
      update();
      _items = _composeFilteredItems();
    });
  }

  String _typeLabel(String? typeKey) {
    if (typeKey == null) return '其他';
    return TemplateRegistry.getTemplate(typeKey)?.label ?? '其他';
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    final colors = context.anchColors;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? colors.accentDeep : colors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: colors.surfaceSoft,
      selectedColor: colors.accentSoft,
      side: BorderSide(color: selected ? colors.accent : colors.divider),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      onSelected: onSelected,
    );
  }

  Widget _buildFilters() {
    final memberIds =
        _matchedItems
            .map((item) => item.memberId)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort(
            (a, b) => (_memberNames[a] ?? '').compareTo(_memberNames[b] ?? ''),
          );
    final typeKeys =
        _matchedItems
            .map((item) => item.typeKey)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort((a, b) => _typeLabel(a).compareTo(_typeLabel(b)));
    final hasExpired = _expiredItemIds.isNotEmpty;
    final hasPinned = _matchedItems.any((item) => item.isPinned);
    final hasFilters =
        memberIds.length > 1 || typeKeys.length > 1 || hasPinned || hasExpired;
    final selectedCount = [
      _memberFilterId != null,
      _typeFilterKey != null,
      _pinnedOnly,
      _expiredOnly,
    ].where((selected) => selected).length;
    final filterLabel = _filtersExpanded ? '收起筛选' : '筛选';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AnchSpacing.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AnchSpacing.sm),
                  child: Text(
                    '找到 ${_items.length} 条资料',
                    key: const Key('search_result_count'),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.anchColors.textSecondary,
                    ),
                  ),
                ),
                if (hasFilters)
                  TextButton.icon(
                    key: const Key('search_filter_toggle'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.anchColors.accent,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () {
                      setState(() => _filtersExpanded = !_filtersExpanded);
                      if (_filtersExpanded) _searchFocusNode.unfocus();
                    },
                    icon: const AnchIcon(AnchIcons.filter, size: 18),
                    label: Text(
                      selectedCount == 0
                          ? filterLabel
                          : '$filterLabel · $selectedCount',
                    ),
                  ),
              ],
            ),
          ),
          if (_filtersExpanded && hasFilters)
            Column(
              key: const Key('search_filter_bar'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPinned || hasExpired)
                  _buildFilterGroup('状态', [
                    if (hasPinned)
                      _buildFilterChip(
                        label: '已置顶',
                        selected: _pinnedOnly,
                        onSelected: (selected) =>
                            _updateFilters(() => _pinnedOnly = selected),
                      ),
                    if (hasExpired)
                      _buildFilterChip(
                        label: '已到期',
                        selected: _expiredOnly,
                        onSelected: (selected) =>
                            _updateFilters(() => _expiredOnly = selected),
                      ),
                  ]),
                if (memberIds.isNotEmpty)
                  _buildFilterGroup('归属', [
                    for (final memberId in memberIds)
                      _buildFilterChip(
                        label: _memberNames[memberId] ?? '未归属',
                        selected: _memberFilterId == memberId,
                        onSelected: (selected) => _updateFilters(
                          () => _memberFilterId = selected ? memberId : null,
                        ),
                      ),
                  ]),
                if (typeKeys.isNotEmpty)
                  _buildFilterGroup('类型', [
                    for (final typeKey in typeKeys)
                      _buildFilterChip(
                        label: _typeLabel(typeKey),
                        selected: _typeFilterKey == typeKey,
                        onSelected: (selected) => _updateFilters(
                          () => _typeFilterKey = selected ? typeKey : null,
                        ),
                      ),
                  ]),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(String label, List<Widget> chips) {
    return Wrap(
      spacing: AnchSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.anchColors.textMuted),
        ),
        ...chips.map(
          (chip) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: chip,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final trimDebouncedKeyword = _debouncedKeyword.trim();

    if (trimDebouncedKeyword.isEmpty) {
      // 初始引导状态
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
            vertical: AnchSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnchIcon(
                AnchIcons.search,
                size: 48,
                color: context.anchColors.textMuted,
              ),
              SizedBox(height: AnchSpacing.md),
              Text(
                '输入关键词，查找已整理的资料',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.anchColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSearching) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.anchColors.accentDeep,
          ),
        ),
      );
    }

    Widget? emptyState;
    if (_items.isEmpty) {
      final sensitiveQuery = ItemSearchService.isLikelyHighSensitiveIdentifier(
        trimDebouncedKeyword,
      );
      final filteredOut = _matchedItems.isNotEmpty;
      // 搜索无结果空状态
      emptyState = AnchEmptyState(
        title: sensitiveQuery ? '不支持完整敏感号码搜索' : '未找到匹配资料',
        description: sensitiveQuery
            ? '请使用资料名称、类型或银行卡尾号查找。'
            : filteredOut
            ? '当前筛选条件下没有匹配资料，请清除筛选后查看。'
            : '没有找到匹配资料，请更换关键词或确认资料是否已归档。',
        actionLabel: sensitiveQuery
            ? null
            : filteredOut
            ? '清除筛选'
            : '去添加资料',
        onAction: sensitiveQuery
            ? null
            : () async {
                if (filteredOut) {
                  _updateFilters(() {
                    _memberFilterId = null;
                    _typeFilterKey = null;
                    _pinnedOnly = false;
                    _expiredOnly = false;
                  });
                  return;
                }
                await ItemEntryFlowPage.open(context);
                if (mounted) {
                  reloadItems();
                }
              },
      );
    }

    final prefix = <Widget>[
      _buildFilters(),
      if (_archivedMatchCount > 0)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
          ),
          leading: const AnchIcon(AnchIcons.archive),
          title: Text('已归档资料中有 $_archivedMatchCount 条匹配'),
          trailing: const AnchIcon(AnchIcons.chevronRight),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ArchivedItemsPage(keyword: _debouncedKeyword.trim()),
            ),
          ),
        ),
      ?emptyState,
    ];
    // 展示搜寻结果列表
    return ListView.builder(
      key: _items.isEmpty ? const Key('search_empty_results_scroll') : null,
      padding: const EdgeInsets.symmetric(vertical: AnchSpacing.sm),
      itemCount: prefix.length + _items.length,
      itemBuilder: (context, index) {
        if (index < prefix.length) return prefix[index];
        final item = _items[index - prefix.length];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
            vertical: AnchSpacing.xs,
          ),
          child: ItemSummaryCard(
            item: item,
            memberName: _memberNames[item.memberId] ?? '家庭',
            keyword: _keyword,
          ),
        );
      },
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final colors = context.anchColors;
    return Padding(
      padding: const EdgeInsets.all(AnchSpacing.page),
      child: AnimatedContainer(
        key: const Key('search_input_container'),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 52,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AnchRadius.md),
          border: Border.all(
            color: _isSearchFocused ? colors.accent : colors.divider,
            width: _isSearchFocused ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.only(left: AnchSpacing.md),
        child: Row(
          children: [
            AnchIcon(AnchIcons.search, size: 20, color: colors.textMuted),
            const SizedBox(width: AnchSpacing.sm),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: _onSearchChanged,
                cursorColor: colors.accent,
                decoration: InputDecoration(
                  hintText: '搜索银行卡 / 身份证 / 保险 / 车辆',
                  hintStyle: TextStyle(fontSize: 14, color: colors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(fontSize: 16, color: colors.textPrimary),
              ),
            ),
            if (_keyword.isNotEmpty)
              Semantics(
                button: true,
                label: '清空搜索内容',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: AnchIcon(
                        AnchIcons.cancel,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '搜索资料',
        foregroundColor: context.anchColors.textPrimary,
        backgroundColor: Colors.transparent,
        onBack: () => Navigator.pop(context),
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                ),
      ),
      body: Column(
        children: [
          if (RuntimeScope.of(context).isDevMode)
            const AnchSecurityBanner(
              message: AnchSecurityBanner.devModeMessage,
            ),
          _buildSearchField(context),

          // 搜索主展示区
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}
