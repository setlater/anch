import 'dart:async';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/dependency_provider.dart';
import '../../core/repository/models/member_model.dart';
import '../../core/repository/models/item_child_entry_model.dart';
import '../../core/repository/models/item_with_fields.dart';
import '../../core/template/type_definition.dart';
import '../../core/template/field_definition.dart';
import '../../core/template/field_priority.dart';
import '../../core/template/field_value_type.dart';
import '../../core/template/template_registry.dart';
import '../../core/service/models/item_draft_input.dart';
import '../../core/service/shipping_address_parser.dart';
import '../../core/service/policy/item_expiry_status_policy.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_motion.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_adaptive_layout.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_bottom_action_bar.dart';
import '../../core/widgets/anch_bottom_sheet.dart';
import '../../core/widgets/anch_blocking_progress_overlay.dart';
import '../../core/widgets/anch_choice_card.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_member_avatar.dart';
import '../../core/widgets/anch_page_header.dart';
import '../member/member_form_sheet.dart';
import '../privacy/screen_protection_scope.dart';
import '../item_detail/attachment_import_controller.dart';
import '../item_detail/attachment_image_gallery_selection.dart';
import '../../core/widgets/anch_section_header.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import '../../core/widgets/anch_step_indicator.dart';
import '../../core/widgets/anch_centered_notice.dart';
import '../../core/service/validation/template_validator.dart';
import 'utils/field_formatters.dart';
import '../../core/security/field_render_policy.dart';
import '../../core/attachment/attachment_model.dart';
import '../../core/attachment/attachment_encrypted_file_writer.dart';
import '../../core/attachment/save_attachment_input.dart';
import 'controllers/item_entry_flow_controller.dart';
import 'controllers/item_entry_attachment_draft_controller.dart';
import 'controllers/item_entry_flow_state.dart';
import 'utils/key_registry.dart';
import 'household_member_draft.dart';
import 'household_member_editor_section.dart';
import 'item_entry_field_error.dart';
import 'item_entry_field_input_section.dart';
import 'item_entry_field_label.dart';
import 'item_entry_text_field.dart';
import 'item_entry_supplement_section.dart';

enum _EntryAttachmentImportSource { camera, gallery, file }

class _ExistingItemLoadData {
  const _ExistingItemLoadData({
    required this.item,
    required this.member,
    required this.childEntries,
  });

  final ItemWithFields item;
  final MemberModel? member;
  final List<ItemChildEntryModel> childEntries;
}

/// 安册资料录入分页流程页。
///
/// 统一按类型、归属、核心字段、补充信息录入；成员入口跳过归属步骤。
/// 编辑保留原模板版本，保存经由 ItemUseCaseService 完成校验。
class ItemEntryFlowPage extends StatefulWidget {
  final String? existingItemId;
  final ItemWithFields? initialExistingItem;
  final MemberModel? initialExistingMember;
  final List<ItemChildEntryModel> initialExistingChildEntries;
  final String? initialMemberId;
  final ItemEntryFlowController? controller;
  final ItemDraftInput? initialDraft;
  final String? renewalSourceItemId;

  const ItemEntryFlowPage({
    super.key,
    this.controller,
    this.existingItemId,
    this.initialExistingItem,
    this.initialExistingMember,
    this.initialExistingChildEntries = const [],
    this.initialMemberId,
    this.initialDraft,
    this.renewalSourceItemId,
  }) : assert(
         existingItemId == null ||
             (initialMemberId == null && initialDraft == null),
         '编辑资料时不能指定初始成员或初始草稿',
       ),
       assert(
         initialExistingItem == null || existingItemId != null,
         '编辑资料快照只能用于编辑模式',
       ),
       assert(initialDraft == null || existingItemId == null, '初始草稿只能用于新建资料');

  static Future<dynamic> open(
    BuildContext context, {
    String? existingItemId,
    ItemWithFields? initialExistingItem,
    MemberModel? initialExistingMember,
    List<ItemChildEntryModel> initialExistingChildEntries = const [],
    String? initialMemberId,
    ItemDraftInput? initialDraft,
    String? renewalSourceItemId,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemEntryFlowPage(
          existingItemId: existingItemId,
          initialExistingItem: initialExistingItem,
          initialExistingMember: initialExistingMember,
          initialExistingChildEntries: initialExistingChildEntries,
          initialMemberId: initialMemberId,
          initialDraft: initialDraft,
          renewalSourceItemId: renewalSourceItemId,
        ),
      ),
    );
  }

  @override
  State<ItemEntryFlowPage> createState() => _ItemEntryFlowPageState();
}

class _ItemEntryFlowPageState extends State<ItemEntryFlowPage>
    with WidgetsBindingObserver {
  static const double _normalScrollBottomPadding = AnchSpacing.xxl;
  static const int _genericCustomFieldLabelMaxLength = 32;
  static const int _genericCustomFieldValueMaxLength = 4000;

  bool get _isKeyboardVisible {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  bool get _isMemberScopedEntry =>
      widget.existingItemId == null && widget.initialMemberId != null;

  double get _scrollBottomPadding {
    return _isKeyboardVisible ? AnchSpacing.md : _normalScrollBottomPadding;
  }

  void _executeStep2PrimaryAction() {
    if (_selectedMember == null || _selectedType == null) {
      return;
    }

    if (!_validateRequiredFields()) {
      return;
    }

    // 组装当前表单字段
    final draftFields = _buildDraftFields();

    final draft = ItemDraftInput(
      memberId: _selectedMember!.id,
      categoryKey: _selectedType!.categoryKey,
      typeKey: _selectedType!.typeKey,
      templateVersion: _selectedType!.version,
      fields: draftFields,
    );

    // 调用已有的校验器（仅用于提取诊断警告，不阻断流程）
    final validationResult = TemplateValidator.validate(draft);
    final errors = validationResult.errors;

    // 过滤只属于当前 Step 2 已展示字段对应的错误
    final currentFieldKeys = _selectedType!.fields
        .map((f) => f.fieldKey)
        .toSet();
    final relevantErrors = errors
        .where(
          (error) =>
              error.fieldKey == null ||
              error.fieldKey!.isEmpty ||
              currentFieldKeys.contains(error.fieldKey),
        )
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fieldErrors.clear();
        _globalError = null;
        for (final error in relevantErrors) {
          if (error.fieldKey != null && error.fieldKey!.isNotEmpty) {
            _fieldErrors[error.fieldKey!] = error.errorMessage;
            final optionalFields = _selectedType!.fields.where(
              (f) => !f.required && f.priority != FieldPriority.p0,
            );
            final isOptional = optionalFields.any(
              (f) => f.fieldKey == error.fieldKey,
            );
            if (isOptional) {
              _showOptionalFields = true;
            }
          } else {
            _globalError = error.errorMessage;
          }
        }
        // 总是允许进入下一步，不阻断流程
        _syncUIToState();
        _controller!.nextStep();
      });
    });
  }

  String _mapErrorText(
    String fieldLabel,
    String rawErrorText,
    FieldValueType valueType,
  ) {
    final error = rawErrorText.trim();
    if (error.contains('请填写') && error.contains('或')) {
      return error;
    }
    if (valueType == FieldValueType.date ||
        error.contains('日期') ||
        error.contains('YYYY-MM-DD') ||
        error.contains('非法')) {
      return '请选择有效的$fieldLabel';
    }
    if (error.contains('是必填项') ||
        error.contains('当前未提供') ||
        error.contains('内容为空')) {
      return '请输入$fieldLabel';
    }
    if (error.contains('长度') ||
        error.contains('12 到 19 位') ||
        error.contains('15 位或 18 位')) {
      return '$fieldLabel长度不正确';
    }
    if (error.contains('格式') ||
        error.contains('不合规') ||
        error.contains('规则') ||
        error.contains('规范') ||
        error.contains('符合')) {
      return '$fieldLabel格式不正确';
    }
    return error;
  }

  Widget _buildAnimatedError(String? errorText, FieldDefinition field) {
    return ItemEntryFieldError(
      message: errorText == null
          ? null
          : _mapErrorText(field.label, errorText, field.valueType),
      fieldKey: field.fieldKey,
    );
  }

  ItemEntryFlowController? _controller;
  ItemEntryFlowController get flowController => _controller!;
  bool _isInitialized = false;
  bool _initializationScheduled = false;
  Animation<double>? _initializationAnimation;
  AnimationStatusListener? _initializationStatusListener;

  // ─── 录入边界与退出守卫 ──────────────────────────────
  /// 本页面打开时的入口步骤索引（0-based）。
  /// 新增模式在 _isInitialized 块内赋值（同步）。
  /// 编辑模式在 _loadExistingItem 成功回调内赋值（异步）。
  /// late final 保证只赋值一次；加载失败路径不赋值也不读取。
  late final int _entryStepIndex;

  /// 退出确认弹窗防重叠守卫
  bool _isExitDialogShowing = false;

  /// 仅由用户主动修改资料内容时置位；类型和归属选择不视为待放弃内容。
  bool _hasPendingUserChanges = false;

  // Getters derived from the controller state as the single source of truth
  ItemEntryStep get _currentStep => _controller!.value.currentStep;
  MemberModel? get _selectedMember => _controller!.value.selectedOwner;
  TypeDefinition? get _selectedType => _controller!.value.selectedType != null
      ? TemplateRegistry.getTemplate(
          _controller!.value.selectedType!.typeKey,
          _controller!.value.selectedTemplateVersion,
        )
      : null;

  // ─── 编辑加载状态 ────────────────────────────────────────
  bool _isLoadingEditItem = false;
  bool _initialDataLoadsScheduled = false;
  bool _initialDataLoadsConsumed = false;
  Future<List<MemberModel>?>? _initialMembersFuture;
  _ExistingItemLoadData? _initialExistingItemData;
  Future<({_ExistingItemLoadData? data, bool failed})>?
  _initialExistingItemFuture;

  // ─── Step 0: 成员选择 ───────────────────────────────────
  bool _isLoadingMembers = true;
  bool _membersLoadFailed = false;
  List<MemberModel> _members = [];

  // ─── Step 2: 字段填写 ───────────────────────────────────
  /// 普通文本字段控制器（fieldKey → controller）
  final Map<String, TextEditingController> _controllers = {};

  /// 缓存的 FocusNode，按 fieldKey 索引以保持 FocusNode 稳定
  final Map<String, FocusNode> _focusNodes = {};

  FocusNode _getFocusNode(String fieldKey) {
    return _focusNodes.putIfAbsent(fieldKey, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          _lastFocusedFieldKey = fieldKey;
        }
      });
      return node;
    });
  }

  /// 记录上一次获得焦点的字段 key，用于在键盘收起时重新 ensureVisible
  String? _lastFocusedFieldKey;

  /// 记录上一次键盘的可见状态，用以检测键盘收起时机
  bool _wasKeyboardVisible = false;

  /// 统一的字段输入避让间距，给键盘和底部操作栏留出语义高度
  static const EdgeInsets _fieldScrollPadding = EdgeInsets.only(bottom: 140.0);

  /// boolean 字段状态（fieldKey → bool）
  final Map<String, bool> _boolFields = {};

  /// 身份证有效期结束实际输入值缓存
  String _actualValidUntil = '';

  /// 字段级错误（fieldKey → 错误文案）
  final Map<String, String> _fieldErrors = {};

  /// 「其他资料」V2 当前展示的自定义字段组数量。
  int get _genericCustomFieldCount =>
      _controller?.value.genericCustomFieldCount ?? 1;
  bool _skipGenericFieldDeleteConfirmation = false;

  /// 缓存的 GlobalKey，按 fieldKey 索引以保持 Key 稳定
  final Map<String, GlobalKey> _fieldKeys = {};

  GlobalKey _getFieldKey(String fieldKey) {
    return _fieldKeys.putIfAbsent(fieldKey, () => GlobalKey());
  }

  /// 全局保存错误
  String? _globalError;

  /// 是否展示补充信息（折叠区）
  bool _showOptionalFields = false;

  /// 当前所选成员唯一活跃身份证中可复用的基础字段；只在录入时短暂保留。
  Map<String, String>? _identityProfileFields;
  int _identityProfileRequest = 0;

  /// 字段联动引擎

  // ─── Step 3: 补充信息 ────────────────────────────────────
  /// 备注（对应 ItemDraftInput 中的 note 字段）
  final TextEditingController _noteController = TextEditingController();

  late final String _itemId = widget.existingItemId ?? _generateUuid();
  bool _isPinned = false;
  int? _pinnedAt;
  String _itemStatus = 'active';
  late final ItemEntryAttachmentDraftController _attachmentDraftController;
  final AttachmentImportController _fileAttachmentImportController =
      AttachmentImportController();
  List<AttachmentModel> _attachmentsDraft = [];
  bool _isFileAttachmentImporting = false;
  bool _isSelectingFileAttachment = false;
  final Set<String> _existingAttachmentFileNames = <String>{};
  List<HouseholdMemberDraft> _householdMembersDraft = [];

  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant RFC4122

    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<void> _deleteAttachmentDraft(AttachmentModel att) async {
    await _attachmentDraftController.delete(
      att,
      deletePhysicalFile: !_existingAttachmentFileNames.contains(att.fileName),
    );

    setState(() {
      _attachmentsDraft.removeWhere((a) => a.id == att.id);
      _hasPendingUserChanges = true;
    });
  }

  Future<void> _discardNewAttachmentDrafts() async {
    final newAttachments = _attachmentsDraft
        .where(
          (attachment) =>
              !_existingAttachmentFileNames.contains(attachment.fileName),
        )
        .toList(growable: false);
    for (final attachment in newAttachments) {
      await _attachmentDraftController.delete(
        attachment,
        deletePhysicalFile: true,
      );
    }
  }

  Future<void> _pickAttachment(String role) async {
    final remaining = AttachmentImportController.remainingAttachmentSlots(
      _attachmentsDraft.length,
    );
    if (remaining == 0) return;

    final source = await showAnchBottomSheet<_EntryAttachmentImportSource>(
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
                    _EntryAttachmentImportSource.camera,
                  ),
                ),
                AnchBottomSheetOption(
                  icon: AnchIcons.photoLibrary,
                  title: '从相册选择',
                  description: '推荐添加图片',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _EntryAttachmentImportSource.gallery,
                  ),
                ),
                AnchBottomSheetOption(
                  icon: AnchIcons.attachment,
                  title: '从文件导入',
                  description: '用于 PDF、TXT 和常见文档',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _EntryAttachmentImportSource.file,
                  ),
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

    if (_attachmentsDraft.length >=
        AttachmentImportController.maxAttachmentCount) {
      if (mounted) {
        showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            title: const Text('提示'),
            content: Text(
              '最多只能添加 ${AttachmentImportController.maxAttachmentCount} 个附件。',
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
      return;
    }

    if (source == _EntryAttachmentImportSource.file) {
      await _pickFileAttachment(role);
      return;
    }

    final picker = ImagePicker();

    if (source == _EntryAttachmentImportSource.camera) {
      // 拍照：单张
      try {
        final pickedFile = await picker.pickImage(source: ImageSource.camera);
        if (pickedFile == null) return;
        await _processAndAddAttachment(pickedFile, role);
      } catch (e) {
        if (mounted) {
          showDialog<void>(
            context: context,
            useRootNavigator: false,
            builder: (context) => AlertDialog(
              title: const Text(
                '拍照失败',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: const Text(
                '无法使用相机拍照，请重试。',
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
    } else {
      // 相册多选：最多 12 张（受当前已有数量限制）
      final remaining = AttachmentImportController.remainingAttachmentSlots(
        _attachmentsDraft.length,
      );
      if (remaining <= 0) {
        if (mounted) {
          showDialog<void>(
            context: context,
            useRootNavigator: false,
            builder: (context) => AlertDialog(
              title: const Text(
                '提示',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Text(
                '最多只能添加 ${AttachmentImportController.maxAttachmentCount} 张附件。',
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
        return;
      }

      try {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        final attachmentController = AttachmentImportController();
        final dependencies = DependencyProvider.of(context);
        final appLockLifecycleController =
            dependencies.appLockBundle?.appLockLifecycleController;
        final privacyShieldController =
            dependencies.privacyShieldBundle?.controller;
        final images = await pickAttachmentGalleryImages(
          navigator,
          limit: remaining,
          cropPickedImage: attachmentController.cropPickedImage,
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
        if (!mounted || images.isEmpty) return;

        int failed = 0;
        for (final image in images) {
          try {
            final file = image.wasCropped
                ? image.file
                : await attachmentController.prepareUncroppedImage(image.file);
            await _addAttachmentDraft(file, role);
          } catch (_) {
            failed++;
          }
        }

        if (mounted && failed > 0) {
          showDialog<void>(
            context: context,
            useRootNavigator: false,
            builder: (context) => AlertDialog(
              title: const Text(
                '添加附件失败',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Text(
                '有 $failed 张附件添加失败，请重试。',
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
      } on AttachmentImportException catch (error) {
        if (mounted) _showAttachmentImportError(error.message);
      } catch (_) {
        if (mounted) {
          showDialog<void>(
            context: context,
            useRootNavigator: false,
            builder: (context) => AlertDialog(
              title: const Text(
                '添加附件失败',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: const Text(
                '选择图片时遇到错误，请重试。',
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
    }
  }

  Future<void> _pickFileAttachment(String role) async {
    ImportedAttachment? imported;
    try {
      final privacyShieldController = DependencyProvider.of(
        context,
      ).privacyShieldBundle?.controller;
      _isSelectingFileAttachment = true;
      imported = await _fileAttachmentImportController.pickFile(
        navigator: Navigator.of(context),
        systemPickerGuard: privacyShieldController == null
            ? null
            : (readFile) => privacyShieldController
                  .runWhileLifecycleShieldSuppressed(readFile),
      );
      if (imported == null) return;
      if (!mounted) return;
      setState(() => _isFileAttachmentImporting = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final attachment = await _attachmentDraftController.createFromBytes(
        bytes: imported.bytes,
        originalName: imported.originalName,
        mimeType: imported.mimeType,
        itemId: _itemId,
        role: role,
        sortOrder: _attachmentsDraft.length,
      );
      if (mounted) {
        setState(() {
          _attachmentsDraft.add(attachment);
          _hasPendingUserChanges = true;
        });
      }
    } on AttachmentImportException catch (error) {
      if (mounted) _showAttachmentImportError(error.message);
    } catch (_) {
      if (mounted) _showAttachmentImportError('无法导入附件，请重试。');
    } finally {
      _isSelectingFileAttachment = false;
      if (mounted && _isFileAttachmentImporting) {
        setState(() => _isFileAttachmentImporting = false);
      }
      if (imported != null) clearAttachmentPlaintext(imported.bytes);
    }
  }

  void _showAttachmentImportError(String message) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 对单张拍照图片进行裁剪后追加到草稿列表。
  Future<void> _processAndAddAttachment(XFile pickedFile, String role) async {
    final navigator = Navigator.of(context);
    final croppedFile = await AttachmentImportController().cropPickedImage(
      navigator,
      pickedFile,
    );
    if (croppedFile == null) return;

    await _addAttachmentDraft(croppedFile, role);
  }

  /// 将已裁剪或已标准化的图片加密暂存到录入草稿。
  Future<void> _addAttachmentDraft(XFile pickedFile, String role) async {
    final newAtt = await _attachmentDraftController.createFromPickedImage(
      pickedFile: pickedFile,
      itemId: _itemId,
      role: role,
      sortOrder: _attachmentsDraft.length,
    );

    if (mounted) {
      setState(() {
        _attachmentsDraft.add(newAtt);
        _hasPendingUserChanges = true;
      });
    }
  }

  // ─── 保存状态 ────────────────────────────────────────────
  bool _isSaving = false;

  // ─── 步骤配置 ────────────────────────────────────────────
  int get _totalSteps {
    return _isMemberScopedEntry ? 3 : 4;
  }

  int _visibleStepIndex(ItemEntryStep step) {
    if (_isMemberScopedEntry) {
      switch (step) {
        case ItemEntryStep.type:
        case ItemEntryStep.owner:
          return 0;
        case ItemEntryStep.editableReview:
          return 1;
        case ItemEntryStep.supplement:
          return 2;
      }
    }
    return step.index;
  }

  bool _hasInitializedEditMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInitialDataLoads();
    _scheduleInitialization();
  }

  void _scheduleInitialization() {
    if (_initializationScheduled) return;
    _initializationScheduled = true;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _initializeAfterTransition();
      return;
    }

    _initializationAnimation = animation;
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      _initializationStatusListener = null;
      _initializationAnimation = null;
      if (mounted) _initializeAfterTransition();
    };
    _initializationStatusListener = listener;
    animation.addStatusListener(listener);
  }

  void _initializeAfterTransition() {
    if (!mounted || _isInitialized) return;
    _isInitialized = true;
    _attachmentDraftController = ItemEntryAttachmentDraftController(
      getDocumentsDirectory: getApplicationDocumentsDirectory,
      createId: _generateUuid,
    );
    final di = DependencyProvider.of(context);
    final runtime = RuntimeScope.of(context);
    _controller =
        widget.controller ??
        di.createEntryFlowController(
          enableAutoFillScaffold: runtime.config.enableAutoFillScaffold,
        );
    _controller!.addListener(_onControllerStateChanged);
    _syncStateToUI();
    if (widget.existingItemId == null) {
      _entryStepIndex = _isMemberScopedEntry
          ? 0
          : _controller!.value.currentStep.index;
    } else if (!_hasInitializedEditMode) {
      _hasInitializedEditMode = true;
      _isLoadingEditItem = true;
    }
    _consumeInitialDataLoads();
    if (widget.existingItemId == null || _isLoadingEditItem) {
      setState(() {});
    }
  }

  /// 查询与路由转场并行，只在转场结束并初始化控制器后提交结果。
  void _scheduleInitialDataLoads() {
    if (_initialDataLoadsScheduled) return;
    _initialDataLoadsScheduled = true;
    final di = DependencyProvider.of(context);
    _initialMembersFuture = di.memberRepo
        .getActiveMembers()
        .then<List<MemberModel>?>((members) => members, onError: (_) => null);
    final existingItemId = widget.existingItemId;
    if (existingItemId != null) {
      final initialItem = widget.initialExistingItem;
      if (initialItem != null && initialItem.id == existingItemId) {
        _initialExistingItemData = _ExistingItemLoadData(
          item: initialItem,
          member: widget.initialExistingMember,
          childEntries: widget.initialExistingChildEntries,
        );
      } else {
        _initialExistingItemFuture = _fetchExistingItem(existingItemId);
      }
    }
  }

  void _consumeInitialDataLoads() {
    if (_initialDataLoadsConsumed) return;
    _initialDataLoadsConsumed = true;
    final membersFuture = _initialMembersFuture;
    if (membersFuture != null) _consumeInitialMembers(membersFuture);
    final existingData = _initialExistingItemData;
    if (existingData != null) {
      _applyExistingItem(existingData);
      return;
    }
    final existingFuture = _initialExistingItemFuture;
    if (existingFuture != null) {
      _consumeInitialExistingItem(existingFuture);
    } else if (widget.initialDraft != null) {
      _loadInitialDraft(widget.initialDraft!);
    }
  }

  Future<void> _consumeInitialMembers(
    Future<List<MemberModel>?> membersFuture,
  ) async {
    final members = await membersFuture;
    if (!mounted) return;
    if (members == null) {
      setState(() {
        _isLoadingMembers = false;
        _membersLoadFailed = true;
      });
      return;
    }
    _applyInitialMembers(members);
  }

  Future<void> _consumeInitialExistingItem(
    Future<({_ExistingItemLoadData? data, bool failed})> existingFuture,
  ) async {
    try {
      final result = await existingFuture;
      if (!mounted) return;
      final data = result.data;
      if (result.failed || data == null) {
        setState(() {
          _globalError = result.failed ? '加载编辑资料失败' : '未找到需要编辑的资料';
          _isLoadingEditItem = false;
        });
        return;
      }
      _applyExistingItem(data);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _globalError = '加载编辑资料失败';
        _isLoadingEditItem = false;
      });
    }
  }

  Future<void> _retryExistingItem() async {
    if (!mounted || _isLoadingEditItem) return;
    setState(() {
      _isLoadingEditItem = true;
      _globalError = null;
    });
    await _consumeInitialExistingItem(
      _fetchExistingItem(widget.existingItemId!),
    );
  }

  Future<void> _loadInitialDraft(ItemDraftInput draft) async {
    final typeKey = draft.typeKey;
    if (typeKey == null) return;
    final type = TemplateRegistry.getTemplate(typeKey, draft.templateVersion);
    if (type == null) return;
    final member = draft.memberId == null
        ? null
        : await DependencyProvider.of(
            context,
          ).memberRepo.getMemberById(draft.memberId!);
    if (!mounted) return;
    _controller!.selectType(type, templateVersion: draft.templateVersion);
    if (member != null) _controller!.selectOwner(member);
    _controller!.setFieldValues({
      for (final field in draft.fields)
        field.fieldKey: field.valueText?.trim() ?? '',
    });
    _controller!.setStepEnum(ItemEntryStep.editableReview);
    _syncStateToUI();
    setState(() {});
  }

  void _onControllerStateChanged() {
    if (!mounted) return;

    setState(() {
      _syncStateToUI();
    });
  }

  void _syncStateToUI() {
    final state = _controller!.value;
    final type = _selectedType;
    if (type != null) {
      final isIDCard = type.typeKey == 'id_card';
      final isLongTermVal =
          (state.fieldValues['is_long_term']?.value ?? '').toLowerCase() ==
          'true';
      final showAsLongTerm = isIDCard && isLongTermVal;

      for (final field in type.fields) {
        final val = state.fieldValues[field.fieldKey]?.value ?? '';
        if (field.fieldKey == 'valid_until') {
          _actualValidUntil = val;
        }
        if (field.valueType == FieldValueType.boolean) {
          _boolFields[field.fieldKey] = val.toLowerCase() == 'true';
        } else {
          String displayVal = val;
          if (field.fieldKey == 'valid_until' && showAsLongTerm) {
            displayVal = '长期';
          } else if (field.valueType == FieldValueType.dayOfMonth &&
              val.isNotEmpty) {
            displayVal = '每月 $val 日';
          }
          if (_controllers.containsKey(field.fieldKey)) {
            if (_controllers[field.fieldKey]!.text != displayVal) {
              _controllers[field.fieldKey]!.text = displayVal;
            }
          } else {
            _controllers[field.fieldKey] = TextEditingController(
              text: displayVal,
            );
          }
        }
      }
    }
    if (_usesDynamicGenericFields) {
      final removedKeys = _controllers.keys.where((key) {
        final index = ItemEntryFlowController.genericFieldIndex(key);
        return index != null && index > state.genericCustomFieldCount;
      }).toList();
      for (final key in removedKeys) {
        _controllers.remove(key)?.dispose();
        _focusNodes.remove(key)?.dispose();
        _fieldKeys.remove(key);
        if (_lastFocusedFieldKey == key) _lastFocusedFieldKey = null;
      }
      for (var index = 1; index <= state.genericCustomFieldCount; index++) {
        for (final kind in ['label', 'value']) {
          final key = ItemEntryFlowController.genericFieldKey(kind, index);
          final text = state.fieldValues[key]?.value ?? '';
          final input = _controllers.putIfAbsent(
            key,
            TextEditingController.new,
          );
          if (input.text != text) input.text = text;
        }
      }
    }
  }

  void _syncUIToState() {
    if (_selectedType == null) return;
    final updatedValues = <String, String>{};
    for (final field in _selectedType!.fields) {
      updatedValues[field.fieldKey] = _getSubmittedFieldValue(field.fieldKey);
    }
    _controller!.setFieldValues(updatedValues);
  }

  String _getSubmittedFieldValue(String fieldKey) {
    if (_selectedType == null) return '';
    final isIDCard = _selectedType!.typeKey == 'id_card';
    if (fieldKey == 'valid_until' &&
        isIDCard &&
        (_boolFields['is_long_term'] ?? false)) {
      return _actualValidUntil;
    }
    final fieldDef = _selectedType!.fields.firstWhere(
      (f) => f.fieldKey == fieldKey,
      orElse: () => throw ArgumentError('Field not found: $fieldKey'),
    );
    if (fieldDef.valueType == FieldValueType.boolean) {
      return (_boolFields[fieldKey] ?? false) ? 'true' : 'false';
    }
    if (fieldDef.valueType == FieldValueType.dayOfMonth) {
      final text = _controllers[fieldKey]?.text ?? '';
      final digits = RegExp(r'\d+').stringMatch(text);
      return digits ?? '';
    }
    return _controllers[fieldKey]?.text ?? '';
  }

  bool get _usesDynamicGenericFields =>
      _controller?.usesDynamicGenericFields ?? false;

  FieldDefinition _genericCustomFieldDefinition(String kind, int index) {
    final isLabel = kind == 'label';
    return FieldDefinition(
      fieldKey: ItemEntryFlowController.genericFieldKey(kind, index),
      label: isLabel ? '字段名 $index' : '字段值 $index',
      valueType: FieldValueType.text,
      sensitiveLevel: SensitiveLevel.low,
      copyable: !isLabel,
    );
  }

  List<ItemFieldDraftInput> _buildDraftFields() {
    _syncUIToState();
    return _controller!.buildDraftFields();
  }

  void _removeGenericCustomField(int index) {
    _hasPendingUserChanges = true;
    _fieldErrors.removeWhere(
      (key, _) => ItemEntryFlowController.genericFieldIndex(key) != null,
    );
    _controller!.removeGenericField(index);
  }

  Future<void> _requestRemoveGenericCustomField(int index) async {
    if (_genericCustomFieldCount <= 1) return;
    final label =
        _controllers[ItemEntryFlowController.genericFieldKey('label', index)]
            ?.text ??
        '';
    final value =
        _controllers[ItemEntryFlowController.genericFieldKey('value', index)]
            ?.text ??
        '';
    final hasContent = label.trim().isNotEmpty || value.trim().isNotEmpty;
    if (!hasContent || _skipGenericFieldDeleteConfirmation) {
      _removeGenericCustomField(index);
      return;
    }

    final skipFutureConfirmation = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除已填写的字段？'),
        content: const Text('这个字段已有内容，删除后字段名和字段值都会从本次新增或编辑中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('本次不再提醒'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('删除字段'),
          ),
        ],
      ),
    );
    if (skipFutureConfirmation == null || !mounted) return;
    if (skipFutureConfirmation) {
      _skipGenericFieldDeleteConfirmation = true;
    }
    _removeGenericCustomField(index);
  }

  Future<({_ExistingItemLoadData? data, bool failed})> _fetchExistingItem(
    String itemId,
  ) async {
    try {
      final itemRepo = DependencyProvider.of(context).itemRepo;
      final memberRepo = DependencyProvider.of(context).memberRepo;
      final item = await itemRepo.getItemWithFields(itemId);
      if (item == null) return (data: null, failed: false);
      final type = item.typeKey == null
          ? null
          : TemplateRegistry.getTemplate(item.typeKey!, item.templateVersion);
      final relatedData = await Future.wait([
        item.memberId != null
            ? memberRepo.getMemberById(item.memberId!)
            : Future<MemberModel?>.value(null),
        type?.typeKey == 'household_book'
            ? itemRepo.getChildEntries(itemId)
            : Future<List<ItemChildEntryModel>>.value(const []),
      ]);
      return (
        data: _ExistingItemLoadData(
          item: item,
          member: relatedData[0] as MemberModel?,
          childEntries: relatedData[1] as List<ItemChildEntryModel>,
        ),
        failed: false,
      );
    } catch (_) {
      return (data: null, failed: true);
    }
  }

  void _applyExistingItem(_ExistingItemLoadData data) {
    if (!mounted || widget.existingItemId != data.item.id) return;
    final controller = _controller!;
    controller.removeListener(_onControllerStateChanged);
    controller.initializeFromItem(data.item, owner: data.member);
    controller.addListener(_onControllerStateChanged);
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    for (final input in _controllers.values) {
      input.dispose();
    }
    setState(() {
      _isPinned = data.item.isPinned;
      _pinnedAt = data.item.pinnedAt;
      _itemStatus = data.item.status;
      _attachmentsDraft = List.from(data.item.attachments);
      _existingAttachmentFileNames
        ..clear()
        ..addAll(
          data.item.attachments.map((attachment) => attachment.fileName),
        );
      _householdMembersDraft =
          controller.value.selectedType?.typeKey == 'household_book'
          ? data.childEntries.map(HouseholdMemberDraft.fromModel).toList()
          : [];
      _fieldKeys.clear();
      _fieldErrors.clear();
      _focusNodes.clear();
      _lastFocusedFieldKey = null;
      _controllers.clear();
      _boolFields.clear();
      _showOptionalFields = controller.hasOptionalValues;
      _noteController.text = data.item.note ?? '';
      _entryStepIndex = ItemEntryStep.editableReview.index;
      _isLoadingEditItem = false;
      _syncStateToUI();
    });
  }

  // ─── 成员加载 ────────────────────────────────────────────
  void _applyInitialMembers(List<MemberModel> members) {
    if (!mounted) return;
    if (widget.existingItemId != null) {
      setState(() {
        _members = members;
        _isLoadingMembers = false;
        _membersLoadFailed = false;
      });
      return;
    }
    setState(() => _applyMembers(members));
  }

  void _applyMembers(List<MemberModel> members) {
    _members = members;
    _isLoadingMembers = false;
    _membersLoadFailed = false;
    final initialMemberId = widget.initialMemberId;
    if (initialMemberId != null) {
      final index = members.indexWhere(
        (member) => member.id == initialMemberId,
      );
      if (index == -1) {
        _globalError = '指定成员当前不可用，请返回后重试';
        return;
      }
      _controller!.selectOwner(members[index]);
      _controller!.setStepEnum(ItemEntryStep.type);
      return;
    }
    const familyId = '00000000-0000-4000-8000-000000000001';
    final familyIndex = members.indexWhere((member) => member.id == familyId);
    if (familyIndex != -1) {
      _controller!.selectOwner(members[familyIndex]);
    } else if (members.isNotEmpty) {
      _controller!.selectOwner(members.first);
    }
  }

  Future<void> _loadMembers() async {
    if (!mounted || _isLoadingMembers) return;
    setState(() {
      _isLoadingMembers = true;
      _membersLoadFailed = false;
    });
    try {
      final memberRepo = DependencyProvider.of(context).memberRepo;
      final list = await memberRepo.getActiveMembers();
      _applyInitialMembers(list);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMembers = false;
        _membersLoadFailed = true;
      });
    }
  }

  // ─── 状态更新 ────────────────────────────────────────────
  void _onMemberSelected(MemberModel member) {
    _controller!.selectOwner(member);
    _refreshIdentityProfileSuggestion();
  }

  void _onTypeSelected(TypeDefinition type) {
    _showOptionalFields = false;
    _fieldErrors.clear();
    _fieldKeys.clear();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _lastFocusedFieldKey = null;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _boolFields.clear();
    _actualValidUntil = '';
    _globalError = null;
    _householdMembersDraft.clear();
    _controller!.selectType(type);
    if (_isMemberScopedEntry) {
      final member = _selectedMember;
      if (member == null) return;
      _controller!.selectOwner(member);
      _controller!.setStepEnum(ItemEntryStep.editableReview);
      _refreshIdentityProfileSuggestion();
      return;
    }
    _controller!.nextStep();
  }

  Future<void> _refreshIdentityProfileSuggestion() async {
    final request = ++_identityProfileRequest;
    final member = _selectedMember;
    final type = _selectedType;
    if (widget.existingItemId != null ||
        member == null ||
        type == null ||
        type.typeKey == 'id_card') {
      if (mounted && _identityProfileFields != null) {
        setState(() => _identityProfileFields = null);
      }
      return;
    }

    if (mounted && _identityProfileFields != null) {
      setState(() => _identityProfileFields = null);
    }
    final profile = await DependencyProvider.of(
      context,
    ).itemRepo.getSingleActiveIdentityProfile(member.id);
    if (!mounted || request != _identityProfileRequest) return;

    setState(() => _identityProfileFields = profile);
  }

  Map<String, String> _identitySuggestionForEmptyFields() =>
      _controller?.identitySuggestions(_identityProfileFields ?? const {}) ??
      const {};

  void _applyIdentityProfileSuggestion() {
    final suggestions = _identitySuggestionForEmptyFields();
    if (suggestions.isEmpty) return;

    setState(() {
      _hasPendingUserChanges = true;
      suggestions.forEach((fieldKey, value) {
        _controllers[fieldKey]?.text = value;
        _controller!.updateFieldWithMeta(fieldKey, value, isUserEdit: false);
        _fieldErrors.remove(fieldKey);
      });
    });
  }

  Widget? _buildIdentityProfileSuggestion() {
    final suggestions = _identitySuggestionForEmptyFields();
    if (suggestions.isEmpty) return null;

    final type = _selectedType!;
    final labels = type.fields
        .where((field) => suggestions.containsKey(field.fieldKey))
        .map((field) => field.label)
        .join('、');
    return Card(
      key: const Key('identity_profile_suggestion'),
      elevation: 0,
      color: context.anchColors.surfaceSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnchRadius.md),
        side: BorderSide(color: context.anchColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AnchSpacing.md),
        child: Row(
          children: [
            AnchIcon(
              AnchIcons.idCard,
              color: context.anchColors.documentIcon,
              size: 20,
            ),
            const SizedBox(width: AnchSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '可从身份证带入基础信息',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.anchColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$labels；只填空白字段。',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.anchColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const Key('identity_profile_suggestion_apply'),
              onPressed: _applyIdentityProfileSuggestion,
              child: const Text('带入'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 字段联动 ────────────────────────────────────────────
  void _onFieldChanged(String fieldKey, String value) {
    if (_selectedType == null) return;
    _hasPendingUserChanges = true;
    _controller!.updateFieldWithInteractions(fieldKey, value);
  }

  void _scrollToField(String fieldKey) {
    final key = _fieldKeys[fieldKey];
    if (key == null) return;
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateRequiredFields() {
    if (_selectedType == null) return true;

    _syncUIToState();
    final newFieldErrors = _controller!.requiredFieldErrors();
    final missingFieldKeys = newFieldErrors.keys.toList();

    if (missingFieldKeys.isNotEmpty) {
      setState(() {
        _fieldErrors.clear();
        _fieldErrors.addAll(newFieldErrors);
        _globalError = null;

        // If we are not currently in the editableReview step, transition back to it first
        if (_currentStep != ItemEntryStep.editableReview) {
          if (_controller != null) {
            _controller!.setStepEnum(ItemEntryStep.editableReview);
          }
        }

        // Expand optional fields section if the missing field is optional
        final optionalFields = _selectedType!.fields
            .where((f) => !f.required && f.priority != FieldPriority.p0)
            .map((f) => f.fieldKey)
            .toSet();
        for (final key in missingFieldKeys) {
          if (optionalFields.contains(key)) {
            _showOptionalFields = true;
            break;
          }
        }
      });

      // Now scroll to the first error field
      final firstErrorKey = missingFieldKeys.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToField(firstErrorKey);
      });

      return false;
    }

    return true;
  }

  /// 构造并提交草稿，走 ItemUseCaseService，不绕过校验。
  ///
  /// [withNote] 是否将 _noteController 的内容写入备注字段。
  Future<void> _saveDraft({bool withNote = false}) async {
    if (_isSaving) return;
    if (_selectedMember == null || _selectedType == null) return;

    if (!_validateRequiredFields()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _fieldErrors.clear();
      _globalError = null;
    });

    try {
      // 组装字段草稿
      final draftFields = _buildDraftFields();

      final draft = ItemDraftInput(
        id: _itemId,
        memberId: _selectedMember!.id,
        categoryKey: _selectedType!.categoryKey,
        typeKey: _selectedType!.typeKey,
        templateVersion: _selectedType!.version,
        fields: draftFields,
        // 如果是编辑模式或者开启了 withNote，就保存备注
        note:
            (widget.existingItemId != null || withNote) &&
                _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        isPinned: _isPinned,
        pinnedAt: _pinnedAt,
        status: _itemStatus,
        attachments: _attachmentsDraft
            .map(
              (a) => SaveAttachmentInput(
                id: a.id,
                originAttachmentId: a.originAttachmentId,
                itemId: a.itemId,
                linkedFieldKey: a.linkedFieldKey,
                attachmentRole: a.attachmentRole,
                fileName: a.fileName,
                originalName: a.originalName,
                mimeType: a.mimeType,
                plainSize: a.plainSize,
                encryptedSize: a.encryptedSize,
                sha256: a.sha256,
                sortOrder: a.sortOrder,
              ),
            )
            .toList(),
        childEntries: _selectedType!.typeKey == 'household_book'
            ? _householdMembersDraft.map((e) => e.toSaveInput()).toList()
            : null,
      );

      final service = DependencyProvider.of(context).itemUseCaseService;
      final result = await service.saveDraft(draft);
      if (!mounted) return;

      if (result.persisted) {
        if (mounted) {
          if (widget.existingItemId != null) {
            // 编辑保存成功：pop 并传回 'save' 触发上层详情页刷新
            Navigator.pop(context, 'save');
          } else {
            if (widget.renewalSourceItemId != null) {
              await _resolveRenewalSource(result.itemId!);
              return;
            }
            // 新建保存成功：pop 并传回新建的 itemId
            Navigator.pop(context, result.itemId);
          }
        }
      } else {
        setState(() {
          _globalError = result.errors.isNotEmpty
              ? result.errors.first.errorMessage
              : '系统存储未成功';

          final missingFieldKeys = <String>[];
          for (final error in result.errors) {
            if (error.fieldKey != null && error.fieldKey!.isNotEmpty) {
              _fieldErrors[error.fieldKey!] = error.errorMessage;
              missingFieldKeys.add(error.fieldKey!);
            }
          }

          if (_currentStep != ItemEntryStep.editableReview) {
            if (_controller != null) {
              _controller!.setStepEnum(ItemEntryStep.editableReview);
            }
          }

          // Expand optional fields if needed
          final optionalFields = _selectedType!.fields
              .where((f) => !f.required && f.priority != FieldPriority.p0)
              .map((f) => f.fieldKey)
              .toSet();
          for (final key in missingFieldKeys) {
            if (optionalFields.contains(key)) {
              _showOptionalFields = true;
              break;
            }
          }

          if (missingFieldKeys.isNotEmpty) {
            final firstErrorKey = missingFieldKeys.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToField(firstErrorKey);
            });
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _globalError = '保存失败，请重试';
        if (_controller != null) {
          _controller!.setStepEnum(ItemEntryStep.editableReview);
        }
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resolveRenewalSource(String newItemId) async {
    final sourceId = widget.renewalSourceItemId!;
    final source = await DependencyProvider.of(
      context,
    ).itemRepo.getItemWithFields(sourceId);
    if (!mounted) return;
    if (source?.status == 'active') {
      final shouldArchive = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('如何处理上一份？'),
            content: const Text('新保险已保存。请选择是否将上一份归档。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('暂不归档'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('归档上一份'),
              ),
            ],
          ),
        ),
      );
      if (shouldArchive == true && mounted) {
        final archiveResult = await DependencyProvider.of(
          context,
        ).itemUseCaseService.archiveItem(sourceId);
        if (!archiveResult.success && mounted) {
          await showDialog<void>(
            context: context,
            useRootNavigator: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('上一份未归档'),
              content: const Text('新保险已保存，但上一份归档失败。可稍后在原资料中重试。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
      }
    }
    if (mounted) Navigator.pop(context, newItemId);
  }

  // ─── 返回逻辑 ────────────────────────────────────────────
  void _onBack() {
    if (_isSaving || _isFileAttachmentImporting) return;
    if (_currentStep == ItemEntryStep.editableReview) {
      _syncUIToState();
    }

    if (_isMemberScopedEntry) {
      switch (_currentStep) {
        case ItemEntryStep.supplement:
          _controller!.setStepEnum(ItemEntryStep.editableReview);
          return;
        case ItemEntryStep.editableReview:
          _controller!.setStepEnum(ItemEntryStep.type);
          return;
        case ItemEntryStep.type:
        case ItemEntryStep.owner:
          _confirmExit();
          return;
      }
    }

    final currentIndex = _currentStep.index;

    if (currentIndex > _entryStepIndex) {
      _controller!.prevStep();
    } else {
      _confirmExit();
    }
  }

  Future<void> _confirmExit() async {
    if (_isSaving || _isFileAttachmentImporting) return;
    if (!_hasPendingUserChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_isExitDialogShowing) return;
    _isExitDialogShowing = true;

    // 在异步 gap 前捕获 NavigatorState，避免 context 失效
    final navigatorState = Navigator.of(context);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('确认退出'),
          content: const Text('确认要退出并放弃当前编辑的内容吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                '取消',
                style: TextStyle(color: ctx.anchColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('退出', style: TextStyle(color: ctx.anchColors.danger)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await _discardNewAttachmentDrafts();
        if (!mounted) return;
        navigatorState.pop();
      }
    } finally {
      // finally 独立复位，不依赖 pop 回调
      _isExitDialogShowing = false;
    }
  }

  // ─── 输入辅助 ────────────────────────────────────────────
  List<TextInputFormatter> _getInputFormatters(FieldValueType type) {
    switch (type) {
      case FieldValueType.idNumber:
        return [IdCardNumberFormatter()];
      case FieldValueType.bankCardNumber:
        return [PureNumberFormatter()];
      case FieldValueType.number:
        return [PureNumberFormatter()];
      case FieldValueType.decimal:
        return [DecimalNumberFormatter()];
      case FieldValueType.phone:
        return [PhoneCharactersFormatter()];
      default:
        return [];
    }
  }

  TextInputType _getKeyboardType(FieldValueType type) {
    switch (type) {
      case FieldValueType.number:
        return TextInputType.number;
      case FieldValueType.decimal:
        return const TextInputType.numberWithOptions(decimal: true);
      case FieldValueType.phone:
        return TextInputType.phone;
      case FieldValueType.bankCardNumber:
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
  void dispose() {
    final initializationAnimation = _initializationAnimation;
    final initializationListener = _initializationStatusListener;
    if (initializationAnimation != null && initializationListener != null) {
      initializationAnimation.removeStatusListener(initializationListener);
    }
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_fileAttachmentImportController.clearFilePickerSessionLocation());
    _controller?.removeListener(_onControllerStateChanged);
    if (widget.controller == null) {
      _controller?.dispose();
    }
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _noteController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => ScreenProtectionScope(
    child: Stack(
      children: [
        AbsorbPointer(absorbing: _isSaving, child: _buildPage(context)),
        if (_isFileAttachmentImporting)
          const AnchBlockingProgressOverlay(
            title: '正在导入附件',
            message: '正在加密并保存附件，请保持应用在前台',
            progress: null,
            semanticsLabel: '正在导入附件，请勿退出',
            barrierKey: ValueKey('entry_attachment_import_loading_barrier'),
          ),
      ],
    ),
  );

  Widget _buildPage(BuildContext context) {
    if (!_isInitialized) {
      return AnchAppScaffold(
        maxContentWidth: 640,
        body: Center(
          child: CircularProgressIndicator(
            color: context.anchColors.accentDeep,
          ),
        ),
      );
    }
    final isKeyboardCurrentlyVisible =
        MediaQuery.of(context).viewInsets.bottom > 0;
    if (_wasKeyboardVisible && !isKeyboardCurrentlyVisible) {
      if (_lastFocusedFieldKey != null) {
        final key = _fieldKeys[_lastFocusedFieldKey];
        if (key != null && key.currentContext != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 150),
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          });
        }
      }
    }
    _wasKeyboardVisible = isKeyboardCurrentlyVisible;

    // ── 编辑模式加载中：不渲染正式流程，不访问 _entryStepIndex ──
    if (widget.existingItemId != null && _isLoadingEditItem) {
      return AnchAppScaffold(
        maxContentWidth: 640,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ── 编辑模式加载失败：不渲染正式流程，不访问 _entryStepIndex ──
    if (widget.existingItemId != null &&
        _globalError != null &&
        _isLoadingEditItem == false &&
        _controller?.value.currentStep != ItemEntryStep.editableReview &&
        _controller?.value.currentStep != ItemEntryStep.supplement) {
      return AnchAppScaffold(
        maxContentWidth: 640,
        body: Column(
          children: [
            AnchPageHeader(
              title: _selectedType != null
                  ? '编辑${_selectedType!.label}'
                  : '编辑资料',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: AnchEmptyState(
                  title: _globalError!,
                  actionLabel: '重新加载',
                  onAction: _retryExistingItem,
                  icon: AnchIcons.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── 正式录入流程：PopScope + AnchFlowHeader ──────────────
    return AnchAppScaffold(
      maxContentWidth: 640,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_isFileAttachmentImporting) return;
          _onBack();
        },
        child: Column(
          children: [
            // 紧凑工具栏（录入流程专用）
            AnchFlowHeader(
              key: const Key('flow_header'),
              title: _selectedType != null
                  ? (widget.existingItemId != null
                        ? '编辑${_selectedType!.label}'
                        : '新增${_selectedType!.label}')
                  : (widget.existingItemId != null ? '编辑资料' : '新增资料'),
              onBack: _onBack,
              onClose: _confirmExit,
            ),

            // 步进条（新增和编辑模式均展示）
            AnchStepIndicator(
              key: const Key('step_indicator'),
              totalSteps: _totalSteps,
              labels: _isMemberScopedEntry
                  ? const ['类型', '填写', '补充']
                  : const ['类型', '归属', '填写', '补充'],
              currentStep: _visibleStepIndex(_currentStep),
            ),
            const SizedBox(height: AnchSpacing.xs),

            // 开发验证模式提示（每步均展示，不可删除）
            if (RuntimeScope.of(context).isDevMode)
              AnchSecurityBanner(
                message: AnchSecurityBanner.devModeMessage,
                type: AnchBannerType.warning,
                compactWhenKeyboardVisible: true,
                isKeyboardVisible: _isKeyboardVisible,
              ),

            // 全局错误提示（正式流程内的字段/保存错误）
            if (_globalError != null)
              _GlobalErrorBanner(message: _globalError!),

            const SizedBox(height: AnchSpacing.xs),

            // 步骤内容
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final scaleAnimation = Tween<double>(begin: 0.98, end: 1.0)
                      .animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                      );
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: scaleAnimation, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<ItemEntryStep>(_currentStep),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_isLoadingEditItem) {
      return Center(
        child: CircularProgressIndicator(
          color: context.anchColors.accentDeep,
          strokeWidth: 2,
        ),
      );
    }
    if (_membersLoadFailed) {
      return SingleChildScrollView(
        child: AnchEmptyState(
          title: '加载成员列表失败',
          actionLabel: '重新加载',
          onAction: _loadMembers,
          icon: AnchIcons.error,
        ),
      );
    }
    if (_isMemberScopedEntry && _isLoadingMembers) {
      return Center(
        child: CircularProgressIndicator(
          color: context.anchColors.accentDeep,
          strokeWidth: 2,
        ),
      );
    }
    switch (_currentStep) {
      case ItemEntryStep.type:
        return _buildTypePicker();
      case ItemEntryStep.owner:
        return _buildOwnerSelector();
      case ItemEntryStep.editableReview:
        return _buildStep2FieldInput();
      case ItemEntryStep.supplement:
        return _buildStep3Supplement();
    }
  }

  Widget _buildTypePicker() {
    final types = TemplateRegistry.getCreatableTypes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnchSectionHeader(title: '选择资料类型'),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const horizontalPadding = AnchSpacing.page * 2;
              const spacing = AnchSpacing.md;
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final largeText = textScale >= 1.5;
              final columns = AnchAdaptiveGrid.columnCountFor(
                availableWidth: constraints.maxWidth - horizontalPadding,
                minTileWidth: largeText
                    ? 280
                    : 144.0 * textScale.clamp(1.0, 1.5),
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
                  mainAxisExtent: largeText
                      ? 156
                      : 88.0 + (textScale - 1).clamp(0.0, 0.5) * 24,
                ),
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final type = types[index];
                  final isSelected =
                      _controller!.value.selectedType?.typeKey == type.typeKey;

                  return AnchChoiceCard(
                    key: type.typeKey == 'id_card'
                        ? KeyRegistry.typeCardIdCard
                        : (type.typeKey == 'debit_card'
                              ? KeyRegistry.typeCardDebitCard
                              : null),
                    title: type.label,
                    icon: AnchIcons.forTypeKey(type.typeKey),
                    selected: isSelected,
                    compact: true,
                    onTap: () => _onTypeSelected(type),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerSelector() {
    if (_isLoadingMembers) {
      return Center(
        child: CircularProgressIndicator(
          color: context.anchColors.accentDeep,
          strokeWidth: 2,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnchSectionHeader(title: '选择归属'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AnchSpacing.page,
              vertical: AnchSpacing.xs,
            ),
            children: [
              ..._members.map((member) {
                final isFamily = member.memberType == 'family';
                final isSelected = _selectedMember?.id == member.id;
                return _OwnerRow(
                  key: isFamily ? KeyRegistry.ownerCardFamily : null,
                  memberId: member.id,
                  name: member.name,
                  selected: isSelected,
                  onTap: () => _onMemberSelected(member),
                );
              }),
              _buildAddMemberChoice(),
            ],
          ),
        ),

        if (!_isKeyboardVisible)
          AnchBottomActionBar(
            key: KeyRegistry.flowButtonNext,
            primaryLabel: '下一步：填写资料',
            compactWhenKeyboardVisible: true,
            compactPrimaryLabel: '下一步',
            isKeyboardVisible: _isKeyboardVisible,
            flat: true,
            onPrimary: _selectedMember == null
                ? null
                : () {
                    _controller!.nextStep();
                  },
          ),
      ],
    );
  }

  Widget _buildAddMemberChoice() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AnchSpacing.sm),
      child: AnchChoiceCard(
        title: '新增家庭成员',
        icon: AnchIcons.add,
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            sheetAnimationStyle: AnchMotion.bottomSheetAnimationStyle(context),
            builder: (_) => const MemberFormSheet(),
          ).then((newMemberId) {
            if (newMemberId != null && newMemberId is String) {
              _loadMembers().then((_) {
                final newMember = _members.firstWhere(
                  (member) => member.id == newMemberId,
                  orElse: () => _members.first,
                );
                _onMemberSelected(newMember);
              });
            }
          });
        },
      ),
    );
  }

  // ─── Step 2: 填写核心字段 ─────────────────────────────────
  Widget _buildStep2FieldInput() {
    final selectedType = _selectedType;
    if (selectedType == null) {
      return const Center(child: Text('未选择模板'));
    }
    return ItemEntryFieldInputSection(
      selectedType: selectedType,
      existingItemId: widget.existingItemId,
      showOptionalFields: _showOptionalFields,
      onShowOptionalFieldsChanged: (visible) {
        setState(() => _showOptionalFields = visible);
      },
      isKeyboardVisible: _isKeyboardVisible,
      scrollBottomPadding: _scrollBottomPadding,
      fieldBuilder: _buildFieldWidget,
      onNext: _executeStep2PrimaryAction,
      identityProfileSuggestion: _buildIdentityProfileSuggestion(),
      genericFieldsLayout: _usesDynamicGenericFields
          ? _buildDynamicGenericFieldsLayout()
          : null,
      shippingAddressPasteAction: selectedType.typeKey == 'shipping_address'
          ? _buildShippingAddressPasteAction()
          : null,
    );
  }

  Widget _buildShippingAddressPasteAction() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('shipping_address_paste_and_parse'),
        onPressed: _pasteAndParseShippingAddress,
        icon: const AnchIcon(AnchIcons.copy, size: 18),
        label: const Text('粘贴并解析'),
      ),
    );
  }

  Future<void> _pasteAndParseShippingAddress() async {
    FocusScope.of(context).unfocus();
    final clipboardText =
        (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    if (clipboardText.isEmpty) {
      AnchCenteredNotice.showError(context, '剪贴板中没有可解析的地址');
      return;
    }

    final parsed = ShippingAddressParser.parse(clipboardText);
    if (!parsed.hasAnyValue) {
      AnchCenteredNotice.showError(context, '未识别到地址内容');
      return;
    }

    final values = parsed.toFieldValues();
    setState(() {
      for (final entry in values.entries) {
        _controllers[entry.key]?.text = entry.value;
      }
    });
    for (final entry in values.entries) {
      _onFieldChanged(entry.key, entry.value);
    }
    AnchCenteredNotice.showSuccess(context, '已解析，请确认后保存');
  }

  Widget _buildDynamicGenericFieldsLayout() {
    final title = _selectedType!.fields.firstWhere(
      (field) => field.fieldKey == 'title',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDynamicGenericFieldCard(
          const Key('item_field_group_generic_title'),
          [_buildFieldWidget(title)],
        ),
        for (var index = 1; index <= _genericCustomFieldCount; index++) ...[
          const SizedBox(height: AnchSpacing.md),
          _buildDynamicGenericFieldCard(
            Key('item_field_group_generic_pair_$index'),
            [
              _buildFieldWidget(_genericCustomFieldDefinition('label', index)),
              _buildFieldWidget(_genericCustomFieldDefinition('value', index)),
              if (_genericCustomFieldCount > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: Key('generic_custom_field_remove_$index'),
                    onPressed: () => _requestRemoveGenericCustomField(index),
                    icon: const AnchIcon(AnchIcons.remove),
                    label: const Text('删除字段'),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AnchSpacing.xs),
        OutlinedButton.icon(
          key: const Key('generic_custom_field_add'),
          onPressed: _controller!.addGenericField,
          icon: const AnchIcon(AnchIcons.add),
          label: const Text('添加字段'),
        ),
      ],
    );
  }

  Widget _buildDynamicGenericFieldCard(Key key, List<Widget> children) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: context.anchColors.surface,
        border: Border(bottom: BorderSide(color: context.anchColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AnchSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildFieldWidget(FieldDefinition field) {
    final isDebitCard = _selectedType?.typeKey == 'debit_card';
    if (isDebitCard &&
        (field.fieldKey == 'open_region' ||
            field.fieldKey == 'tail_number' ||
            field.fieldKey == 'reserved_phone' ||
            field.fieldKey == 'card_color')) {
      return const SizedBox.shrink();
    }

    final isCreditCard = _selectedType?.typeKey == 'credit_card';
    if (isCreditCard &&
        (field.fieldKey == 'tail_number' ||
            field.fieldKey == 'reserved_phone' ||
            field.fieldKey == 'repayment_account')) {
      return const SizedBox.shrink();
    }

    if (!FieldRenderPolicy.isFieldAllowed(
      field.fieldKey,
      field.sensitiveLevel,
    )) {
      return const SizedBox.shrink();
    }
    final child = _buildFieldWidgetImpl(field);
    return KeyedSubtree(key: _getFieldKey(field.fieldKey), child: child);
  }

  Widget _buildFieldWidgetImpl(FieldDefinition field) {
    final isRequired = field.required;
    final errorText = _fieldErrors[field.fieldKey];

    final isIDCard = _selectedType?.typeKey == 'id_card';
    final isPassport = _selectedType?.typeKey == 'passport';
    final isHkMacaoPass = _selectedType?.typeKey == 'hk_macao_pass';
    final isDrivingLicense = _selectedType?.typeKey == 'driver_license';
    final isBirthCertificate = _selectedType?.typeKey == 'birth_certificate';
    final isCreditCard = _selectedType?.typeKey == 'credit_card';
    final isEducationCertificate =
        _selectedType?.typeKey == 'education_certificate';

    final focusNode = _getFocusNode(field.fieldKey);
    final labelWidget = ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => ItemEntryFieldLabel(
        fieldKey: field.fieldKey,
        label: field.label,
        required: isRequired,
        textColor: focusNode.hasFocus
            ? context.anchColors.accent
            : context.anchColors.textSecondary,
        requiredColor: context.anchColors.danger,
      ),
    );

    // 性别字段使用二选一选择器
    if ((isIDCard ||
            isPassport ||
            isHkMacaoPass ||
            isDrivingLicense ||
            isBirthCertificate) &&
        field.fieldKey == 'gender') {
      final selectedGender = _controllers[field.fieldKey]?.text;

      return Padding(
        key: Key('item_field_root_${field.fieldKey}'),
        padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            ItemEntryGenderSelector(
              key: Key('item_field_control_${field.fieldKey}'),
              fieldLabel: field.label,
              value: selectedGender,
              onChanged: (val) {
                setState(() {
                  _controllers[field.fieldKey] ??= TextEditingController();
                  _controllers[field.fieldKey]!.text = val;
                });
                _onFieldChanged(field.fieldKey, val);
              },
              hasError: errorText != null,
            ),
            _buildAnimatedError(errorText, field),
          ],
        ),
      );
    }

    // Boolean 字段：Switch
    if (field.valueType == FieldValueType.boolean) {
      final isLongTermField = isIDCard && field.fieldKey == 'is_long_term';

      if (isLongTermField) {
        return Padding(
          key: Key('item_field_root_${field.fieldKey}'),
          padding: const EdgeInsets.symmetric(vertical: AnchSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      field.label,
                      key: Key('item_field_label_${field.fieldKey}'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.anchColors.textSecondary,
                      ),
                    ),
                    Switch(
                      key: Key('item_field_control_${field.fieldKey}'),
                      value: _boolFields[field.fieldKey] ?? false,
                      activeThumbColor: context.anchColors.accent,
                      onChanged: (val) {
                        setState(() {
                          _boolFields[field.fieldKey] = val;
                          if (val) {
                            _controllers['valid_until']?.text = '长期';
                            _onFieldChanged('valid_until', _actualValidUntil);
                          } else {
                            _controllers['valid_until']?.text =
                                _actualValidUntil;
                            _onFieldChanged('valid_until', _actualValidUntil);
                          }
                        });
                        _onFieldChanged(field.fieldKey, val ? 'true' : 'false');
                      },
                    ),
                  ],
                ),
              ),
              _buildAnimatedError(errorText, field),
            ],
          ),
        );
      }

      return Padding(
        key: Key('item_field_root_${field.fieldKey}'),
        padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: Key('item_field_control_${field.fieldKey}'),
              title: Text(
                field.label,
                key: Key('item_field_label_${field.fieldKey}'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.anchColors.textSecondary,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: _boolFields[field.fieldKey] ?? false,
              activeThumbColor: context.anchColors.accent,
              onChanged: (val) {
                setState(() => _boolFields[field.fieldKey] = val);
                _onFieldChanged(field.fieldKey, val ? 'true' : 'false');
              },
            ),
            _buildAnimatedError(errorText, field),
          ],
        ),
      );
    }

    // 出生证明的出生时间：时间选择组件
    if (isBirthCertificate && field.fieldKey == 'birth_time') {
      final ctrl = _controllers[field.fieldKey];

      return Padding(
        key: Key('item_field_root_${field.fieldKey}'),
        padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            Semantics(
              label: field.label,
              child: TextFormField(
                key: Key('item_field_control_${field.fieldKey}'),
                controller: ctrl,
                readOnly: true,
                focusNode: _getFocusNode(field.fieldKey),
                scrollPadding: _fieldScrollPadding,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnchRadius.sm),
                    borderSide: BorderSide(
                      color: context.anchColors.borderStrong,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnchRadius.sm),
                    borderSide: BorderSide(
                      color: context.anchColors.borderStrong,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  suffixIcon: const Center(
                    child: AnchIcon(AnchIcons.time, size: 16),
                  ),
                  filled: true,
                  fillColor: context.anchColors.surface,
                ),
                onTap: () async {
                  _getFocusNode(field.fieldKey).requestFocus();
                  TimeOfDay initialTime;
                  final text = ctrl?.text.trim() ?? '';
                  final parts = text.split(':');
                  if (parts.length == 2) {
                    final hour = int.tryParse(parts[0]);
                    final minute = int.tryParse(parts[1]);
                    if (hour != null &&
                        minute != null &&
                        hour >= 0 &&
                        hour < 24 &&
                        minute >= 0 &&
                        minute < 60) {
                      initialTime = TimeOfDay(hour: hour, minute: minute);
                    } else {
                      final now = DependencyProvider.of(
                        context,
                      ).timeDomainSource.now();
                      initialTime = TimeOfDay(
                        hour: now.hour,
                        minute: now.minute,
                      );
                    }
                  } else {
                    final now = DependencyProvider.of(
                      context,
                    ).timeDomainSource.now();
                    initialTime = TimeOfDay(hour: now.hour, minute: now.minute);
                  }

                  final picked = await showAnchBottomSheet<TimeOfDay>(
                    context: context,
                    builder: (context) =>
                        ItemEntryTimePicker(initialTime: initialTime),
                  );
                  if (picked != null) {
                    final hourStr = picked.hour.toString().padLeft(2, '0');
                    final minStr = picked.minute.toString().padLeft(2, '0');
                    final formatted = '$hourStr:$minStr';
                    setState(() {
                      if (ctrl != null) {
                        ctrl.text = formatted;
                      }
                    });
                    _onFieldChanged(field.fieldKey, formatted);
                  }
                },
              ),
            ),
            _buildAnimatedError(errorText, field),
          ],
        ),
      );
    }

    // 每月日期选择器（账单日/还款日）
    if (field.valueType == FieldValueType.dayOfMonth) {
      final ctrl = _controllers[field.fieldKey];

      return Padding(
        key: Key('item_field_root_${field.fieldKey}'),
        padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            Semantics(
              label: field.label,
              child: TextFormField(
                key: Key('item_field_control_${field.fieldKey}'),
                controller: ctrl,
                readOnly: true,
                focusNode: _getFocusNode(field.fieldKey),
                scrollPadding: _fieldScrollPadding,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnchRadius.sm),
                    borderSide: BorderSide(
                      color: context.anchColors.borderStrong,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnchRadius.sm),
                    borderSide: BorderSide(
                      color: context.anchColors.borderStrong,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  suffixIcon: const Center(
                    child: AnchIcon(AnchIcons.calendar, size: 16),
                  ),
                  filled: true,
                  fillColor: context.anchColors.surface,
                ),
                onTap: () async {
                  _getFocusNode(field.fieldKey).requestFocus();
                  final text = ctrl?.text.trim() ?? '';
                  final match = RegExp(r'\d+').stringMatch(text);
                  final initialDay = match != null
                      ? (int.tryParse(match) ?? 15)
                      : 15;

                  final picked = await showAnchBottomSheet<int>(
                    context: context,
                    builder: (context) =>
                        ItemEntryDayOfMonthPicker(initialDay: initialDay),
                  );
                  if (picked != null) {
                    final formatted = '每月 $picked 日';
                    setState(() {
                      if (ctrl != null) {
                        ctrl.text = formatted;
                      }
                    });
                    _onFieldChanged(field.fieldKey, '$picked');
                  }
                },
              ),
            ),
            _buildAnimatedError(errorText, field),
          ],
        ),
      );
    }

    // Date 字段：只读 + 年月日滚轮选择
    if (field.valueType == FieldValueType.date) {
      final ctrl = _controllers[field.fieldKey];
      final isValidUntil = field.fieldKey == 'valid_until';
      final isLongTerm = isIDCard && (_boolFields['is_long_term'] ?? false);
      final showAsLongTerm = isLongTerm && isValidUntil;

      final displayCtrl = showAsLongTerm
          ? (ctrl != null
                ? (ctrl..text = '长期')
                : TextEditingController(text: '长期'))
          : ctrl;
      final isDateDisabled = showAsLongTerm;

      return Padding(
        key: Key('item_field_root_${field.fieldKey}'),
        padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            Semantics(
              label: field.label,
              child: TextFormField(
                key: Key('item_field_control_${field.fieldKey}'),
                controller: displayCtrl,
                readOnly: true,
                focusNode: _getFocusNode(field.fieldKey),
                scrollPadding: _fieldScrollPadding,
                decoration: InputDecoration(
                  hintText: isDateDisabled ? null : '选择日期',
                  suffixIconConstraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  suffixIcon: isDateDisabled
                      ? null
                      : const Center(
                          child: AnchIcon(AnchIcons.calendar, size: 16),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnchRadius.sm),
                    borderSide: BorderSide(
                      color: context.anchColors.borderStrong,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnchRadius.sm),
                    borderSide: BorderSide(
                      color: context.anchColors.borderStrong,
                    ),
                  ),
                  filled: true,
                  fillColor: context.anchColors.surface,
                ),
                onTap: isDateDisabled
                    ? null
                    : () async {
                        _getFocusNode(field.fieldKey).requestFocus();
                        final initialDate =
                            DateTime.tryParse(ctrl?.text ?? '') ??
                            DependencyProvider.of(
                              context,
                            ).timeDomainSource.now();
                        final picked = await showAnchBottomSheet<DateTime>(
                          context: context,
                          builder: (context) =>
                              ItemEntryDatePicker(initialDate: initialDate),
                        );
                        if (picked != null) {
                          final formatted =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          if (field.fieldKey == 'valid_until') {
                            _actualValidUntil = formatted;
                          }
                          setState(() {
                            if (ctrl != null) {
                              ctrl.text = formatted;
                            }
                          });
                          _onFieldChanged(field.fieldKey, formatted);
                        }
                      },
              ),
            ),
            _buildAnimatedError(errorText, field),
          ],
        ),
      );
    }

    // 其他文本类字段
    final formatters = _getInputFormatters(field.valueType);
    final keyboard = _getKeyboardType(field.valueType);
    final genericCustomFieldIndex = _usesDynamicGenericFields
        ? ItemEntryFlowController.genericFieldIndex(field.fieldKey)
        : null;
    final isGenericCustomFieldLabel =
        genericCustomFieldIndex != null &&
        field.fieldKey.startsWith('custom_field_label_');
    final isGenericCustomFieldValue =
        genericCustomFieldIndex != null &&
        field.fieldKey.startsWith('custom_field_value_');
    final maxLength = isGenericCustomFieldLabel
        ? _genericCustomFieldLabelMaxLength
        : (isGenericCustomFieldValue
              ? _genericCustomFieldValueMaxLength
              : null);

    final isAddress =
        (isIDCard && field.fieldKey == 'address') ||
        (_selectedType?.typeKey == 'shipping_address' &&
            field.fieldKey == 'detailed_address');
    final maxLines = isAddress ? 3 : 1;
    final minLines = isAddress ? 2 : 1;
    final keyboardType = isAddress ? TextInputType.multiline : keyboard;

    return Padding(
      key: Key('item_field_root_${field.fieldKey}'),
      padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelWidget,
          ItemEntryTextField(
            fieldKey: field.fieldKey,
            label: field.label,
            controller: _controllers[field.fieldKey],
            focusNode: _getFocusNode(field.fieldKey),
            scrollPadding: _fieldScrollPadding,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            maxLines: maxLines,
            minLines: minLines,
            fillColor: context.anchColors.surface,
            maxLength: maxLength,
            hintText: isGenericCustomFieldLabel
                ? '最多 $_genericCustomFieldLabelMaxLength 字'
                : null,
            helperText: field.fieldKey == 'account_type'
                ? '一类／二类／三类'
                : field.fieldKey == 'insurance_type'
                ? '医疗险、意外险、车险等'
                : isCreditCard && field.fieldKey == 'card_network'
                ? '银联、Visa、Mastercard 等'
                : isEducationCertificate && field.fieldKey == 'certificate_type'
                ? '毕业证、学位证等'
                : isEducationCertificate && field.fieldKey == 'degree_level'
                ? '本科、硕士、学士等'
                : null,
            onChanged: (value) => _onFieldChanged(field.fieldKey, value),
          ),
          _buildAnimatedError(errorText, field),
        ],
      ),
    );
  }

  // ─── Step 3: 补充信息 / 保存 ──────────────────────────────
  Widget _buildStep3Supplement() {
    final type = _selectedType;
    final typeKey = type?.typeKey;
    final expiryPreview =
        ItemExpiryStatusPolicy.supportsType(
          typeKey,
          templateVersion: type?.version,
        )
        ? Builder(
            builder: (context) {
              final fieldKey = ItemExpiryStatusPolicy.expiryFieldKeyFor(
                typeKey,
                templateVersion: type?.version,
              )!;
              final rawState = {
                'fields': <String, dynamic>{
                  fieldKey: _getSubmittedFieldValue(fieldKey),
                  'is_long_term': _boolFields['is_long_term'] ?? false,
                },
              };
              final policyResult = ItemExpiryStatusPolicy.calculate(
                typeKey: typeKey,
                templateVersion: type?.version,
                rawState: rawState,
                now: DependencyProvider.of(context).timeDomainSource.now(),
              );
              return _ExpiryStatusPreviewRow(
                status: policyResult.status,
                daysUntilExpiry: policyResult.daysUntilExpiry,
              );
            },
          )
        : null;
    return ItemEntrySupplementSection(
      attachments: _attachmentsDraft,
      showAddAttachment:
          AttachmentImportController.remainingAttachmentSlots(
            _attachmentsDraft.length,
          ) >
          0,
      onAddAttachment: () => _pickAttachment('other'),
      onDeleteAttachment: _deleteAttachmentDraft,
      noteInput: _buildNoteInputSection(),
      householdMemberSection: typeKey == 'household_book'
          ? _buildHouseholdBookMembersSection()
          : null,
      expiryPreview: expiryPreview,
      isKeyboardVisible: _isKeyboardVisible,
      existingItemId: widget.existingItemId,
      isSaving: _isSaving,
      onSave: () => _saveDraft(withNote: true),
    );
  }

  Widget _buildNoteInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '备注',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.anchColors.textSecondary,
          ),
        ),
        const SizedBox(height: AnchSpacing.sm),
        TextFormField(
          key: const Key('entry_note_field'),
          controller: _noteController,
          maxLines: 3,
          minLines: 2,
          keyboardType: TextInputType.multiline,
          enableInteractiveSelection: true,
          contextMenuBuilder: (context, editableTextState) {
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: editableTextState.contextMenuButtonItems,
            );
          },
          onChanged: (_) => _hasPendingUserChanges = true,
          style: TextStyle(fontSize: 16, color: context.anchColors.textPrimary),
          decoration: InputDecoration(
            hintText: '可填写补充说明',
            hintStyle: TextStyle(
              color: context.anchColors.textMuted,
              fontSize: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AnchRadius.md),
              borderSide: BorderSide(color: context.anchColors.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AnchRadius.md),
              borderSide: BorderSide(color: context.anchColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AnchRadius.md),
              borderSide: BorderSide(color: context.anchColors.accentDeep),
            ),
            filled: true,
            fillColor: context.anchColors.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildHouseholdBookMembersSection() => HouseholdMemberEditorSection(
    members: _householdMembersDraft,
    onChanged: (members) => setState(() {
      _householdMembersDraft = members;
      _hasPendingUserChanges = true;
    }),
  );
}

// ─── 大类+模板 ExpansionTile ─────────────────────────────────

/// 大类展开卡片，展示该大类下所有模板。
///
/// - 点击大类标题展开/折叠
/// - 点击模板直接进入字段填写
class _ExpiryStatusPreviewRow extends StatelessWidget {
  const _ExpiryStatusPreviewRow({
    required this.status,
    required this.daysUntilExpiry,
  });

  final ItemExpiryStatus status;
  final int? daysUntilExpiry;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color iconColor;
    Color hintColor;
    AnchIconData icon;
    String hintText;

    switch (status) {
      case ItemExpiryStatus.missing:
      case ItemExpiryStatus.unsupported:
        bgColor = context.anchColors.surface;
        borderColor = context.anchColors.divider;
        iconColor = context.anchColors.textMuted;
        hintColor = context.anchColors.textMuted;
        icon = AnchIcons.notification;
        hintText = '填写有效期后，安册会在资料列表和详情中提示到期状态';
        break;
      case ItemExpiryStatus.invalid:
        bgColor = context.anchColors.warningSoft;
        borderColor = context.anchColors.warning.withValues(alpha: 0.25);
        iconColor = context.anchColors.warning;
        hintColor = context.anchColors.warning;
        icon = AnchIcons.warning;
        hintText = '有效期格式异常，请返回填写页检查';
        break;
      case ItemExpiryStatus.normal:
        bgColor = context.anchColors.surface;
        borderColor = context.anchColors.divider;
        iconColor = context.anchColors.textMuted;
        hintColor = context.anchColors.textMuted;
        icon = AnchIcons.notification;
        hintText = '当前有效期未临近，到期前 30 天内会自动提示';
        break;
      case ItemExpiryStatus.upcoming:
        if (daysUntilExpiry != null && daysUntilExpiry! <= 7) {
          bgColor = context.anchColors.dangerSoft;
          borderColor = context.anchColors.danger.withValues(alpha: 0.25);
          iconColor = context.anchColors.danger;
          hintColor = context.anchColors.danger;
          icon = AnchIcons.error;
          hintText = '保存后将显示剩余 $daysUntilExpiry 天';
        } else {
          bgColor = context.anchColors.warningSoft;
          borderColor = context.anchColors.warning.withValues(alpha: 0.25);
          iconColor = context.anchColors.warning;
          hintColor = context.anchColors.warning;
          icon = AnchIcons.warning;
          hintText = '保存后将显示即将到期';
        }
        break;
      case ItemExpiryStatus.today:
        bgColor = context.anchColors.dangerSoft;
        borderColor = context.anchColors.danger.withValues(alpha: 0.25);
        iconColor = context.anchColors.danger;
        hintColor = context.anchColors.danger;
        icon = AnchIcons.error;
        hintText = '保存后将显示今日到期';
        break;
      case ItemExpiryStatus.expired:
        bgColor = context.anchColors.dangerSoft;
        borderColor = context.anchColors.danger.withValues(alpha: 0.25);
        iconColor = context.anchColors.danger;
        hintColor = context.anchColors.danger;
        icon = AnchIcons.error;
        hintText = '保存后将显示已过期';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.lg,
        vertical: AnchSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AnchRadius.lg),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          AnchIcon(icon, size: 20, color: iconColor),
          const SizedBox(width: AnchSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '到期状态提示',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.anchColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hintText,
                  style: TextStyle(
                    fontSize: 11,
                    color: hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 全局错误横幅 ──────────────────────────────────────────────

class _GlobalErrorBanner extends StatelessWidget {
  const _GlobalErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: AnchSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.md,
        vertical: AnchSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.anchColors.dangerSoft,
        borderRadius: BorderRadius.circular(AnchRadius.sm),
        border: Border.all(
          color: context.anchColors.danger.withValues(alpha: 0.16),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AnchIcon(AnchIcons.error, size: 15, color: context.anchColors.danger),
          const SizedBox(width: AnchSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: context.anchColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({
    super.key,
    required this.memberId,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String memberId;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AnchSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: AnchChoiceCard(
          title: name,
          leading: ExcludeSemantics(
            child: AnchMemberAvatar(
              memberId: memberId,
              name: name,
              size: 28,
              selected: selected,
            ),
          ),
          selected: selected,
          onTap: onTap,
        ),
      ),
    );
  }
}
