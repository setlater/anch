import '../item_entry/item_entry_flow_page.dart';
import 'dart:async';

import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/dependency_provider.dart';
import '../../core/repository/models/item_with_fields.dart';
import '../../core/repository/models/member_model.dart';
import '../../core/repository/models/item_child_entry_model.dart';
import '../../core/template/template_registry.dart';
import '../../core/service/builder/item_text_builder.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_motion.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_bottom_sheet.dart';
import '../../core/widgets/anch_blocking_progress_overlay.dart';
import '../../core/widgets/anch_header_action.dart';
import '../../core/widgets/anch_route_back.dart';
import '../../core/widgets/anch_centered_notice.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import '../privacy/privacy_shield_coordinator.dart';
import '../privacy/privacy_shield_controller.dart';
import '../privacy/screen_protection_scope.dart';
import '../../core/service/item_use_case_service.dart';
import '../../core/security/field_render_policy.dart';
import '../../core/attachment/attachment_persistence_service.dart';
import '../../core/attachment/attachment_encrypted_file_writer.dart';
import '../../core/attachment/attachment_model.dart';
import '../../core/attachment/attachment_payload_reader.dart';
import '../../core/attachment/attachment_preview_policy.dart';
import '../../core/attachment/android_attachment_external_open_service.dart';
import '../../core/service/policy/item_expiry_status_policy.dart';
import '../../core/service/shipping_address_parser.dart';
import '../../core/service/insurance_renewal_service.dart';
import 'attachment_image_gallery_selection.dart';
import 'attachment_image_selection.dart';
import 'attachment_import_controller.dart';
import 'decrypted_image_preview_page.dart';
import 'decrypted_document_preview_page.dart';
import 'detail_copy_interaction.dart';
import 'item_detail_field_sections.dart';
import 'item_detail_attachments_section.dart';

enum _AttachmentImportSource { camera, gallery, file }

class _ItemDetailLoadData {
  const _ItemDetailLoadData({
    required this.item,
    required this.member,
    required this.childEntries,
  });

  final ItemWithFields item;
  final MemberModel? member;
  final List<ItemChildEntryModel> childEntries;
}

/// 资料详情页。
///
/// 展示已保存资料的视觉结构与字段详情。
/// 支持字段卡片分组（基本信息、高敏字段、补充信息等）与高敏字段查看/复制交互。
class ItemDetailPage extends StatefulWidget {
  final String itemId;
  final PrivacyShieldCoordinator? privacyShieldCoordinator;
  final Future<ItemWithFields?>? prefetchedItem;

  const ItemDetailPage({
    super.key,
    required this.itemId,
    this.privacyShieldCoordinator,
    this.prefetchedItem,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage>
    with WidgetsBindingObserver {
  bool _isEdited = false;
  final Set<String> _revealedFieldKeys = {};
  List<ItemChildEntryModel> _householdChildEntries = [];
  final Set<String> _revealedChildFieldIds = {};

  ItemWithFields? _currentItem;
  MemberModel? _currentMember;
  bool _actionTraceExpanded = false;

  bool _isLoading = true;
  bool _initialLoadStarted = false;
  bool _initialLoadReady = false;
  bool _routeTransitionComplete = false;
  int _initialLoadGeneration = 0;
  _ItemDetailLoadData? _pendingInitialData;
  String? _pendingInitialError;
  Animation<double>? _initialLoadAnimation;
  AnimationStatusListener? _initialLoadStatusListener;
  final _copyInteraction = DetailCopyInteraction.system();

  @override
  void didUpdateWidget(ItemDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) {
      _initialLoadGeneration += 1;
      _isLoading = true;
      _loadingError = null;
      _currentItem = null;
      _currentMember = null;
      _revealedFieldKeys.clear();
      _revealedChildFieldIds.clear();
      _householdChildEntries = [];
      _initialLoadStarted = false;
      _initialLoadReady = false;
      _pendingInitialData = null;
      _pendingInitialError = null;
      _startInitialLoad();
    }
  }

  bool _isReloading = false;
  bool _isSavingOverlayVisible = false;
  bool _isImportingFileAttachment = false;
  bool _isOpeningExternalAttachment = false;
  bool _isSelectingFileAttachment = false;
  final AttachmentImportController _fileAttachmentImportController =
      AttachmentImportController();
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    final animation = _initialLoadAnimation;
    final listener = _initialLoadStatusListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_fileAttachmentImportController.clearFilePickerSessionLocation());
    _copyInteraction.dispose();
    _revealedFieldKeys.clear();
    if (widget.privacyShieldCoordinator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.privacyShieldCoordinator?.clear(
          source: PrivacyShieldSource.itemDetail,
        );
      });
    }
    super.dispose();
  }

  void _updatePrivacyShield() {
    // 前台查看高敏字段不能触发全屏遮罩，否则用户无法完成查看操作。
    // 应用进入后台时，生命周期遮罩与字段自动收起仍独立生效。
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.itemDetail,
    );
  }

  void _hideAllSensitiveFields() {
    bool changed = false;
    if (_revealedFieldKeys.isNotEmpty) {
      _revealedFieldKeys.clear();
      changed = true;
    }
    if (_revealedChildFieldIds.isNotEmpty) {
      _revealedChildFieldIds.clear();
      changed = true;
    }
    if (changed) {
      if (mounted) {
        setState(() {});
      }
      _updatePrivacyShield();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed ||
        state.toString().contains('hidden')) {
      _hideAllSensitiveFields();
    }
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state.toString().contains('hidden')) &&
        !_isSelectingFileAttachment) {
      unawaited(
        _fileAttachmentImportController.clearFilePickerSessionLocation(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchRouteTransition();
    _startInitialLoad();
  }

  /// 数据读取立即开始，但完整详情树只在路由转场结束后一次性提交。
  void _watchRouteTransition() {
    if (_routeTransitionComplete || _initialLoadAnimation != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _routeTransitionComplete = true;
      _applyInitialLoadIfReady();
      return;
    }

    _initialLoadAnimation = animation;
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      _initialLoadStatusListener = null;
      _initialLoadAnimation = null;
      _routeTransitionComplete = true;
      _applyInitialLoadIfReady();
    };
    _initialLoadStatusListener = listener;
    animation.addStatusListener(listener);
  }

  void _startInitialLoad() {
    if (_initialLoadStarted || !_isLoading) return;
    _initialLoadStarted = true;
    final generation = _initialLoadGeneration;
    _fetchInitialData(
      generation: generation,
      itemId: widget.itemId,
      prefetchedItem: widget.prefetchedItem,
    );
  }

  Future<void> _fetchInitialData({
    required int generation,
    required String itemId,
    required Future<ItemWithFields?>? prefetchedItem,
  }) async {
    final itemRepo = DependencyProvider.of(context).itemRepo;
    final memberRepo = DependencyProvider.of(context).memberRepo;
    try {
      final item = await (prefetchedItem ?? itemRepo.getItemWithFields(itemId));
      if (item == null || item.id != itemId) {
        _completeInitialLoad(generation: generation, error: '未找到对应的资料数据');
        return;
      }
      final relatedData = await Future.wait([
        item.memberId != null
            ? memberRepo.getMemberById(item.memberId!)
            : Future<MemberModel?>.value(null),
        item.typeKey == 'household_book'
            ? itemRepo.getChildEntries(itemId)
            : Future<List<ItemChildEntryModel>>.value(const []),
      ]);
      _completeInitialLoad(
        generation: generation,
        data: _ItemDetailLoadData(
          item: item,
          member: relatedData[0] as MemberModel?,
          childEntries: relatedData[1] as List<ItemChildEntryModel>,
        ),
      );
    } catch (_) {
      _completeInitialLoad(generation: generation, error: '当前无法打开这份资料，请返回后重试。');
    }
  }

  void _completeInitialLoad({
    required int generation,
    _ItemDetailLoadData? data,
    String? error,
  }) {
    if (!mounted || generation != _initialLoadGeneration) return;
    _pendingInitialData = data;
    _pendingInitialError = error;
    _initialLoadReady = true;
    _applyInitialLoadIfReady();
  }

  void _applyInitialLoadIfReady() {
    if (!mounted || !_routeTransitionComplete || !_initialLoadReady) return;
    final data = _pendingInitialData;
    setState(() {
      _currentItem = data?.item;
      _currentMember = data?.member;
      _householdChildEntries = data?.childEntries ?? const [];
      _loadingError = _pendingInitialError;
      _isLoading = false;
      _initialLoadReady = false;
      _pendingInitialData = null;
      _pendingInitialError = null;
    });
  }

  Future<void> reloadItems() async {
    if (_isReloading) return;
    _isReloading = true;
    final itemRepo = DependencyProvider.of(context).itemRepo;
    final memberRepo = DependencyProvider.of(context).memberRepo;
    try {
      final item = await itemRepo.getItemWithFields(widget.itemId);
      if (item != null) {
        final relatedData = await Future.wait([
          item.memberId != null
              ? memberRepo.getMemberById(item.memberId!)
              : Future<MemberModel?>.value(null),
          item.typeKey == 'household_book'
              ? itemRepo.getChildEntries(widget.itemId)
              : Future<List<ItemChildEntryModel>>.value(const []),
        ]);
        final member = relatedData[0] as MemberModel?;
        final childEntries = relatedData[1] as List<ItemChildEntryModel>;
        if (mounted) {
          setState(() {
            _currentItem = item;
            _currentMember = member;
            _householdChildEntries = childEntries;
          });
        }
      }
    } catch (_) {
    } finally {
      _isReloading = false;
    }
  }

  void _popWithResult() {
    if (_isImportingFileAttachment || _isOpeningExternalAttachment) return;
    Navigator.of(context).pop(_isEdited);
  }

  void _showFeedbackNotice(String message) {
    AnchCenteredNotice.showSuccess(context, message);
  }

  Future<void> _updateItemPinned({
    required bool isPinned,
    required String feedback,
  }) async {
    if (_isSavingOverlayVisible || _currentItem == null) return;

    setState(() {
      _isSavingOverlayVisible = true;
    });
    final result = await DependencyProvider.of(
      context,
    ).itemUseCaseService.updateItemPinned(widget.itemId, isPinned: isPinned);
    if (!mounted) return;

    try {
      if (result.success) {
        _isEdited = true;
        await reloadItems();
        if (mounted) _showFeedbackNotice(feedback);
      } else {
        showDialog<void>(
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
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOverlayVisible = false;
        });
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    final service = DependencyProvider.of(context).itemUseCaseService;
    final navigator = Navigator.of(context);

    _hideAllSensitiveFields();
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
      builder: (BuildContext sheetContext) {
        return DeleteRecordSheet(itemId: widget.itemId, service: service);
      },
    ).then((result) {
      _hideAllSensitiveFields();
      if (result?.success == true && mounted) {
        _showFeedbackNotice('已移入最近删除');
        navigator.pop({'changed': true, 'deletedItemId': widget.itemId});
      }
    });
  }

  Future<void> _archiveCurrentItem() async {
    final item = _currentItem;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('归档资料？'),
        content: const Text('归档后资料仍会保留，可在「已归档资料」中查看和取消归档。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('归档资料'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await DependencyProvider.of(
      context,
    ).itemUseCaseService.archiveItem(item.id);
    if (!mounted) return;
    if (!result.success) {
      AnchCenteredNotice.showError(context, '归档失败，请重试');
      return;
    }
    _isEdited = true;
    await reloadItems();
    if (!mounted) return;
    AnchCenteredNotice.showSuccess(
      context,
      '资料已归档',
      actionLabel: '撤销',
      duration: const Duration(seconds: 4),
      onAction: () async {
        final undo = await DependencyProvider.of(
          context,
        ).itemUseCaseService.unarchiveItem(item.id);
        if (undo.success && mounted) {
          await reloadItems();
        }
      },
    );
  }

  Future<void> _unarchiveCurrentItem() async {
    final item = _currentItem;
    if (item == null) return;
    final result = await DependencyProvider.of(
      context,
    ).itemUseCaseService.unarchiveItem(item.id);
    if (!mounted) return;
    if (result.success) {
      _isEdited = true;
      await reloadItems();
      if (mounted) AnchCenteredNotice.showSuccess(context, '已取消归档');
    } else {
      AnchCenteredNotice.showError(context, '取消归档失败，请重试');
    }
  }

  Future<void> _renewInsurance() async {
    final source = _currentItem;
    if (source == null) return;
    final draft = InsuranceRenewalService.createDraft(source);
    final result = await ItemEntryFlowPage.open(
      context,
      initialDraft: draft,
      renewalSourceItemId: source.id,
    );
    if (!mounted || result is! String) return;
    _isEdited = true;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => ItemDetailPage(
          itemId: result,
          privacyShieldCoordinator: widget.privacyShieldCoordinator,
        ),
      ),
    );
  }

  Future<void> _dismissSheetThenOpenEditor(BuildContext sheetContext) async {
    final sheetRoute = ModalRoute.of(sheetContext);
    Navigator.of(sheetContext).pop();
    await sheetRoute?.completed;
    if (!mounted) return;
    _hideAllSensitiveFields();
    final result = await ItemEntryFlowPage.open(
      context,
      existingItemId: widget.itemId,
      initialExistingItem: _currentItem,
      initialExistingMember: _currentMember,
      initialExistingChildEntries: _householdChildEntries,
    );
    if (!mounted) return;
    _hideAllSensitiveFields();
    if (result != 'save' && result != true) return;
    _isEdited = true;
    setState(() => _isSavingOverlayVisible = true);
    await reloadItems();
    if (!mounted) return;
    setState(() => _isSavingOverlayVisible = false);
  }

  void _showItemActionsBottomSheet(BuildContext context) {
    showAnchBottomSheet<void>(
      context: context,
      builder: (sheetContext) => AnchBottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnchBottomSheetHeader(title: '资料操作'),
            AnchBottomSheetOptionGroup(
              children: [
                if (_currentItem?.status == 'active')
                  AnchBottomSheetOption(
                    icon: AnchIcons.success,
                    title: _currentItem!.isPinned ? '取消置顶' : '设为置顶',
                    onTap: () {
                      final item = _currentItem!;
                      Navigator.of(sheetContext).pop();
                      _updateItemPinned(
                        isPinned: !item.isPinned,
                        feedback: item.isPinned ? '已取消置顶' : '已设为置顶',
                      );
                    },
                  ),
                if (_currentItem?.status == 'active')
                  AnchBottomSheetOption(
                    icon: AnchIcons.archive,
                    title: '归档资料',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _archiveCurrentItem();
                    },
                  ),
                if (_currentItem?.status == 'archived')
                  AnchBottomSheetOption(
                    icon: AnchIcons.restore,
                    title: '取消归档',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _unarchiveCurrentItem();
                    },
                  ),
                if (_currentItem?.typeKey == 'insurance')
                  AnchBottomSheetOption(
                    icon: AnchIcons.restore,
                    title: '续保一份',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _renewInsurance();
                    },
                  ),
                AnchBottomSheetOption(
                  icon: AnchIcons.edit,
                  title: '编辑',
                  onTap: () => _dismissSheetThenOpenEditor(sheetContext),
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
                    _confirmDelete(context);
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

  /// 获取大类的中文标签
  String _getCategoryLabel(String categoryKey) {
    for (final cat in TemplateRegistry.getCategories()) {
      if (cat.categoryKey == categoryKey) {
        return cat.label;
      }
    }
    return categoryKey;
  }

  void _handleCopy(String fieldId) {
    if (_currentItem == null) return;
    final field = _currentItem!.fields.firstWhere(
      (f) => f.id == fieldId,
      orElse: () => throw ArgumentError('Field not found for id: $fieldId'),
    );
    final value = field.valueText ?? '';

    if (value.trim().isEmpty) return;
    _copyInteraction.copyValue(context, value);
  }

  void _confirmPrimaryCopy(ItemFieldModel field) {
    if (_currentItem == null) return;
    final value = field.valueText ?? '';
    if (value.trim().isEmpty) return;

    final typeDef = _currentItem!.typeKey != null
        ? TemplateRegistry.getTemplate(
            _currentItem!.typeKey!,
            _currentItem!.templateVersion,
          )
        : null;
    final fieldDef = TemplateRegistry.fieldDefinitionByKey(
      typeDef,
      field.fieldKey,
    );
    if (fieldDef?.sensitiveLevel == SensitiveLevel.forbidden) return;

    _copyInteraction.confirmHeaderCopy(context, value);
  }

  Widget _buildShippingAddressCopyButton(ItemWithFields item) {
    final values = <String, String?>{
      for (final field in item.fields) field.fieldKey: field.valueText,
    };
    final copyText = ShippingAddressTextBuilder.build(values);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        key: const Key('shipping_address_copy'),
        onPressed: () => _copyInteraction.copyValue(context, copyText),
        icon: const AnchIcon(AnchIcons.copy, size: 18),
        label: const Text('复制地址'),
      ),
    );
  }

  void _handleChildCopy(ItemChildFieldModel field) {
    final value = field.valueText ?? '';

    if (value.trim().isEmpty) return;
    _copyInteraction.copyValue(context, value);
  }

  Widget _buildActionTraceSection() {
    return ItemDetailActionTraceSection(
      events: DependencyProvider.of(
        context,
      ).itemEventRepo.getForItem(widget.itemId),
      isExpanded: _actionTraceExpanded,
      onExpandedChanged: (expanded) {
        setState(() => _actionTraceExpanded = expanded);
      },
    );
  }

  /// 组织并构建所有的卡片分组小部件列表
  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AnchRadius.status),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _openFileAttachment(AttachmentModel attachment) async {
    if (AttachmentPreviewPolicy.canPreviewTextInApp(attachment)) {
      _hideAllSensitiveFields();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              DecryptedDocumentPreviewPage(attachment: attachment),
        ),
      );
      _hideAllSensitiveFields();
      return;
    }

    await _confirmAndOpenAttachmentExternally(attachment);
  }

  Future<void> _confirmAndOpenAttachmentExternally(
    AttachmentModel attachment,
  ) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('使用其他应用打开？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('所选应用将读取附件内容，可能自行复制或缓存。'),
            if (AttachmentPreviewPolicy.needsLargeExternalOpenWarning(
              attachment,
            )) ...[
              const SizedBox(height: 12),
              const Text('附件较大，打开前需要准备内容。'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await _openAttachmentWithOtherApp(attachment);
    }
  }

  Future<void> _openAttachmentWithOtherApp(AttachmentModel attachment) async {
    Uint8List? bytes;
    try {
      setState(() => _isOpeningExternalAttachment = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      bytes = await AttachmentPayloadReader.readInBackground(attachment);
      await AndroidAttachmentExternalOpenService().open(
        bytes: bytes,
        mimeType: attachment.mimeType,
      );
    } on AttachmentExternalOpenException catch (error) {
      if (mounted) _showAttachmentImportError(error.message);
    } catch (_) {
      if (mounted) _showAttachmentImportError('无法使用其他应用打开附件。');
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      if (mounted) setState(() => _isOpeningExternalAttachment = false);
    }
  }

  Future<void> _pickAndAddAttachment() async {
    final existingCount = _currentItem?.attachments.length ?? 0;
    final remaining = AttachmentImportController.remainingAttachmentSlots(
      existingCount,
    );
    if (remaining == 0) {
      _showAttachmentImportError(
        '最多只能添加 ${AttachmentImportController.maxAttachmentCount} 个附件。',
      );
      return;
    }

    final di = DependencyProvider.of(context);
    final navigator = Navigator.of(context);
    final source = await showAnchBottomSheet<_AttachmentImportSource>(
      context: context,
      builder: (sheetContext) => AnchBottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnchBottomSheetHeader(
              title: '选择附件来源',
              description: '还可添加 $remaining 个附件',
            ),
            AnchBottomSheetOptionGroup(
              children: [
                AnchBottomSheetOption(
                  icon: AnchIcons.camera,
                  title: '拍照',
                  description: '直接拍摄纸质资料',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _AttachmentImportSource.camera,
                  ),
                ),
                AnchBottomSheetOption(
                  icon: AnchIcons.photoLibrary,
                  title: '从相册选择',
                  description: '推荐添加图片',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _AttachmentImportSource.gallery,
                  ),
                ),
                AnchBottomSheetOption(
                  icon: AnchIcons.attachment,
                  title: '从文件导入',
                  description: '用于 PDF、TXT 和常见文档',
                  onTap: () =>
                      Navigator.pop(sheetContext, _AttachmentImportSource.file),
                ),
              ],
            ),
            AnchBottomSheetDismissAction(
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (source == _AttachmentImportSource.gallery) {
      await _pickAndAddGalleryAttachments(navigator);
      return;
    }

    ImportedAttachment? imported;
    try {
      final controller = _fileAttachmentImportController;
      final privacyShieldController = di.privacyShieldBundle?.controller;
      if (source == _AttachmentImportSource.file) {
        _isSelectingFileAttachment = true;
      }
      imported = await switch (source) {
        _AttachmentImportSource.camera => controller.pickImage(
          navigator,
          source: ImageSource.camera,
        ),
        _AttachmentImportSource.gallery => null,
        _AttachmentImportSource.file => controller.pickFile(
          navigator: navigator,
          systemPickerGuard: privacyShieldController == null
              ? null
              : (readFile) => privacyShieldController
                    .runWhileLifecycleShieldSuppressed(readFile),
        ),
      };
    } on AttachmentImportException catch (e) {
      if (mounted) {
        _showAttachmentImportError(e.message);
      }
      return;
    } catch (_) {
      if (mounted) {
        _showAttachmentImportError('无法导入附件，请重试。');
      }
      return;
    } finally {
      _isSelectingFileAttachment = false;
    }

    if (imported == null) return;

    setState(() {
      _isSavingOverlayVisible = true;
      _isImportingFileAttachment = source == _AttachmentImportSource.file;
    });
    if (_isImportingFileAttachment) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) {
      clearAttachmentPlaintext(imported.bytes);
      return;
    }

    try {
      final persistenceService = AttachmentPersistenceService(
        getDocumentsDirectory: getApplicationDocumentsDirectory,
        saveMetadata: di.attachmentRepo.insertAttachment,
      );
      await persistenceService.save(
        itemId: widget.itemId,
        originalName: imported.originalName,
        mimeType: imported.mimeType,
        sortOrder: _currentItem?.attachments.length ?? 0,
        bytes: imported.bytes,
      );

      _isEdited = true;
      await reloadItems();
    } catch (e) {
      if (mounted) {
        showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            title: const Text(
              '添加失败',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: const Text(
              '加密或保存附件时遇到错误，请重试。',
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
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOverlayVisible = false;
          _isImportingFileAttachment = false;
        });
      }
      clearAttachmentPlaintext(imported.bytes);
    }
  }

  Future<void> _pickAndAddGalleryAttachments(NavigatorState navigator) async {
    final existingCount = _currentItem?.attachments.length ?? 0;
    final remaining = AttachmentImportController.remainingAttachmentSlots(
      existingCount,
    );
    if (remaining <= 0) {
      if (mounted) {
        _showAttachmentImportError(
          '最多只能添加 ${AttachmentImportController.maxAttachmentCount} 个附件。',
        );
      }
      return;
    }

    final controller = AttachmentImportController();
    final dependencies = DependencyProvider.of(context);
    final appLockLifecycleController =
        dependencies.appLockBundle?.appLockLifecycleController;
    final privacyShieldController =
        dependencies.privacyShieldBundle?.controller;
    List<AttachmentImageSelection> selections;
    try {
      selections = await pickAttachmentGalleryImages(
        navigator,
        limit: remaining,
        cropPickedImage: controller.cropPickedImage,
        systemPickerGuard: (pickImages) {
          Future<List<XFile>> pickWithPrivacyShield() =>
              privacyShieldController == null
              ? pickImages()
              : privacyShieldController.runWhileLifecycleShieldSuppressed(
                  pickImages,
                );
          return appLockLifecycleController == null
              ? pickWithPrivacyShield()
              : appLockLifecycleController.runWhileSystemUiLockSuppressed(
                  pickWithPrivacyShield,
                );
        },
      );
    } on AttachmentImportException catch (error) {
      if (mounted) _showAttachmentImportError(error.message);
      return;
    } catch (_) {
      if (mounted) _showAttachmentImportError('无法导入附件，请重试。');
      return;
    }
    if (!mounted || selections.isEmpty) return;

    setState(() => _isSavingOverlayVisible = true);
    var savedCount = 0;
    var failedCount = 0;
    try {
      final di = DependencyProvider.of(context);
      final persistenceService = AttachmentPersistenceService(
        getDocumentsDirectory: getApplicationDocumentsDirectory,
        saveMetadata: di.attachmentRepo.insertAttachment,
      );
      for (final selection in selections) {
        ImportedAttachment? imported;
        try {
          imported = await controller.importImageSelection(selection);
          if (imported == null) {
            failedCount++;
            continue;
          }
          await persistenceService.save(
            itemId: widget.itemId,
            originalName: imported.originalName,
            mimeType: imported.mimeType,
            sortOrder: existingCount + savedCount,
            bytes: imported.bytes,
          );
          savedCount++;
        } catch (_) {
          failedCount++;
        } finally {
          if (imported != null) clearAttachmentPlaintext(imported.bytes);
        }
      }
      if (savedCount > 0) {
        _isEdited = true;
        await reloadItems();
      }
    } finally {
      if (mounted) setState(() => _isSavingOverlayVisible = false);
    }

    if (mounted && failedCount > 0) {
      showDialog<void>(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text(
            '添加附件失败',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            '有 $failedCount 张附件添加失败，请重试。',
            style: const TextStyle(fontSize: 13),
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

  void _showAttachmentImportError(String message) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '提示',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ScreenProtectionScope(
    child: Stack(
      children: [
        _buildPage(context),
        if (_isImportingFileAttachment)
          const AnchBlockingProgressOverlay(
            title: '正在导入附件',
            message: '正在加密并保存附件，请保持应用在前台',
            progress: null,
            semanticsLabel: '正在导入附件，请勿退出',
            barrierKey: ValueKey('detail_attachment_import_loading_barrier'),
          ),
        if (_isOpeningExternalAttachment)
          const AnchBlockingProgressOverlay(
            title: '正在准备附件',
            message: '正在解密附件，请保持应用在前台',
            progress: null,
            semanticsLabel: '正在准备附件，请勿退出',
            barrierKey: ValueKey(
              'detail_attachment_external_open_loading_barrier',
            ),
          ),
      ],
    ),
  );

  Widget _buildPage(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.anchColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: context.anchColors.accentDeep,
          ),
        ),
      );
    }
    if (_loadingError != null) {
      return Scaffold(
        backgroundColor: context.anchColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 48,
          titleSpacing: 0,
          leading: AnchRouteBack(
            color: context.anchColors.textPrimary,
            onBack: _popWithResult,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnchIcon(
                  AnchIcons.error,
                  size: 48,
                  color: context.anchColors.danger,
                ),
                const SizedBox(height: AnchSpacing.md),
                Text(
                  '资料加载失败',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.anchColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AnchSpacing.sm),
                Text(
                  _loadingError!,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.anchColors.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AnchSpacing.xl),
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.anchColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AnchRadius.md),
                      ),
                    ),
                    onPressed: _popWithResult,
                    child: Text(
                      '返回',
                      style: TextStyle(color: context.anchColors.accentInk),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final item = _currentItem!;
    final member = _currentMember;
    final typeDef = item.typeKey != null
        ? TemplateRegistry.getTemplate(item.typeKey!, item.templateVersion)
        : null;

    final typeLabel = typeDef?.label ?? item.typeKey ?? '资料';
    final isGeneric = item.typeKey == 'generic' || typeDef == null;
    final typeTagText = isGeneric
        ? _getCategoryLabel(item.categoryKey ?? '')
        : typeLabel;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isImportingFileAttachment || _isOpeningExternalAttachment) return;
        _popWithResult();
      },
      child: AnchAppScaffold(
        maxContentWidth: 640,
        appBar: AppBar(
          systemOverlayStyle:
              (Theme.of(context).brightness == Brightness.dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness:
                        Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
                    statusBarBrightness:
                        Theme.of(context).brightness == Brightness.dark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 48,
          titleSpacing: 0,
          leading: AnchRouteBack(
            color: context.anchColors.textPrimary,
            onBack: _popWithResult,
          ),
          title: Text(typeTagText),
          actions: [
            AnchHeaderAction(
              key: const Key('detail_more_action'),
              icon: AnchIcons.more,
              color: context.anchColors.textSecondary,
              semanticLabel: '更多操作',
              onTap: () {
                _showItemActionsBottomSheet(context);
              },
            ),
            AnchHeaderAction(
              key: const Key('detail_home_action'),
              icon: AnchIcons.home,
              color: context.anchColors.textSecondary,
              semanticLabel: '回到首页',
              onTap: () {
                final navigator = Navigator.of(context);
                DependencyProvider.of(context).mainShellController.goHome();
                navigator.popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (RuntimeScope.of(context).isDevMode)
                  const AnchSecurityBanner(
                    message: AnchSecurityBanner.devModeMessage,
                    type: AnchBannerType.warning,
                  ),
                const SizedBox(height: AnchSpacing.xs),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AnchSpacing.page,
                      AnchSpacing.xs,
                      AnchSpacing.page,
                      AnchSpacing.md,
                    ),
                    child: Column(
                      children: [
                        // 1. Header Section (Title + Tags)
                        (() {
                          final ownerName = member?.name ?? '未知';
                          final displayTitle =
                              TitleSummaryBuilder.buildDetailTitle(
                                item: item,
                                typeLabel:
                                    typeDef?.label ?? item.typeKey ?? '资料',
                                ownerName: member?.name ?? '未知',
                              );
                          final isClosedCreditCard =
                              item.typeKey == 'credit_card' &&
                              ItemExpiryStatusPolicy.isBankCardClosed(
                                typeKey: item.typeKey,
                                rawState: item.rawState,
                                primaryText: item.primaryText,
                              );

                          // Expiry status tag
                          Widget? expiryTag;
                          if (!isClosedCreditCard &&
                              ItemExpiryStatusPolicy.supportsType(
                                item.typeKey,
                                templateVersion: item.templateVersion,
                              )) {
                            final now = DependencyProvider.of(
                              context,
                            ).timeDomainSource.now();
                            final result = ItemExpiryStatusPolicy.calculate(
                              typeKey: item.typeKey,
                              templateVersion: item.templateVersion,
                              rawState: item.rawState,
                              primaryText: item.primaryText,
                              now: now,
                            );
                            if (result.status == ItemExpiryStatus.expired) {
                              expiryTag = _buildTag(
                                '已过期',
                                context.anchColors.dangerSoft,
                                context.anchColors.danger,
                              );
                            } else if (result.status ==
                                ItemExpiryStatus.today) {
                              expiryTag = _buildTag(
                                '今日到期',
                                context.anchColors.dangerSoft,
                                context.anchColors.danger,
                              );
                            } else if (result.status ==
                                ItemExpiryStatus.upcoming) {
                              expiryTag = _buildTag(
                                result.daysUntilExpiry != null
                                    ? '${result.daysUntilExpiry}天后到期'
                                    : '即将到期',
                                context.anchColors.warningSoft,
                                context.anchColors.warning,
                              );
                            }
                          }

                          return ItemDetailHeaderSection(
                            title: displayTitle,
                            icon: AnchIcons.forTypeKey(item.typeKey),
                            tags: [
                              Text(
                                '归属 · $ownerName',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.anchColors.textSecondary,
                                ),
                              ),
                              ?expiryTag,
                              if (isClosedCreditCard) ...[
                                _buildTag(
                                  '已注销',
                                  context.anchColors.dangerSoft,
                                  context.anchColors.danger,
                                ),
                              ],
                            ],
                          );
                        })(),

                        if (item.typeKey == 'shipping_address') ...[
                          _buildShippingAddressCopyButton(item),
                          const SizedBox(height: AnchSpacing.sectionGap),
                        ],

                        ItemDetailFieldsSection(
                          item: item,
                          typeDef: typeDef,
                          childEntries: _householdChildEntries,
                          revealedFieldKeys: _revealedFieldKeys,
                          revealedChildFieldIds: _revealedChildFieldIds,
                          onCopy: _handleCopy,
                          onChildCopy: _handleChildCopy,
                          onReveal: (key, reveal) {
                            setState(
                              () => reveal
                                  ? _revealedFieldKeys.add(key)
                                  : _revealedFieldKeys.remove(key),
                            );
                            _updatePrivacyShield();
                          },
                          onRevealChild: (key, reveal) {
                            setState(
                              () => reveal
                                  ? _revealedChildFieldIds.add(key)
                                  : _revealedChildFieldIds.remove(key),
                            );
                            _updatePrivacyShield();
                          },
                          onCopyPrimary: (field) {
                            if (item.typeKey == 'debit_card') {
                              _copyInteraction.showDebitCardCopyMenu(
                                context,
                                item,
                              );
                            } else if (item.typeKey == 'credit_card') {
                              _copyInteraction.showCreditCardCopyMenu(
                                context,
                                item,
                              );
                            } else {
                              _confirmPrimaryCopy(field);
                            }
                          },
                        ),

                        if (item.note?.trim().isNotEmpty ?? false) ...[
                          ItemDetailNoteSection(item: item),
                          const SizedBox(height: AnchSpacing.lg),
                        ],
                        ItemDetailAttachmentsSection(
                          attachments: item.attachments,
                          showAddAttachment:
                              AttachmentImportController.remainingAttachmentSlots(
                                item.attachments.length,
                              ) >
                              0,
                          onAddAttachment: _pickAndAddAttachment,
                          onPreviewImages: (attachments, initialIndex) async {
                            _hideAllSensitiveFields();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DecryptedImagePreviewPage(
                                  attachments: attachments,
                                  initialIndex: initialIndex,
                                ),
                              ),
                            );
                            _hideAllSensitiveFields();
                          },
                          onOpenFileAttachment: _openFileAttachment,
                        ),

                        _buildActionTraceSection(),
                        const SizedBox(height: AnchSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isSavingOverlayVisible && !_isImportingFileAttachment)
              Positioned.fill(
                child: Container(
                  color: context.anchColors.background.withValues(alpha: 0.62),
                  alignment: Alignment.center,
                  child: Material(
                    color: context.anchColors.surface,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AnchRadius.md),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AnchSpacing.lg,
                        vertical: AnchSpacing.md,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.anchColors.accentDeep,
                            ),
                          ),
                          SizedBox(width: AnchSpacing.sm),
                          Text(
                            '正在保存',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.anchColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
}

class DeleteRecordSheet extends StatefulWidget {
  final String itemId;
  final ItemUseCaseService service;

  const DeleteRecordSheet({
    super.key,
    required this.itemId,
    required this.service,
  });

  @override
  State<DeleteRecordSheet> createState() => _DeleteRecordSheetState();
}

class _DeleteRecordSheetState extends State<DeleteRecordSheet> {
  // 状态机变量：confirm (默认二次确认) -> loading (正在删除) -> error (报错)
  String _state = 'confirm';
  String? _error;

  void _onConfirmDelete() async {
    setState(() {
      _state = 'loading';
    });
    try {
      final result = await widget.service.deleteItem(widget.itemId);
      if (!result.success) {
        throw result.error ?? Exception('delete failed');
      }
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = 'error';
          _error = e.toString();
        });
      }
    }
  }

  Widget _scrollableSheet(Widget child) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: child,
      ),
    );
  }

  Widget _confirmationActions(BuildContext context) {
    final cancelButton = OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: context.anchColors.borderStrong),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnchRadius.md),
        ),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: Text(
        '取消',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.anchColors.textMuted,
        ),
      ),
    );
    final deleteButton = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: context.anchColors.danger,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnchRadius.md),
        ),
        elevation: 0,
      ),
      onPressed: _onConfirmDelete,
      child: Text(
        '移入最近删除',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useStackedActions =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        if (useStackedActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              deleteButton,
              const SizedBox(height: AnchSpacing.sm),
              cancelButton,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: cancelButton),
            const SizedBox(width: AnchSpacing.md),
            Expanded(child: deleteButton),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state == 'loading') {
      return _scrollableSheet(
        SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: context.anchColors.accentDeep),
                const SizedBox(height: AnchSpacing.md),
                Text(
                  '正在删除资料...',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.anchColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_state == 'error') {
      return _scrollableSheet(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
            vertical: AnchSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnchIcon(
                AnchIcons.error,
                size: 36,
                color: context.anchColors.danger,
              ),
              const SizedBox(height: AnchSpacing.md),
              Text(
                '删除失败: $_error',
                style: TextStyle(
                  fontSize: 14,
                  color: context.anchColors.danger,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AnchSpacing.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.anchColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AnchRadius.md),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  '关闭',
                  style: TextStyle(color: context.anchColors.accentInk),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default 'confirm' state
    return _scrollableSheet(
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AnchSpacing.page,
          vertical: AnchSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '移入最近删除？',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.anchColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AnchSpacing.md),
            Text(
              '资料将从当前列表移除，可在「数据与备份－最近删除」中恢复。',
              style: TextStyle(
                fontSize: 13,
                color: context.anchColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AnchSpacing.xl),
            _confirmationActions(context),
          ],
        ),
      ),
    );
  }
}
