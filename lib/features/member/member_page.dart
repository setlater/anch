import '../item_entry/item_entry_flow_page.dart';
import '../../core/repository/models/item_model.dart';
import '../../widgets/item_summary_card.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../app/dependency_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/repository/models/member_model.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_motion.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_header_action.dart';
import '../../core/widgets/anch_member_avatar.dart';
import '../../core/widgets/anch_page_header.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import 'member_form_sheet.dart';

/// 成员页。
///
/// 展示当前会话中的家庭成员列表，每个成员卡片显示：
/// - 成员标识、名称、说明
/// - 该成员下的资料数量（根据当前会话数据计算）
///
/// 点击成员卡片进入该成员的资料列表（只展示低敏摘要）。
class MemberPage extends StatefulWidget {
  final bool isActive;
  const MemberPage({super.key, this.isActive = true});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  _MemberPageData? _memberPageData;
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
  void didUpdateWidget(covariant MemberPage oldWidget) {
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
    try {
      final data = await _fetchData();
      if (mounted && request == _loadRequest) {
        setState(() {
          _hasLoadedData = true;
          _memberPageData = data;
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

  Future<_MemberPageData> _fetchData() async {
    final memberRepo = DependencyProvider.of(context).memberRepo;
    final itemRepo = DependencyProvider.of(context).itemRepo;

    final results = await Future.wait<Object>([
      memberRepo.getActiveMembers(),
      itemRepo.getActiveMemberCounts(),
    ]);
    final members = results[0] as List<MemberModel>;
    final countMap = results[1] as Map<String, int>;

    return _MemberPageData(members: members, countMap: countMap);
  }

  @override
  Widget build(BuildContext context) {
    return AnchAppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnchPageHeader(
            title: '成员',
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
            AnchEmptyState.loadError(onRetry: reloadItems, hasContent: true),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnchMotion.bottomSheetAnimationStyle(context),
      builder: (_) => const MemberFormSheet(),
    ).then((result) {
      if (result != null) {
        reloadItems();
      }
    });
  }

  void _goToMemberItems(MemberModel member) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberItemsPage(member: member)),
    ).then((_) => reloadItems());
  }

  Future<void> _goToEntry() async {
    final result = await ItemEntryFlowPage.open(context);
    if (!mounted) return;
    if (result != null && result is String) {
      await ItemSummaryCard.openDetail(context, result);
    }
  }

  Widget _buildMemberRow({
    required BuildContext context,
    required String name,
    required int itemCount,
    required Widget leading,
    bool showChevron = true,
    String? customSubtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.anchColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
            vertical: 14,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AnchSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customSubtitle ?? '$itemCount 项资料',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                AnchIcon(
                  AnchIcons.chevronRight,
                  size: 20,
                  color: colors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(height: 1, color: color);
  }

  Widget _buildContent() {
    if (_loadFailed && !_hasLoadedData) {
      return AnchEmptyState.loadError(onRetry: reloadItems);
    }

    if (_isLoading && _memberPageData == null) {
      if (!widget.isActive) return const SizedBox.shrink();
      return Center(
        child: CircularProgressIndicator(
          color: context.anchColors.accentDeep,
          strokeWidth: 2,
        ),
      );
    }

    final data = _memberPageData;
    if (data == null || data.members.isEmpty) {
      return AnchEmptyState(
        title: '暂无资料',
        description: '通过搜索或添加资料开始使用',
        actionLabel: '去添加资料',
        onAction: _goToEntry,
      );
    }

    MemberModel? familyMember;
    MemberModel? meMember;
    final List<MemberModel> customMembers = [];

    for (final m in data.members) {
      if (m.id == systemFamilyMemberId) {
        familyMember = m;
      } else if (m.id == systemMeMemberId) {
        meMember = m;
      } else {
        customMembers.add(m);
      }
    }

    final colors = context.anchColors;

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.surface,
      onRefresh: () async => reloadItems(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (familyMember != null) ...[
                  _buildMemberRow(
                    context: context,
                    name: familyMember.name,
                    itemCount: data.countMap[familyMember.id] ?? 0,
                    leading: AnchMemberAvatar(
                      memberId: familyMember.id,
                      name: familyMember.name,
                    ),
                    onTap: () => _goToMemberItems(familyMember!),
                  ),
                  _buildDivider(colors.divider),
                ],
                if (meMember != null) ...[
                  _buildMemberRow(
                    context: context,
                    name: meMember.name,
                    itemCount: data.countMap[meMember.id] ?? 0,
                    leading: AnchMemberAvatar(
                      memberId: meMember.id,
                      name: meMember.name,
                    ),
                    onTap: () => _goToMemberItems(meMember!),
                  ),
                ],
                if (customMembers.isNotEmpty) ...[
                  _buildDivider(colors.divider),
                  ...customMembers.map((m) {
                    final isLast = m == customMembers.last;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMemberRow(
                          context: context,
                          name: m.name,
                          itemCount: data.countMap[m.id] ?? 0,
                          leading: AnchMemberAvatar(
                            memberId: m.id,
                            name: m.name,
                          ),
                          onTap: () => _goToMemberItems(m),
                        ),
                        if (!isLast) _buildDivider(colors.divider),
                      ],
                    );
                  }),
                ],
                _buildDivider(colors.divider),
                _buildMemberRow(
                  context: context,
                  name: '新增家庭成员',
                  itemCount: 0,
                  customSubtitle: '父母、配偶、孩子或其他',
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.divider),
                    ),
                    child: AnchIcon(
                      AnchIcons.add,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                  ),
                  showChevron: false,
                  onTap: () => _showAddMemberSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AnchSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── 成员下资料列表页 ────────────────────────────────────────────────────────

/// 某成员下的资料列表页。
///
/// 安全规则：只展示低敏摘要（title、categoryKey、typeKey、primaryText），
/// 不展示完整高敏字段。
class MemberItemsPage extends StatefulWidget {
  const MemberItemsPage({super.key, required this.member});

  final MemberModel member;

  @override
  State<MemberItemsPage> createState() => _MemberItemsPageState();
}

class _MemberItemsPageState extends State<MemberItemsPage> {
  late MemberModel _member;
  List<ItemModel> _items = const [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _hasLoadedData = false;
  int _loadRequest = 0;

  ItemGlobalRegistry? _registry;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
  }

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
      final latestMember = await memberRepo.getMemberById(_member.id);
      final list = await itemRepo.getActiveItems(memberId: _member.id);
      final summaries = list
          .map((item) => item.toListSummary())
          .toList(growable: false);

      if (mounted && request == _loadRequest) {
        setState(() {
          _hasLoadedData = true;
          if (latestMember != null) {
            _member = latestMember;
          }
          _items = summaries;
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

  void _showEditMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnchMotion.bottomSheetAnimationStyle(context),
      builder: (_) =>
          MemberFormSheet(existingMember: _member, itemCount: _items.length),
    ).then((result) {
      if (!mounted) return;
      if (result == 'deleted') {
        if (!context.mounted) return;
        Navigator.pop(context);
      } else if (result != null) {
        reloadItems();
      }
    });
  }

  Future<void> _goToEntry() async {
    final result = await ItemEntryFlowPage.open(
      context,
      initialMemberId: _member.id,
    );
    if (!mounted) return;
    if (result is String) {
      await ItemSummaryCard.openDetail(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      floatingActionButton: !_isLoading && _items.isNotEmpty
          ? FloatingActionButton(
              key: const Key('member_items_add_fab'),
              onPressed: _goToEntry,
              tooltip: '新增资料',
              backgroundColor: colors.accent,
              foregroundColor: colors.accentInk,
              child: AnchIcon(AnchIcons.add, size: 28, color: colors.accentInk),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnchPageHeader(
            title: _member.name,
            titleTrailingText: _isLoading ? null : '[${_items.length}条]',
            onBack: () => Navigator.pop(context),
            padding: const EdgeInsets.fromLTRB(
              AnchSpacing.page,
              AnchSpacing.lg,
              AnchSpacing.page,
              AnchSpacing.xs,
            ),
            trailingFollowsTitle: true,
            trailing: _member.isSystem
                ? null
                : AnchHeaderAction(
                    icon: AnchIcons.edit,
                    semanticLabel: '编辑成员',
                    onTap: () => _showEditMemberSheet(context),
                  ),
          ),

          if (RuntimeScope.of(context).isDevMode)
            const AnchSecurityBanner(
              message: AnchSecurityBanner.devModeMessage,
              type: AnchBannerType.warning,
            ),

          const SizedBox(height: AnchSpacing.xs),
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
        onAction: _goToEntry,
      );
    }

    return ListView.builder(
      itemCount: list.length + 1,
      itemBuilder: (context, index) => index < list.length
          ? _buildItemCard(list[index])
          : const SizedBox(height: AnchSpacing.xxl),
    );
  }

  Widget _buildItemCard(ItemModel item) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: AnchSpacing.xs,
      ),
      child: ItemSummaryCard(item: item, memberName: _member.name),
    );
  }
}

// ─── 数据容器 ────────────────────────────────────────────────────────────────

class _MemberPageData {
  const _MemberPageData({required this.members, required this.countMap});

  final List<MemberModel> members;
  final Map<String, int> countMap;
}
