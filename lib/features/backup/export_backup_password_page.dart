import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import '../../core/backup/backup_file_save_service.dart';
import '../../core/backup/backup_file_policy.dart';
import '../../core/backup/backup_unavailable_attachment.dart';
import '../../core/backup/backup_export_progress.dart';
import '../../core/widgets/anch_blocking_progress_overlay.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import 'backup_password_text_form_field.dart';
import '../privacy/privacy_shield_coordinator.dart';
import '../privacy/privacy_shield_controller.dart';
import '../privacy/screen_protection_scope.dart';

/// 导出备份前的密码设置与确认页面原型。
class ExportBackupPasswordPage extends StatefulWidget {
  const ExportBackupPasswordPage({
    super.key,
    this.onExportForTestOrPrototype,
    this.onEstimateOutputForTestOrPrototype,
    this.privacyShieldCoordinator,
  });

  final Future<BackupFileSaveResult> Function(
    String backupPassword,
    BackupExportProgressCallback onProgress,
  )?
  onExportForTestOrPrototype;
  final Future<int> Function()? onEstimateOutputForTestOrPrototype;
  final PrivacyShieldCoordinator? privacyShieldCoordinator;

  @override
  State<ExportBackupPasswordPage> createState() =>
      _ExportBackupPasswordPageState();
}

class _UnavailableAttachmentItemGroup {
  _UnavailableAttachmentItemGroup({required this.itemDisplayName});

  final String itemDisplayName;
  final List<_UnavailableAttachmentReasonGroup> reasonGroups = [];

  int get attachmentCount =>
      reasonGroups.fold(0, (total, group) => total + group.attachments.length);
}

class _UnavailableAttachmentReasonGroup {
  _UnavailableAttachmentReasonGroup({required this.reason});

  final BackupUnavailableAttachmentReason reason;
  final List<BackupUnavailableAttachment> attachments = [];
}

class _ExportBackupPasswordPageState extends State<ExportBackupPasswordPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isExporting = false;
  BackupExportProgress? _exportProgress;
  bool _clearedByLifecycle = false;
  bool _needsTipOnResumed = false;
  bool _wasInActualBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _passwordController.addListener(_updatePrivacyShield);
    _confirmPasswordController.addListener(_updatePrivacyShield);
  }

  void _updatePrivacyShield() {
    // 备份密码在前台输入时不能显示全屏遮罩，否则会阻断第二次确认输入。
    // 系统截图由全局 FLAG_SECURE 防护；进入后台仍由生命周期处理立即清空。
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.backupExport,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.removeListener(_updatePrivacyShield);
    _confirmPasswordController.removeListener(_updatePrivacyShield);
    // ⚠️ 【安全边界】在内存彻底释放前，强力清空 controller 内的密码字符串，防止残留
    _passwordController.clear();
    _confirmPasswordController.clear();

    _passwordController.dispose();
    _confirmPasswordController.dispose();
    if (widget.privacyShieldCoordinator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.privacyShieldCoordinator?.clear(
          source: PrivacyShieldSource.backupExport,
        );
      });
    }
    super.dispose();
  }

  void _showLifecycleClearedDialog() {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            '安全保护已生效',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.anchColors.textPrimary,
            ),
          ),
          content: Text(
            '为保护备份密码，请重新输入后再导出。',
            style: TextStyle(
              fontSize: 13,
              color: context.anchColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '我知道了',
                style: TextStyle(
                  color: context.anchColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearSensitiveInputsForLifecycle() {
    final hasPassword =
        _passwordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;
    if (hasPassword || _isExporting) {
      _needsTipOnResumed = true;
      _clearedByLifecycle = true;
    }
    _passwordController.clear();
    _confirmPasswordController.clear();
    _obscurePassword = true;
    _obscureConfirmPassword = true;
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.backupExport,
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActualBackground =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (isActualBackground) {
      if (!_wasInActualBackground) {
        _wasInActualBackground = true;
        _clearSensitiveInputsForLifecycle();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_wasInActualBackground) return;
      _wasInActualBackground = false;
      // Android SAF 会使应用暂时进入后台；已启动的导出仍在等待系统
      // 选择器结果。此时输入框必须清空，但应由导出结果给出最终反馈，
      // 不能用“请重新输入”覆盖真实的成功或失败状态。
      if (_needsTipOnResumed && !_isExporting) {
        _needsTipOnResumed = false;
        _showLifecycleClearedDialog();
      }
    }
  }

  void _showBlockedDialog() {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            '无法开始导出',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.anchColors.textPrimary,
            ),
          ),
          content: Text(
            '当前无法开始导出，请返回后重新进入。',
            style: TextStyle(
              fontSize: 13,
              color: context.anchColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '我知道了',
                style: TextStyle(
                  color: context.anchColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog(BackupFileSaveResult result) {
    final hasKnownLocation =
        result.displayLocation.trim().isNotEmpty &&
        result.displayLocation != '系统选择的位置';
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final maxDialogHeight = MediaQuery.sizeOf(ctx).height - 48;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
            vertical: AnchSpacing.xl,
          ),
          backgroundColor: context.anchColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AnchRadius.xl),
          ),
          child: ConstrainedBox(
            key: const ValueKey('backup_export_success_dialog'),
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: maxDialogHeight,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactAction =
                      constraints.maxWidth < 360 ||
                      MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                  final action = TextButton(
                    key: const ValueKey('backup_export_success_action'),
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: Text(
                      '我知道了',
                      style: TextStyle(
                        color: context.anchColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '备份文件已交给系统保存',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: context.anchColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.md),
                      Text(
                        '安册已通过系统文件选择器写出备份文件。请确认你已经妥善保存 .abk 文件，并单独保管备份密码。安册不会保存你的备份密码。',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.anchColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.lg),
                      const Divider(),
                      const SizedBox(height: AnchSpacing.lg),
                      Text(
                        '文件名',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.anchColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.xs),
                      Text(
                        result.fileName,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.anchColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.md),
                      Text(
                        '大小',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.anchColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.xs),
                      Text(
                        BackupFilePolicy.formatBytes(result.sizeBytes),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.anchColors.textPrimary,
                        ),
                      ),
                      if (hasKnownLocation) ...[
                        const SizedBox(height: AnchSpacing.md),
                        Text(
                          '保存位置',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.anchColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AnchSpacing.xs),
                        Text(
                          result.displayLocation,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.anchColors.textPrimary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AnchSpacing.xl),
                      const Divider(),
                      const SizedBox(height: AnchSpacing.sm),
                      if (compactAction)
                        SizedBox(width: double.infinity, child: action)
                      else
                        Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<_UnavailableAttachmentItemGroup> _groupUnavailableAttachments(
    List<BackupUnavailableAttachment> attachments,
  ) {
    final groupsByItem = <String, _UnavailableAttachmentItemGroup>{};
    for (final attachment in attachments) {
      final itemId = attachment.itemId?.trim();
      final itemKey = itemId == null || itemId.isEmpty
          ? 'title:${attachment.itemDisplayName}'
          : 'id:$itemId';
      final itemGroup = groupsByItem.putIfAbsent(
        itemKey,
        () => _UnavailableAttachmentItemGroup(
          itemDisplayName: attachment.itemDisplayName,
        ),
      );
      _UnavailableAttachmentReasonGroup? reasonGroup;
      for (final group in itemGroup.reasonGroups) {
        if (group.reason == attachment.reason) {
          reasonGroup = group;
          break;
        }
      }
      final targetGroup =
          reasonGroup ??
          _UnavailableAttachmentReasonGroup(reason: attachment.reason);
      if (reasonGroup == null) {
        itemGroup.reasonGroups.add(targetGroup);
      }
      targetGroup.attachments.add(attachment);
    }
    return groupsByItem.values.toList(growable: false);
  }

  Future<void> _showFailureDialog(Object error) {
    String errorMessage = '导出未完成，请稍后重试。';
    final List<BackupUnavailableAttachment> unavailableAttachments =
        error is BackupFileSaveException
        ? error.unavailableAttachments
        : const [];
    if (error is BackupFileSaveException) {
      switch (error.type) {
        case BackupFileSaveErrorType.userCancelled:
          errorMessage = '导出已取消，未写入备份文件。';
          break;
        case BackupFileSaveErrorType.permissionDenied:
          errorMessage = '系统未授予写入权限，导出未完成。';
          break;
        case BackupFileSaveErrorType.writeFailed:
          errorMessage = '写入中断，未生成有效备份。';
          break;
        case BackupFileSaveErrorType.sourceUnavailable:
          errorMessage = '部分附件不可用，未生成备份。';
          break;
        case BackupFileSaveErrorType.systemPickerUnavailable:
          errorMessage = '当前设备无法打开系统文件选择器。';
          break;
        case BackupFileSaveErrorType.insufficientSpace:
          errorMessage = '存储空间不足，未生成有效备份。';
          break;
        case BackupFileSaveErrorType.preparationFailed:
          errorMessage = '备份加密准备未完成，未写入有效备份。请重试。';
          break;
        case BackupFileSaveErrorType.targetWriteFailed:
        case BackupFileSaveErrorType.storageUnavailable:
          errorMessage = '所选保存位置无法开始写入。请重新选择手机本地文件夹后重试。';
          break;
        case BackupFileSaveErrorType.operationInProgress:
          errorMessage = '上一次文件操作尚未结束。请返回数据与备份页后再试。';
          break;
        case BackupFileSaveErrorType.writeInterrupted:
          errorMessage = '系统保存写入被中断，未生成有效备份。请重新选择保存位置后重试。';
          break;
        case BackupFileSaveErrorType.finalizationFailed:
          errorMessage = '文件写入后无法完成确认，未生成有效备份。';
          break;
        default:
          errorMessage = '导出未完成，请稍后重试。';
          break;
      }
    }

    final unavailableAttachmentGroups = _groupUnavailableAttachments(
      unavailableAttachments,
    );

    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final detailsMaxHeight = (MediaQuery.sizeOf(ctx).height * 0.32)
            .clamp(120.0, 260.0)
            .toDouble();
        return Center(
          child: ConstrainedBox(
            key: const ValueKey('backup_export_failure_dialog'),
            constraints: const BoxConstraints(maxWidth: 480),
            child: AlertDialog(
              title: Text(
                '导出未完成',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.anchColors.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导出流程未完成。若系统已创建文件，它不含最终提交帧，不能用于恢复；应用不会自动删除该文件。',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.anchColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '错误原因: $errorMessage',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.anchColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unavailableAttachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '发现 ${unavailableAttachments.length} 个不可用附件，涉及 ${unavailableAttachmentGroups.length} 条资料。',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.anchColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: detailsMaxHeight),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < unavailableAttachmentGroups.length;
                              index++
                            )
                              Container(
                                key: ValueKey('unavailable_backup_item_$index'),
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.anchColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${unavailableAttachmentGroups[index].itemDisplayName} · ${unavailableAttachmentGroups[index].attachmentCount} 个附件',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.anchColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    for (
                                      var reasonIndex = 0;
                                      reasonIndex <
                                          unavailableAttachmentGroups[index]
                                              .reasonGroups
                                              .length;
                                      reasonIndex++
                                    ) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '${unavailableAttachmentGroups[index].reasonGroups[reasonIndex].attachments.first.reasonTitle} · ${unavailableAttachmentGroups[index].reasonGroups[reasonIndex].attachments.length} 个',
                                        key: ValueKey(
                                          'unavailable_backup_reason_${index}_$reasonIndex',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.anchColors.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      for (final attachment
                                          in unavailableAttachmentGroups[index]
                                              .reasonGroups[reasonIndex]
                                              .attachments)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            '· ${attachment.displayName}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context
                                                  .anchColors
                                                  .textSecondary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    '我知道了',
                    style: TextStyle(
                      color: context.anchColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _finishExporting() {
    if (!mounted || !_isExporting) return;
    setState(() {
      _isExporting = false;
      _exportProgress = null;
      _clearedByLifecycle = false;
    });
  }

  Future<bool> _confirmLargeExportIfNeeded() async {
    final estimateOutput = widget.onEstimateOutputForTestOrPrototype;
    if (estimateOutput == null) return true;

    final estimatedOutputBytes = await estimateOutput();
    if (!BackupFilePolicy.exceedsVerifiedV2Capacity(estimatedOutputBytes)) {
      return true;
    }
    if (!mounted) return false;
    final shouldContinue = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('备份较大'),
        content: const Text('预计备份文件较大，导出可能耗时较长。请保持应用在前台。仍要继续导出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续导出'),
          ),
        ],
      ),
    );
    return shouldContinue ?? false;
  }

  @override
  Widget build(BuildContext context) => ScreenProtectionScope(
    child: PopScope(
      key: const ValueKey('export_backup_pop_scope'),
      canPop: !_isExporting,
      child: Stack(
        children: [
          _buildPage(context),
          if (_exportProgress case final progress?)
            AnchBlockingProgressOverlay(
              title:
                  progress.stage ==
                      BackupExportProgressStage.checkingAttachments
                  ? '正在检查附件'
                  : progress.stage == BackupExportProgressStage.preparing
                  ? '正在准备导出'
                  : '正在导出备份',
              message: progress.stage == BackupExportProgressStage.finalizing
                  ? '正在确认文件完整性，请保持应用在前台'
                  : progress.stage ==
                        BackupExportProgressStage.checkingAttachments
                  ? '已检查 ${progress.completedAttachments ?? 0}／${progress.totalAttachments ?? 0} 个附件，请保持应用在前台'
                  : progress.stage == BackupExportProgressStage.preparing
                  ? '正在准备加密，请保持应用在前台'
                  : '正在加密并写入文件，请保持应用在前台',
              progress:
                  progress.stage == BackupExportProgressStage.preparing ||
                      progress.stage ==
                          BackupExportProgressStage.checkingAttachments
                  ? null
                  : progress.fraction,
              semanticsLabel:
                  progress.stage ==
                      BackupExportProgressStage.checkingAttachments
                  ? '正在检查附件，请勿退出'
                  : '正在导出备份，请勿退出',
              barrierKey: const ValueKey('export_backup_loading_barrier'),
            ),
        ],
      ),
    ),
  );

  Widget _buildPage(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.vertical;
    final collapseHeader =
        mediaQuery.viewInsets.bottom > 0 && availableHeight < 200;
    return AnchAppScaffold(
      appBar: collapseHeader
          ? null
          : AnchSubpageAppBar(
              title: '导出备份',
              foregroundColor: context.anchColors.textPrimary,
              backgroundColor: Colors.transparent,
              onBack: _isExporting ? null : () => Navigator.pop(context),
              systemOverlayStyle:
                  (Theme.of(context).brightness == Brightness.dark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark)
                      .copyWith(statusBarColor: Colors.transparent),
            ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // 1. 顶部安全提示
            if (RuntimeScope.of(context).isDevMode)
              const AnchSecurityBanner(
                message: AnchSecurityBanner.devModeMessage,
                type: AnchBannerType.warning,
              ),
            const SizedBox(height: AnchSpacing.sm),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AnchSpacing.page,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. 安全告知卡片
                      _buildSectionCard(
                        title: '备份安全提示',
                        icon: AnchIcons.security,
                        bullets: const [
                          '本次备份使用下方密码加密，安册不会保存密码。',
                          '忘记密码将无法恢复，请与备份文件分开保存。',
                        ],
                      ),
                      const SizedBox(height: AnchSpacing.lg),

                      // 3. 密码输入框
                      Text(
                        '备份密码',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.anchColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.xs),
                      BackupPasswordTextFormField(
                        controller: _passwordController,
                        enabled: !_isExporting,
                        onChanged: (val) {
                          if (_clearedByLifecycle && val.isNotEmpty) {
                            _clearedByLifecycle = false;
                          }
                        },
                        obscureText: _obscurePassword,
                        hintText: '输入密码',
                        helperText: '至少 8 位',
                        onToggleVisibility: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                        // ⚠️ 密码本体不自动 trim，但校验时拒绝全空白密码
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              value.trim().isEmpty) {
                            return '请输入备份密码';
                          }
                          if (value.length < 8) {
                            return '密码长度至少为 8 位';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AnchSpacing.md),

                      // 4. 再次输入密码框
                      Text(
                        '再次输入备份密码',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.anchColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.xs),
                      BackupPasswordTextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isExporting,
                        onChanged: (val) {
                          if (_clearedByLifecycle && val.isNotEmpty) {
                            _clearedByLifecycle = false;
                          }
                        },
                        obscureText: _obscureConfirmPassword,
                        hintText: '确认密码',
                        onToggleVisibility: () => setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        }),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              value.trim().isEmpty) {
                            return '请再次输入备份密码';
                          }
                          if (value != _passwordController.text) {
                            return '两次输入的密码不一致';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AnchSpacing.lg),

                      // 6. 主操作按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.anchColors.accent,
                            foregroundColor: context.anchColors.accentInk,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AnchRadius.md,
                              ),
                            ),
                          ),
                          onPressed: _isExporting
                              ? null
                              : () async {
                                  if (_isExporting) return;
                                  if (_formKey.currentState!.validate()) {
                                    if (widget.onExportForTestOrPrototype ==
                                        null) {
                                      _showBlockedDialog();
                                    } else {
                                      setState(() {
                                        _isExporting = true;
                                      });
                                      try {
                                        final shouldContinue =
                                            await _confirmLargeExportIfNeeded();
                                        if (!mounted ||
                                            !shouldContinue ||
                                            _clearedByLifecycle) {
                                          return;
                                        }
                                        final password =
                                            _passwordController.text;
                                        final result =
                                            await widget
                                                .onExportForTestOrPrototype!(
                                              password,
                                              (progress) {
                                                if (!mounted) return;
                                                setState(() {
                                                  _exportProgress = progress;
                                                });
                                              },
                                            );
                                        if (mounted) {
                                          _passwordController.clear();
                                          _confirmPasswordController.clear();
                                          _needsTipOnResumed = false;
                                          _clearedByLifecycle = false;
                                          _finishExporting();
                                          await _showSuccessDialog(result);
                                        }
                                        if (mounted) {
                                          Navigator.of(
                                            this.context,
                                          ).pop(result);
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          _needsTipOnResumed = false;
                                          _clearedByLifecycle = false;
                                          _finishExporting();
                                          await _showFailureDialog(e);
                                        }
                                      } finally {
                                        _finishExporting();
                                      }
                                    }
                                  }
                                },
                          child: Text(
                            _isExporting ? '正在验证导出流程...' : '继续导出',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // 预留足够的底部 padding，防键盘遮挡
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required AnchIconData icon,
    required List<String> bullets,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AnchSpacing.lg),
      decoration: BoxDecoration(
        color: context.anchColors.surface,
        borderRadius: BorderRadius.circular(AnchRadius.lg),
        border: Border.all(color: context.anchColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnchIcon(icon, size: 20, color: context.anchColors.accentDeep),
              const SizedBox(width: AnchSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.anchColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AnchSpacing.md),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: AnchSpacing.xs),
              child: Text(
                b,
                style: TextStyle(
                  fontSize: 13,
                  color: context.anchColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
