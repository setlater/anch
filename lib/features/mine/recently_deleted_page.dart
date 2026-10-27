import 'package:flutter/material.dart';

import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_model.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_centered_notice.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';

class RecentlyDeletedPage extends StatefulWidget {
  const RecentlyDeletedPage({super.key});

  @override
  State<RecentlyDeletedPage> createState() => _RecentlyDeletedPageState();
}

class _RecentlyDeletedPageState extends State<RecentlyDeletedPage> {
  List<ItemModel> _items = const [];
  String? _pendingItemId;
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
    try {
      final items = await DependencyProvider.of(
        context,
      ).itemRepo.getDeletedItems();
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _items = items;
        _hasLoadedData = true;
      });
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() => _loadFailed = true);
      }
    }
  }

  Future<void> _restore(ItemModel item) async {
    if (_pendingItemId != null) return;
    setState(() => _pendingItemId = item.id);
    final dependencies = DependencyProvider.of(context);
    final snapshot = await dependencies.itemRepo.getItemWithFields(item.id);
    final result = snapshot == null
        ? null
        : await dependencies.itemUseCaseService.restoreItem(snapshot);
    if (!mounted) return;
    setState(() => _pendingItemId = null);
    if (result?.success == true) {
      AnchCenteredNotice.showSuccess(context, '资料已恢复');
    } else {
      AnchCenteredNotice.showError(context, '恢复失败，请重试');
    }
  }

  Future<void> _permanentlyDelete(ItemModel item) async {
    if (_pendingItemId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除资料？'),
        content: const Text('永久删除后无法从最近删除中恢复；已有外部备份不会受到影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.anchColors.danger,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _pendingItemId = item.id);
    final result = await DependencyProvider.of(
      context,
    ).itemUseCaseService.permanentlyDeleteItem(item.id);
    if (!mounted) return;
    setState(() => _pendingItemId = null);
    if (result.success) {
      AnchCenteredNotice.showSuccess(context, '资料已永久删除');
    } else {
      AnchCenteredNotice.showError(context, '永久删除失败，请重试');
    }
  }

  String _formatDeletedAt(int? milliseconds) {
    if (milliseconds == null) return '删除时间未知';
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '最近删除',
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          if (_loadFailed)
            Flexible(
              flex: _hasLoadedData ? 0 : 1,
              child: SingleChildScrollView(
                child: AnchEmptyState.loadError(
                  onRetry: _reload,
                  hasContent: _hasLoadedData,
                ),
              ),
            ),
          if (!_hasLoadedData && !_loadFailed)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_hasLoadedData)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                color: colors.accent,
                backgroundColor: colors.surface,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: AnchSpacing.md),
                    if (_items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AnchSpacing.xxl),
                        child: Text(
                          '暂无最近删除的资料',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textMuted),
                        ),
                      )
                    else
                      for (final item in _items)
                        Container(
                          margin: const EdgeInsets.fromLTRB(
                            AnchSpacing.page,
                            0,
                            AnchSpacing.page,
                            AnchSpacing.sm,
                          ),
                          padding: const EdgeInsets.all(AnchSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(AnchRadius.lg),
                            border: Border.all(color: colors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title?.trim().isNotEmpty == true
                                    ? item.title!.trim()
                                    : '未命名资料',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AnchSpacing.xs),
                              Text(
                                _formatDeletedAt(item.deletedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: AnchSpacing.sm),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _pendingItemId == null
                                          ? () => _restore(item)
                                          : null,
                                      child: const Text('恢复'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: colors.danger,
                                      ),
                                      onPressed: _pendingItemId == null
                                          ? () => _permanentlyDelete(item)
                                          : null,
                                      child: const Text('永久删除'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: AnchSpacing.xxl),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
