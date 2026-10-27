import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_blocking_progress_overlay.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import 'backup_password_text_form_field.dart';
import '../../core/backup/backup_file_read_service.dart';
import '../../core/backup/backup_file_policy.dart';
import '../../core/backup/backup_file_restore_preview_coordinator.dart';
import '../../core/backup/backup_file_restore_decrypt_preview_coordinator.dart';
import '../../core/backup/backup_file_restore_apply_coordinator.dart';
import '../../core/backup/backup_package_content_preview.dart';
import '../../core/backup/backup_restore_progress.dart';
import '../../core/template/template_registry.dart';
import '../privacy/privacy_shield_coordinator.dart';
import '../privacy/privacy_shield_controller.dart';
import '../privacy/screen_protection_scope.dart';

/// 恢复备份前的密码输入与确认页面。
class RestoreBackupPasswordPage extends StatefulWidget {
  const RestoreBackupPasswordPage({
    super.key,
    this.onPreview,
    this.onSelectFile,
    this.onDecryptPreview,
    this.onApplyRestore,
    this.onApplyRestoreWithProgress,
    this.onClearPreparedRestoreFile,
    this.privacyShieldCoordinator,
    this.directRestore = false,
    this.preparedFileSizeLabel,
  });

  final Future<BackupFileRestorePreviewResult> Function()? onPreview;
  final Future<BackupFileRestorePreviewResult> Function()? onSelectFile;
  final Future<BackupFileRestoreDecryptPreviewResult> Function(
    String backupPassword,
  )?
  onDecryptPreview;
  final Future<BackupFileRestoreApplyResult> Function(String backupPassword)?
  onApplyRestore;
  final Future<BackupFileRestoreApplyResult> Function(
    String backupPassword,
    BackupRestoreProgressCallback onProgress,
  )?
  onApplyRestoreWithProgress;
  final VoidCallback? onClearPreparedRestoreFile;
  final PrivacyShieldCoordinator? privacyShieldCoordinator;
  final bool directRestore;
  final String? preparedFileSizeLabel;

  @override
  State<RestoreBackupPasswordPage> createState() =>
      _RestoreBackupPasswordPageState();
}

class _RestoreBackupPasswordPageState extends State<RestoreBackupPasswordPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _confirmRisk = false;
  bool _isVerifying = false;
  bool _isApplying = false;
  bool _clearedByLifecycle = false;
  bool _needsTipOnResumed = false;
  bool _hasPreparedRestore = false;
  bool _hasDecryptedRestorePreview = false;
  bool _isSelectingFile = false;
  bool _isReturningFromFilePicker = false;
  bool _wasInActualBackground = false;
  bool _isDecryptPreviewDialogOpen = false;
  bool _isConfirmRestoreDialogOpen = false;
  bool _requiresFileReselection = false;
  bool _requiresPasswordReentry = false;
  bool _requiresFullVerificationOnApply = false;
  String? _preparedFileSizeLabel;
  BackupRestoreProgress? _restoreProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _passwordController.addListener(_updatePrivacyShield);
    _preparedFileSizeLabel = widget.preparedFileSizeLabel;
    _hasPreparedRestore = _preparedFileSizeLabel != null;
  }

  Future<void> _selectRestoreFile() async {
    final selectFile = widget.onSelectFile;
    if (selectFile == null || _isVerifying) return;

    widget.onClearPreparedRestoreFile?.call();
    _passwordController.clear();
    setState(() {
      _isVerifying = true;
      _isSelectingFile = true;
      _preparedFileSizeLabel = null;
      _hasPreparedRestore = false;
      _hasDecryptedRestorePreview = false;
      _requiresFullVerificationOnApply = false;
      _restoreProgress = null;
      _requiresFileReselection = false;
    });
    try {
      final preview = await selectFile();
      if (!mounted) return;
      setState(() {
        _preparedFileSizeLabel = preview.sizeLabel;
        _hasPreparedRestore = true;
        _clearedByLifecycle = false;
        _requiresFileReselection = false;
        _requiresPasswordReentry = false;
      });
    } on BackupFileRestoreDecryptPreviewException catch (error) {
      if (!mounted ||
          error.type ==
              BackupFileRestoreDecryptPreviewErrorType.userCancelled) {
        return;
      }
      _showFileSelectionFailureDialog(error);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isSelectingFile = false;
        });
      }
    }
  }

  void _showFileSelectionFailureDialog(
    BackupFileRestoreDecryptPreviewException error,
  ) {
    final message = switch (error.type) {
      BackupFileRestoreDecryptPreviewErrorType.fileTooLarge => '备份文件过大，暂不支持恢复。',
      BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat =>
        '备份文件格式不正确或已损坏。',
      _ => '备份文件读取失败。',
    };
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('无法选择备份文件'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _updatePrivacyShield() {
    // 前台恢复输入及确认对话框必须可操作，不能由全屏遮罩阻断。
    // 系统截图仍由全局 FLAG_SECURE 防护；进入后台仍会立即清空密码。
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.backupRestore,
    );
  }

  void _restoreOrClearPrivacyShield() {
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.restoreConfirming,
    );
    _updatePrivacyShield();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.removeListener(_updatePrivacyShield);
    // ⚠️ 【安全边界】在内存释放前，强力清空 controller 内的密码字符串，防止残留
    _passwordController.clear();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    widget.onClearPreparedRestoreFile?.call();
    if (widget.privacyShieldCoordinator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.privacyShieldCoordinator?.clear(
          source: PrivacyShieldSource.backupRestore,
        );
        widget.privacyShieldCoordinator?.clear(
          source: PrivacyShieldSource.restoreConfirming,
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
            _requiresFileReselection
                ? '为保护备份内容，请重新选择备份文件并输入密码后再继续恢复。'
                : '为保护备份密码，请重新输入后再继续恢复。',
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
    // 系统文件选择器会让应用短暂经过后台生命周期；此时恢复页已在发起
    // 选择前清空密码且尚未持有文件内容，不能误判为需要中断恢复的后台。
    if (_isSelectingFile) return;
    final preserveInFlight = _isVerifying || _isApplying;
    final hasPassword = _passwordController.text.isNotEmpty;
    final hadConfirmRisk = _confirmRisk;
    final hadPreparedRestore = _hasPreparedRestore;
    if (hasPassword ||
        hadConfirmRisk ||
        preserveInFlight ||
        hadPreparedRestore) {
      _needsTipOnResumed = true;
      _clearedByLifecycle = true;
    }
    _passwordController.clear();
    _confirmRisk = false;
    if (!_isSelectingFile &&
        !_isApplying &&
        (hadPreparedRestore ||
            (_isVerifying && !_isApplying) ||
            _hasDecryptedRestorePreview)) {
      _discardPreparedRestoreSession(
        requireFileReselection: hadPreparedRestore,
      );
      _dismissSensitiveRestoreDialog();
    }
    if (preserveInFlight) {
      _requiresPasswordReentry = true;
    } else {
      _isVerifying = false;
      _isApplying = false;
      _requiresPasswordReentry =
          _requiresPasswordReentry || hasPassword || hadConfirmRisk;
      if (!_hasPreparedRestore) {
        widget.onClearPreparedRestoreFile?.call();
      }
    }
    _obscurePassword = true;
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.backupRestore,
    );
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.restoreConfirming,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _discardPreparedRestoreSession({bool requireFileReselection = false}) {
    _hasPreparedRestore = false;
    _hasDecryptedRestorePreview = false;
    _preparedFileSizeLabel = null;
    _requiresFullVerificationOnApply = false;
    _restoreProgress = null;
    _requiresPasswordReentry = false;
    _requiresFileReselection =
        _requiresFileReselection || requireFileReselection;
    widget.onClearPreparedRestoreFile?.call();
  }

  bool _isPasswordRetryableFailure(Object error) =>
      error is BackupFileRestoreDecryptPreviewException &&
      error.type ==
          BackupFileRestoreDecryptPreviewErrorType
              .invalidPasswordOrCorruptedData;

  void _handleDecryptPreviewFailure(Object error) {
    if (_isPasswordRetryableFailure(error)) {
      _passwordController.clear();
      setState(() {
        _obscurePassword = true;
        _hasDecryptedRestorePreview = false;
        _requiresPasswordReentry = false;
      });
    } else {
      _discardPreparedRestoreSession();
    }
    _showFailureDecryptPreviewDialog(error);
  }

  void _dismissSensitiveRestoreDialog() {
    if (!_isDecryptPreviewDialogOpen && !_isConfirmRestoreDialogOpen) return;
    _isDecryptPreviewDialogOpen = false;
    _isConfirmRestoreDialogOpen = false;
    Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActualBackground =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (isActualBackground) {
      if (_isSelectingFile || _isReturningFromFilePicker) {
        _isReturningFromFilePicker = true;
        return;
      }
      if (!_wasInActualBackground) {
        _wasInActualBackground = true;
        _clearSensitiveInputsForLifecycle();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isSelectingFile || _isReturningFromFilePicker) {
        _isReturningFromFilePicker = false;
        return;
      }
      if (!_wasInActualBackground) return;
      _wasInActualBackground = false;
      if (_needsTipOnResumed && (!_isVerifying || _isApplying)) {
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
            '无法开始恢复',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.anchColors.textPrimary,
            ),
          ),
          content: Text(
            '当前无法开始恢复，请返回后重新进入。',
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

  void _showSuccessPreviewDialog(BackupFileRestorePreviewResult result) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            '备份文件格式校验通过',
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
                '已读取并识别备份文件格式。输入备份密码后可继续验证并确认覆盖恢复。',
                style: TextStyle(
                  fontSize: 13,
                  color: context.anchColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.anchColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: context.anchColors.divider,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '大小: ${result.sizeLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.anchColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '来源: ${result.displaySource}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.anchColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '外壳版本: V${result.envelopeVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.anchColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '负载版本: V${result.payloadVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.anchColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '算法: ${result.cipherName} (${result.kdfName})',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.anchColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
        );
      },
    );
  }

  void _showFailurePreviewDialog(Object error) {
    String errorMessage = '备份文件无法读取，请稍后重试。';
    if (error is BackupFileReadException) {
      switch (error.type) {
        case BackupFileReadErrorType.userCancelled:
          errorMessage = '已取消选择备份文件。';
          break;
        case BackupFileReadErrorType.fileTooLarge:
          errorMessage = '备份文件过大，暂不支持读取。';
          break;
        case BackupFileReadErrorType.invalidFile:
          errorMessage = '备份文件格式不正确或已损坏。';
          break;
        case BackupFileReadErrorType.readFailed:
          errorMessage = '备份文件读取失败。';
          break;
        case BackupFileReadErrorType.systemPickerUnavailable:
          errorMessage = '当前设备无法打开系统文件选择器。';
          break;
        default:
          errorMessage = '备份文件无法读取，请稍后重试。';
          break;
      }
    }
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            '备份文件读取失败',
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
                '错误原因: $errorMessage',
                style: TextStyle(
                  fontSize: 13,
                  color: context.anchColors.danger,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
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
        );
      },
    );
  }

  void _showSuccessDecryptPreviewDialog(
    BackupFileRestoreDecryptPreviewResult result,
  ) {
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.restoreConfirming,
    );
    _isDecryptPreviewDialogOpen = true;
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final screenSize = MediaQuery.sizeOf(ctx);
        final dialogWidth = screenSize.width > 712
            ? 680.0
            : screenSize.width - 32.0;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            key: const ValueKey('restore_content_preview_dialog'),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: Text(
              '备份密码验证通过',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.anchColors.textPrimary,
              ),
            ),
            content: SizedBox(
              width: dialogWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenSize.height * 0.68,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.requiresFullVerificationOnApply
                            ? '已验证备份密码并读取恢复范围。确认后会完整校验备份并准备附件，再整包覆盖当前数据。'
                            : '已验证备份密码。请先核对以下恢复范围；确认后会整包覆盖当前数据。',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.anchColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (BackupFilePolicy.exceedsVerifiedV2Capacity(
                        result.sizeBytes,
                      )) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.anchColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: context.anchColors.divider,
                            ),
                          ),
                          child: Text(
                            '此备份文件较大，恢复可能耗时较长。可以继续恢复；请保持应用在前台。',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.anchColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildDecryptPreviewSummary(result),
                      const SizedBox(height: 16),
                      _buildRestoreContentPreview(result.contentPreview),
                    ],
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  _isDecryptPreviewDialogOpen = false;
                  Navigator.of(ctx).pop();
                  setState(() {
                    _discardPreparedRestoreSession();
                  });
                  _restoreOrClearPrivacyShield();
                },
                child: Text(
                  '取消',
                  style: TextStyle(color: context.anchColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  _isDecryptPreviewDialogOpen = false;
                  Navigator.of(ctx).pop();
                  if (_requiresPasswordReentry) {
                    _showLifecycleClearedDialog();
                    return;
                  }
                  if (widget.directRestore) {
                    _applyRestore();
                  } else {
                    _showConfirmRestoreDialog();
                  }
                },
                child: Text(
                  widget.directRestore ? '确认覆盖恢复' : '继续覆盖恢复',
                  style: TextStyle(
                    color: widget.directRestore
                        ? context.anchColors.danger
                        : context.anchColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _isDecryptPreviewDialogOpen = false;
    });
  }

  Widget _buildDecryptPreviewSummary(
    BackupFileRestoreDecryptPreviewResult result,
  ) {
    final lines = <String>[
      '文件大小：${result.sizeLabel}',
      '成员数量：${result.membersCount}',
      '资料数量：${result.itemsCount}',
      '附件数量：${result.contentPreview.attachmentCount}',
      '字段数量：${result.itemFieldsCount}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.anchColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.anchColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 12,
                  color: context.anchColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRestoreContentPreview(BackupPackageContentPreview preview) {
    if (preview.isEmpty) {
      return Text(
        '此备份不包含资料。',
        style: TextStyle(fontSize: 13, color: context.anchColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '将恢复的资料',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: context.anchColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final member in preview.members)
          _buildRestoreContentGroup(member.displayName, member.items),
        if (preview.unassignedItems.isNotEmpty)
          _buildRestoreContentGroup('未归属资料', preview.unassignedItems),
      ],
    );
  }

  Widget _buildRestoreContentGroup(
    String displayName,
    List<BackupPackageItemPreview> items,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.anchColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.anchColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$displayName · ${items.length} 条资料',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.anchColors.textPrimary,
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '未包含资料',
                style: TextStyle(
                  fontSize: 12,
                  color: context.anchColors.textSecondary,
                ),
              ),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _restorePreviewTitle(item),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.anchColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_restorePreviewTypeLabel(item)} · '
                    '${_restorePreviewStatusLabel(item.status)} · '
                    '${item.attachmentCount} 个附件',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.anchColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _restorePreviewTitle(BackupPackageItemPreview item) {
    final title = item.title?.trim();
    return title == null || title.isEmpty ? '未命名资料' : title;
  }

  String _restorePreviewTypeLabel(BackupPackageItemPreview item) {
    final typeKey = item.typeKey;
    if (typeKey == null || typeKey.isEmpty) return '历史／未知类型';
    return TemplateRegistry.getTemplate(typeKey, item.templateVersion)?.label ??
        TemplateRegistry.getTemplate(typeKey)?.label ??
        '历史／未知类型';
  }

  String _restorePreviewStatusLabel(BackupPackageItemPreviewStatus status) {
    return switch (status) {
      BackupPackageItemPreviewStatus.active => '当前资料',
      BackupPackageItemPreviewStatus.archived => '已归档',
      BackupPackageItemPreviewStatus.deleted => '最近删除',
      BackupPackageItemPreviewStatus.unknown => '未知状态',
    };
  }

  void _showConfirmRestoreDialog() {
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.restoreConfirming,
    );
    _isConfirmRestoreDialogOpen = true;
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              '确认覆盖恢复？',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.anchColors.textPrimary,
              ),
            ),
            content: Text(
              '恢复会清空当前已有资料，并使用备份内容完整覆盖。确认前请核对恢复范围；恢复失败时，当前资料不会被替换。',
              style: TextStyle(
                fontSize: 13,
                color: context.anchColors.textSecondary,
                height: 1.4,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _discardPreparedRestoreSession();
                  });
                  _restoreOrClearPrivacyShield();
                },
                child: Text(
                  '取消',
                  style: TextStyle(color: context.anchColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (_clearedByLifecycle) {
                    _showLifecycleClearedDialog();
                    return;
                  }
                  _applyRestore();
                },
                child: Text(
                  '确认覆盖恢复',
                  style: TextStyle(
                    color: context.anchColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _isConfirmRestoreDialogOpen = false;
    });
  }

  Future<void> _applyRestore() async {
    final applyRestore = widget.onApplyRestore;
    final applyRestoreWithProgress = widget.onApplyRestoreWithProgress;
    if (_requiresFullVerificationOnApply
        ? applyRestoreWithProgress == null
        : applyRestore == null) {
      return;
    }
    if (_clearedByLifecycle) {
      _showLifecycleClearedDialog();
      return;
    }
    _passwordFocusNode.unfocus();
    _passwordFocusNode.canRequestFocus = false;
    setState(() {
      _isVerifying = true;
      _isApplying = true;
      _restoreProgress = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    try {
      final password = _passwordController.text;
      final result = _requiresFullVerificationOnApply
          ? await applyRestoreWithProgress!(password, (progress) {
              if (!mounted || !_isApplying) return;
              setState(() {
                _restoreProgress = progress;
              });
            })
          : await applyRestore!(password);
      if (mounted) {
        if (_clearedByLifecycle) {
          _showLifecycleClearedDialog();
          return;
        }
        _showSuccessApplyDialog(result);
      }
    } catch (e) {
      if (mounted) {
        if (_clearedByLifecycle) {
          _showLifecycleClearedDialog();
          return;
        }
        _showFailureApplyDialog(e);
      }
    } finally {
      if (mounted) {
        _passwordFocusNode.canRequestFocus = true;
        setState(() {
          _isVerifying = false;
          _isApplying = false;
          _clearedByLifecycle = false;
          _hasPreparedRestore = false;
          _hasDecryptedRestorePreview = false;
          _preparedFileSizeLabel = null;
          _requiresFullVerificationOnApply = false;
          _restoreProgress = null;
        });
        widget.onClearPreparedRestoreFile?.call();
      }
    }
  }

  Future<void> _verifyAndShowDirectRestorePreview() async {
    final decryptPreview = widget.onDecryptPreview;
    final applyRestore = widget.onApplyRestore;
    final applyRestoreWithProgress = widget.onApplyRestoreWithProgress;
    if (decryptPreview == null ||
        (applyRestore == null && applyRestoreWithProgress == null)) {
      return;
    }
    if (_clearedByLifecycle) {
      _showLifecycleClearedDialog();
      return;
    }

    setState(() {
      _isVerifying = true;
      // 选择器返回后的生命周期保护只覆盖系统选择阶段。一旦用户已主动
      // 发起密码验证，后续后台必须按敏感恢复会话处理，不能再被旧标记跳过。
      _isReturningFromFilePicker = false;
    });
    final password = _passwordController.text;
    try {
      final result = await decryptPreview(password);
      if (!mounted || _clearedByLifecycle) {
        if (mounted) _showLifecycleClearedDialog();
        return;
      }
      setState(() {
        _hasPreparedRestore = true;
        _hasDecryptedRestorePreview = true;
        _needsTipOnResumed = false;
        _clearedByLifecycle = false;
        _requiresFullVerificationOnApply =
            result.requiresFullVerificationOnApply;
      });
      _showSuccessDecryptPreviewDialog(result);
    } on BackupFileRestoreDecryptPreviewException catch (error) {
      if (mounted) {
        _handleDecryptPreviewFailure(error);
      }
    } catch (error) {
      if (mounted) {
        _discardPreparedRestoreSession();
        _showFailureDecryptPreviewDialog(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _clearedByLifecycle = false;
        });
      }
    }
  }

  void _showSuccessApplyDialog(BackupFileRestoreApplyResult result) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            widget.directRestore ? '恢复完成' : '恢复验证完成',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.anchColors.textPrimary,
            ),
          ),
          content: Text(
            widget.directRestore ? '备份已恢复。请返回首页核对资料与附件。' : '备份已恢复。请返回首页核对资料。',
            style: TextStyle(
              fontSize: 13,
              color: context.anchColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
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

  void _showFailureApplyDialog(Object error) {
    String errorMessage = '恢复失败，请稍后重试。';
    if (error is BackupFileRestoreApplyException) {
      switch (error.type) {
        case BackupFileRestoreApplyErrorType.userCancelled:
          errorMessage = '已取消选择备份文件。';
          break;
        case BackupFileRestoreApplyErrorType.fileTooLarge:
          errorMessage = '备份文件过大，暂不支持恢复。';
          break;
        case BackupFileRestoreApplyErrorType.invalidFileFormat:
          errorMessage = '备份文件格式不正确或已损坏。';
          break;
        case BackupFileRestoreApplyErrorType.invalidPasswordOrCorruptedData:
          errorMessage = '备份密码不正确，或备份文件已损坏。';
          break;
        case BackupFileRestoreApplyErrorType.unsupportedPayloadVersion:
        case BackupFileRestoreApplyErrorType.unsupportedSchemaVersion:
        case BackupFileRestoreApplyErrorType.invalidPayload:
          errorMessage = '当前版本暂不支持此备份文件。';
          break;
        case BackupFileRestoreApplyErrorType.importValidationFailed:
          errorMessage = '备份内容校验失败，未执行恢复。';
          break;
        case BackupFileRestoreApplyErrorType.importTransactionFailed:
          errorMessage = '恢复过程中发生错误，当前数据不应被破坏。';
          break;
        default:
          errorMessage = '恢复失败，请稍后重试。';
          break;
      }
    }
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            '恢复失败',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.anchColors.textPrimary,
            ),
          ),
          content: Text(
            errorMessage,
            style: TextStyle(
              fontSize: 13,
              color: context.anchColors.danger,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _restoreOrClearPrivacyShield();
              },
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

  void _showFailureDecryptPreviewDialog(Object error) {
    String errorMessage = '备份文件无法验证，请稍后重试。';
    if (error is BackupFileRestoreDecryptPreviewException) {
      switch (error.type) {
        case BackupFileRestoreDecryptPreviewErrorType.userCancelled:
          errorMessage = '已取消选择备份文件。';
          break;
        case BackupFileRestoreDecryptPreviewErrorType.fileTooLarge:
          errorMessage = '备份文件过大，暂不支持读取。';
          break;
        case BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat:
          errorMessage = '备份文件格式不正确或已损坏。';
          break;
        case BackupFileRestoreDecryptPreviewErrorType
            .invalidPasswordOrCorruptedData:
          errorMessage = '备份密码不正确，或备份文件已损坏。';
          break;
        case BackupFileRestoreDecryptPreviewErrorType.unsupportedPayloadVersion:
        case BackupFileRestoreDecryptPreviewErrorType.unsupportedSchemaVersion:
        case BackupFileRestoreDecryptPreviewErrorType.invalidPayload:
          errorMessage = '当前版本暂不支持此备份文件。';
          break;
        case BackupFileRestoreDecryptPreviewErrorType.fileReadFailed:
          errorMessage = '备份文件读取失败。';
          break;
        default:
          errorMessage = '备份文件无法验证，请稍后重试。';
          break;
      }
    }
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            widget.directRestore ? '无法恢复备份' : '备份密码验证失败',
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
                errorMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: context.anchColors.danger,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      ScreenProtectionScope(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.vertical;
    final collapseHeader =
        mediaQuery.viewInsets.bottom > 0 && availableHeight < 200;
    return PopScope(
      canPop: !_isApplying,
      child: Stack(
        children: [
          AnchAppScaffold(
            appBar: collapseHeader
                ? null
                : AnchSubpageAppBar(
                    title: '恢复备份',
                    foregroundColor: context.anchColors.textPrimary,
                    backgroundColor: Colors.transparent,
                    onBack: () => Navigator.pop(context),
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
                            // 2. 覆盖风险确认卡片
                            _buildRiskCard(),
                            if (widget.directRestore) ...[
                              const SizedBox(height: AnchSpacing.md),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AnchSpacing.md),
                                decoration: BoxDecoration(
                                  color: context.anchColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AnchRadius.md,
                                  ),
                                  border: Border.all(
                                    color: context.anchColors.divider,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _preparedFileSizeLabel == null
                                            ? '尚未选择备份文件'
                                            : '已选择备份文件 · $_preparedFileSizeLabel',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              context.anchColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AnchSpacing.sm),
                                    TextButton(
                                      onPressed: _isVerifying
                                          ? null
                                          : _selectRestoreFile,
                                      child: Text(
                                        _preparedFileSizeLabel == null
                                            ? '选择文件'
                                            : '重新选择',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (!widget.directRestore ||
                                _hasPreparedRestore) ...[
                              const SizedBox(height: AnchSpacing.lg),

                              // 3. 密码输入框标签
                              Text(
                                '备份密码',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: context.anchColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AnchSpacing.xs),

                              // 4. 密码输入框
                              BackupPasswordTextFormField(
                                key: ValueKey(
                                  'restore_password_field_cleared_$_clearedByLifecycle',
                                ),
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                enabled: !_isApplying,
                                onChanged: (val) {
                                  if (_clearedByLifecycle && val.isNotEmpty) {
                                    _clearedByLifecycle = false;
                                    _requiresPasswordReentry = false;
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
                              const SizedBox(height: AnchSpacing.lg),

                              // 5. 覆盖风险确认组件
                              if (!widget.directRestore)
                                FormField<bool>(
                                  key: ValueKey(
                                    'confirm_risk_field_cleared_$_clearedByLifecycle',
                                  ),
                                  initialValue: _confirmRisk,
                                  validator: (value) {
                                    if (value != true) {
                                      return '请先确认你理解覆盖恢复风险';
                                    }
                                    return null;
                                  },
                                  builder: (FormFieldState<bool> state) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CheckboxListTile(
                                          title: Text(
                                            '我理解恢复备份会覆盖当前已有资料',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: context
                                                  .anchColors
                                                  .textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          value: state.value,
                                          onChanged: (val) {
                                            state.didChange(val);
                                            setState(() {
                                              _confirmRisk = val ?? false;
                                            });
                                          },
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          contentPadding: EdgeInsets.zero,
                                          activeColor:
                                              context.anchColors.accent,
                                          dense: true,
                                        ),
                                        if (state.hasError)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                              left: 12,
                                            ),
                                            child: Text(
                                              state.errorText!,
                                              style: TextStyle(
                                                color:
                                                    context.anchColors.danger,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              SizedBox(
                                height: widget.directRestore
                                    ? AnchSpacing.lg
                                    : AnchSpacing.xl,
                              ),

                              // 6. 继续恢复操作按钮
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.anchColors.accent,
                                    foregroundColor:
                                        context.anchColors.accentInk,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AnchRadius.md,
                                      ),
                                    ),
                                  ),
                                  onPressed: _isVerifying
                                      ? null
                                      : () async {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            if (widget.directRestore) {
                                              await _verifyAndShowDirectRestorePreview();
                                            } else if (_hasPreparedRestore) {
                                              setState(() {
                                                _requiresPasswordReentry =
                                                    false;
                                              });
                                              _showConfirmRestoreDialog();
                                            } else if (widget
                                                    .onDecryptPreview !=
                                                null) {
                                              setState(() {
                                                _isVerifying = true;
                                              });
                                              try {
                                                final password =
                                                    _passwordController.text;
                                                final result =
                                                    await widget
                                                        .onDecryptPreview!(
                                                      password,
                                                    );
                                                if (mounted) {
                                                  if (_clearedByLifecycle) {
                                                    _showLifecycleClearedDialog();
                                                    return;
                                                  }
                                                  setState(() {
                                                    _hasPreparedRestore = true;
                                                    _hasDecryptedRestorePreview =
                                                        true;
                                                    _needsTipOnResumed = false;
                                                    _clearedByLifecycle = false;
                                                  });
                                                  _showSuccessDecryptPreviewDialog(
                                                    result,
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  _handleDecryptPreviewFailure(
                                                    e,
                                                  );
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isVerifying = false;
                                                    _clearedByLifecycle = false;
                                                  });
                                                }
                                              }
                                            } else if (widget.onPreview !=
                                                null) {
                                              setState(() {
                                                _isVerifying = true;
                                              });
                                              try {
                                                final result =
                                                    await widget.onPreview!();
                                                if (mounted) {
                                                  _needsTipOnResumed = false;
                                                  _clearedByLifecycle = false;
                                                  _showSuccessPreviewDialog(
                                                    result,
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  widget
                                                      .onClearPreparedRestoreFile
                                                      ?.call();
                                                  _showFailurePreviewDialog(e);
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isVerifying = false;
                                                    _clearedByLifecycle = false;
                                                  });
                                                }
                                              }
                                            } else {
                                              _showBlockedDialog();
                                            }
                                          }
                                        },
                                  child: Text(
                                    _isVerifying
                                        ? (_isApplying
                                              ? (widget.directRestore
                                                    ? '正在恢复...'
                                                    : '正在覆盖恢复...')
                                              : (widget.onDecryptPreview != null
                                                    ? (widget.directRestore
                                                          ? '正在验证...'
                                                          : '正在验证备份密码...')
                                                    : '正在验证备份文件...'))
                                        : (widget.directRestore
                                              ? '确定恢复'
                                              : '继续恢复'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
          ),
          if (_isVerifying && !_isApplying && !_isSelectingFile)
            _buildVerificationOverlay(),
          if (_isApplying) _buildApplyRestoreOverlay(),
        ],
      ),
    );
  }

  Widget _buildVerificationOverlay() {
    return const AnchBlockingProgressOverlay(
      title: '正在验证备份',
      message: '正在验证密码并读取恢复范围，请保持应用在前台',
      progress: null,
      semanticsLabel: '正在验证备份，请勿退出',
      barrierKey: ValueKey('restore_verification_loading_barrier'),
    );
  }

  Widget _buildApplyRestoreOverlay() {
    final progress = _restoreProgress;
    final isStaging = progress?.stage == BackupRestoreProgressStage.staging;
    return AnchBlockingProgressOverlay(
      title: isStaging ? '正在准备恢复附件' : '正在恢复备份',
      message: isStaging ? '正在读取并校验备份文件，请保持应用在前台' : '正在应用恢复内容，请保持应用在前台',
      progress: isStaging ? progress?.fraction : null,
      semanticsLabel: isStaging ? '正在准备恢复附件，请勿退出' : '正在覆盖恢复，请勿退出',
      barrierKey: const ValueKey('restore_apply_loading_barrier'),
    );
  }

  Widget _buildRiskCard() {
    final bullets = [
      '恢复备份会覆盖当前 App 内已有资料。选择 .abk 文件并验证密码、核对清单后，再确认覆盖。',
      '密码错误、文件损坏或版本不兼容时无法恢复。安册不会保存备份密码。',
    ];

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
              AnchIcon(
                AnchIcons.danger,
                size: 20,
                color: context.anchColors.danger,
              ),
              SizedBox(width: AnchSpacing.sm),
              Expanded(
                child: Text(
                  '覆盖恢复风险',
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
