import '../../widgets/item_summary_card.dart';
import 'package:flutter/material.dart';
import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_model.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../../core/widgets/anch_section_header.dart';
import '../../core/service/item_expiry_overview_service.dart';
import '../../core/service/policy/item_expiry_status_policy.dart';

class ExpiryItemsPage extends StatefulWidget {
  final List<ItemModel> items;
  final Map<String, String> memberNameById;
  final DateTime now;

  const ExpiryItemsPage({
    super.key,
    required this.items,
    required this.memberNameById,
    required this.now,
  });

  @override
  State<ExpiryItemsPage> createState() => _ExpiryItemsPageState();
}

class _ExpiryItemsPageState extends State<ExpiryItemsPage> {
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequest = 0;
  List<ItemModel> _expiredItems = const [];
  List<ItemModel> _todayItems = const [];
  List<ItemModel> _within7DaysItems = const [];
  List<ItemModel> _within30DaysItems = const [];
  Map<String, String> _memberMap = const {};

  @override
  void initState() {
    super.initState();
    _memberMap = widget.memberNameById;
    final groups = _classifyItems(widget.items, widget.now);
    _expiredItems = groups.expired;
    _todayItems = groups.today;
    _within7DaysItems = groups.within7;
    _within30DaysItems = groups.within30;
  }

  _ExpiryGroups _classifyItems(List<ItemModel> rawItems, DateTime now) {
    final overview = ItemExpiryOverviewService.calculate(rawItems, now);

    final List<ItemModel> expired = [];
    final List<ItemModel> today = [];
    final List<ItemModel> within7 = [];
    final List<ItemModel> within30 = [];

    for (final entry in overview.actionableEntries) {
      if (entry.statusResult.status == ItemExpiryStatus.expired) {
        expired.add(entry.item);
      } else if (entry.statusResult.status == ItemExpiryStatus.today) {
        today.add(entry.item);
      } else if (entry.statusResult.status == ItemExpiryStatus.upcoming) {
        if (entry.statusResult.daysUntilExpiry != null &&
            entry.statusResult.daysUntilExpiry! <= 7) {
          within7.add(entry.item);
        } else {
          within30.add(entry.item);
        }
      }
    }

    return _ExpiryGroups(
      expired: expired,
      today: today,
      within7: within7,
      within30: within30,
    );
  }

  Future<void> _loadData() async {
    final request = ++_loadRequest;
    setState(() => _loadFailed = false);
    if (!_hasData) setState(() => _isLoading = true);
    final di = DependencyProvider.of(context);
    try {
      final results = await Future.wait([
        di.memberRepo.getActiveMembers(),
        di.itemRepo.getActiveItems(),
      ]);
      final members = results[0] as List;
      final items = results[1] as List<ItemModel>;

      final memberMap = <String, String>{
        for (final m in members) m.id as String: m.name as String,
      };

      if (mounted && request == _loadRequest) {
        final groups = _classifyItems(items, di.timeDomainSource.now());
        setState(() {
          _memberMap = memberMap;
          _expiredItems = groups.expired;
          _todayItems = groups.today;
          _within7DaysItems = groups.within7;
          _within30DaysItems = groups.within30;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _loadFailed = true);
    } finally {
      if (mounted && request == _loadRequest && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '到期资料',
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          if (_loadFailed)
            AnchEmptyState.loadError(onRetry: _loadData, hasContent: true),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accentDeep,
                    ),
                  )
                : !_hasData
                ? const AnchEmptyState(
                    title: '暂无到期资料',
                    description: '暂无即将到期的资料',
                  )
                : CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: _InAppExpiryNotice()),
                      ..._buildGroup('已过期', _expiredItems),
                      ..._buildGroup('今日到期', _todayItems),
                      ..._buildGroup('7 天内到期', _within7DaysItems),
                      ..._buildGroup('30 天内到期', _within30DaysItems),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool get _hasData =>
      _expiredItems.isNotEmpty ||
      _todayItems.isNotEmpty ||
      _within7DaysItems.isNotEmpty ||
      _within30DaysItems.isNotEmpty;

  List<Widget> _buildGroup(String title, List<ItemModel> items) {
    if (items.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: AnchSectionHeader(title: title)),
      SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => _buildCard(items[index]),
      ),
    ];
  }

  Widget _buildCard(ItemModel item) {
    final memberName = _memberMap[item.memberId] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: AnchSpacing.xs,
      ),
      child: ItemSummaryCard(
        item: item,
        memberName: memberName,
        onDetailClosed: () {
          if (mounted) _loadData();
        },
      ),
    );
  }
}

class _InAppExpiryNotice extends StatelessWidget {
  const _InAppExpiryNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AnchSpacing.page,
        AnchSpacing.md,
        AnchSpacing.page,
        AnchSpacing.sm,
      ),
      padding: const EdgeInsets.all(AnchSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '到期状态仅在安册内显示，不会发送系统通知。',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ExpiryGroups {
  const _ExpiryGroups({
    required this.expired,
    required this.today,
    required this.within7,
    required this.within30,
  });

  final List<ItemModel> expired;
  final List<ItemModel> today;
  final List<ItemModel> within7;
  final List<ItemModel> within30;
}
