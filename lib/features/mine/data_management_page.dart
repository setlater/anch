import 'dart:async';
import '../../core/backup/backup_file_save_service.dart';
import '../../core/backup/backup_history_manager.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import '../../app/app_metadata.dart';
import '../../core/backup/backup_export_service.dart';
import '../../core/backup/backup_v2_file_export_coordinator.dart';
import '../backup/export_backup_password_page.dart';
import '../backup/restore_backup_password_page.dart';
import '../../core/backup/android_saf_backup_file_read_service.dart';
import '../../core/backup/backup_file_restore_decrypt_preview_coordinator.dart';
import '../../core/backup/backup_file_restore_apply_coordinator.dart';
import '../../core/backup/backup_file_restore_preview_coordinator.dart';
import '../../core/backup/backup_import_service.dart';
import '../../core/backup/backup_v2_restore_coordinator.dart';
import '../privacy/screen_protection_scope.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/dependency_provider.dart';
import '../../core/security/app_data_reset_plan.dart';
import '../../core/security/app_key_manager.dart';
import '../../core/security/physical_app_data_reset_service.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../app_lock/app_data_reset_page.dart';
import 'recently_deleted_page.dart';
import '../all_items/archived_items_page.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  BackupHistory? _backupHistory;
  bool _historyLoaded = false;
  _DataSummary? _summary;
  bool _summaryFailed = false;
  int _summaryRequest = 0;
  bool _didStartInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartInitialLoad) return;
    _didStartInitialLoad = true;
    _refreshSummary();
    unawaited(_loadBackupHistory());
  }

  Future<void> _refreshSummary() async {
    final request = ++_summaryRequest;
    setState(() => _summaryFailed = false);
    final di = DependencyProvider.of(context);
    try {
      final results = await Future.wait<int>([
        di.itemRepo.getActiveItemCount(),
        di.attachmentRepo.getActiveAttachmentCount(),
        di.itemRepo.getArchivedItemCount(),
      ]);
      if (!mounted || request != _summaryRequest) return;
      setState(
        () => _summary = _DataSummary(
          itemCount: results[0],
          attachmentCount: results[1],
          archivedCount: results[2],
        ),
      );
    } catch (_) {
      if (!mounted || request != _summaryRequest) return;
      setState(() => _summaryFailed = true);
    }
  }

  Future<void> _loadBackupHistory() async {
    final history = await DependencyProvider.of(
      context,
    ).backupHistoryManager.load();
    if (!mounted) return;
    setState(() {
      _backupHistory = history;
      _historyLoaded = true;
    });
  }

  Future<void> _openExportPage() async {
    final provider = DependencyProvider.of(context);
    final exportService = BackupExportService(
      itemRepository: provider.itemRepo,
      memberRepository: provider.memberRepo,
      metadata: BackupExportMetadata(
        appVersion: anchAppVersion,
        schemaVersion: provider.db.schemaVersion,
        appId: 'icu.codealive.anch',
        platform: 'android',
        locale: 'zh_CN',
      ),
    );
    final coordinator = BackupV2FileExportCoordinator(
      exportService: exportService,
    );

    final result = await Navigator.push<BackupFileSaveResult>(
      context,
      MaterialPageRoute<BackupFileSaveResult>(
        builder: (context) => ScreenProtectionScope(
          child: ExportBackupPasswordPage(
            onEstimateOutputForTestOrPrototype: () {
              Future<int> estimateOutput() async =>
                  (await coordinator.estimateOutput()).estimatedOutputBytes;
              final lifecycleController =
                  provider.appLockBundle?.appLockLifecycleController;
              return lifecycleController == null
                  ? estimateOutput()
                  : lifecycleController.runWhileSystemUiLockSuppressed(
                      estimateOutput,
                    );
            },
            onExportForTestOrPrototype: (password, onProgress) {
              Future<BackupFileSaveResult> export() =>
                  coordinator.exportAndSave(
                    backupPassword: password,
                    onProgress: onProgress,
                  );
              final lifecycleController =
                  provider.appLockBundle?.appLockLifecycleController;
              return lifecycleController == null
                  ? export()
                  : lifecycleController.runWhileSystemUiLockSuppressed(export);
            },
            privacyShieldCoordinator: DependencyProvider.maybeOf(
              context,
            )?.privacyShieldBundle?.coordinator,
          ),
        ),
      ),
    );
    if (!mounted || result == null || !result.isSuccess) return;

    final history = BackupHistory(
      fileName: result.fileName,
      savedAt: result.savedAt,
    );
    setState(() {
      _backupHistory = history;
      _historyLoaded = true;
    });
    try {
      await provider.backupHistoryManager.record(
        fileName: history.fileName,
        savedAt: history.savedAt,
      );
    } catch (_) {
      // 备份文件已经成功写出；本地状态记录失败不能将导出误报为失败。
    }
  }

  Future<void> _openRestorePage() async {
    final readService = AndroidSafBackupFileReadService();
    final provider = DependencyProvider.of(context);
    final decryptPreviewCoordinator =
        BackupFileRestoreDecryptPreviewCoordinator(
          readService: readService,
          supportedSchemaVersion: provider.db.schemaVersion,
        );
    final importService = BackupImportService(database: provider.db);
    final applyCoordinator = BackupFileRestoreApplyCoordinator(
      readService: readService,
      importService: importService,
    );
    final v2Coordinator = BackupV2RestoreCoordinator(
      importService: importService,
      supportedSchemaVersion: provider.db.schemaVersion,
    );
    var isV2Selected = false;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ScreenProtectionScope(
          child: RestoreBackupPasswordPage(
            directRestore: true,
            onSelectFile: () async {
              Future<BackupFileRestorePreviewResult> selectFile() async {
                await v2Coordinator.clearPreparedRestoreAndWait();
                try {
                  final result = await decryptPreviewCoordinator
                      .selectAndPrepareFile();
                  isV2Selected = false;
                  return result;
                } on BackupFileRestoreDecryptPreviewException catch (error) {
                  if (error.type !=
                      BackupFileRestoreDecryptPreviewErrorType
                          .streamingV2Selected) {
                    rethrow;
                  }
                  isV2Selected = true;
                  return v2Coordinator.prepareSelectedFile();
                }
              }

              final lifecycleController =
                  provider.appLockBundle?.appLockLifecycleController;
              return lifecycleController == null
                  ? selectFile()
                  : lifecycleController.runWhileSystemUiLockSuppressed(
                      selectFile,
                    );
            },
            onDecryptPreview: (backupPassword) async {
              if (isV2Selected) {
                return v2Coordinator.decryptAndPreviewManifest(
                  backupPassword: backupPassword,
                );
              }
              return decryptPreviewCoordinator.decryptPreparedPreview(
                backupPassword: backupPassword,
              );
            },
            onApplyRestore: (backupPassword) async {
              if (isV2Selected) {
                throw BackupFileRestoreApplyException(
                  BackupFileRestoreApplyErrorType.fileReadFailed,
                  '备份文件读取失败。',
                );
              }
              final preparedReadResult = decryptPreviewCoordinator
                  .takePreparedReadResult();
              if (preparedReadResult == null) {
                throw BackupFileRestoreApplyException(
                  BackupFileRestoreApplyErrorType.fileReadFailed,
                  '备份文件读取失败。',
                );
              }
              return applyCoordinator.readAndApplyRestore(
                backupPassword: backupPassword,
                preparedReadResult: preparedReadResult,
              );
            },
            onApplyRestoreWithProgress: (backupPassword, onProgress) async {
              if (!isV2Selected) {
                throw BackupFileRestoreApplyException(
                  BackupFileRestoreApplyErrorType.fileReadFailed,
                  '备份文件读取失败。',
                );
              }
              return v2Coordinator.stageAndApply(
                backupPassword: backupPassword,
                onProgress: onProgress,
              );
            },
            onClearPreparedRestoreFile: () {
              isV2Selected = false;
              decryptPreviewCoordinator.clearPreparedReadResult();
              v2Coordinator.clearPreparedRestore();
            },
            privacyShieldCoordinator: DependencyProvider.maybeOf(
              context,
            )?.privacyShieldBundle?.coordinator,
          ),
        ),
      ),
    );
    if (mounted) await _refreshSummary();
  }

  Future<void> _openPhysicalReset() async {
    final di = DependencyProvider.of(context);
    final bundle = di.appLockBundle;
    if (bundle == null) {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text('当前无需清除'),
          content: const Text('当前运行模式不会保留本机资料。请在安全验证模式下执行本机数据清除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    final resetService = PhysicalAppDataResetService(
      appPinManager: bundle.appPinManager,
      appLockSettingsManager: bundle.appLockSettingsManager,
      keyStore: FlutterSecureKeyValueStore(),
      closeDatabase: di.db.close,
      documentsDirectoryProvider: getApplicationDocumentsDirectory,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AppDataResetPage(
          physicalReset: true,
          onConfirmReset: () =>
              resetService.resetAppData(AppDataResetPlans.forgotPinPhysical),
          onPhysicalResetCompleted: di.appSessionRestartController?.restart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '数据与备份',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        children: [
          const SizedBox(height: AnchSpacing.md),
          if (_summaryFailed)
            AnchEmptyState.loadError(
              onRetry: _refreshSummary,
              hasContent: _summary != null,
            ),
          if (_summary != null || !_summaryFailed)
            _SummaryCard(
              itemCount: _summary?.itemCount,
              attachmentCount: _summary?.attachmentCount,
              isLoading: _summary == null,
            ),
          const SizedBox(height: AnchSpacing.md),
          if (RuntimeScope.of(context).isDevMode)
            const AnchSecurityBanner(
              message: AnchSecurityBanner.devModeMessage,
              type: AnchBannerType.warning,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
            child: Text(
              '备份文件经过加密，只能使用创建时设置的密码恢复。安册不会上传或找回密码。',
              style: TextStyle(
                fontSize: 14,
                color: context.anchColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: AnchSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
            child: _buildBackupStatus(),
          ),
          const SizedBox(height: AnchSpacing.sm),
          _ActionCard(
            icon: AnchIcons.backup,
            title: '导出加密备份',
            description: '创建备份，包含当前资料和附件',
            onTap: _openExportPage,
            primary: true,
          ),
          const SizedBox(height: AnchSpacing.sm),
          _ActionCard(
            icon: AnchIcons.download,
            title: '从备份恢复',
            description: '恢复备份前验证文件与密码，再确认覆盖范围',
            onTap: _openRestorePage,
          ),
          const SizedBox(height: AnchSpacing.md),
          _ActionCard(
            icon: AnchIcons.archive,
            title: '已归档资料',
            description: _summary == null
                ? '读取数量中'
                : '${_summary!.archivedCount} 条，可查看、编辑或取消归档',
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const ArchivedItemsPage()),
              );
              if (mounted) await _refreshSummary();
            },
          ),
          const SizedBox(height: AnchSpacing.sm),
          _ActionCard(
            icon: AnchIcons.restore,
            title: '最近删除',
            description: '恢复已删除资料，或再次确认后永久删除',
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const RecentlyDeletedPage()),
              );
              if (mounted) await _refreshSummary();
            },
          ),
          const SizedBox(height: AnchSpacing.sm),
          _ActionCard(
            icon: AnchIcons.delete,
            title: '删除本机资料',
            description: '永久删除资料、附件、PIN 与本机密钥；外部备份不会删除',
            danger: true,
            onTap: _openPhysicalReset,
          ),
          const SizedBox(height: AnchSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildBackupStatus() {
    if (!_historyLoaded) return const SizedBox.shrink();

    final colors = context.anchColors;
    final history = _backupHistory;
    return Padding(
      key: ValueKey(
        history == null ? 'backup_status_empty' : 'backup_status_success',
      ),
      padding: const EdgeInsets.symmetric(vertical: AnchSpacing.xs),
      child: history == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '尚未创建备份',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '上次备份时间：${_formatTimestamp(history.savedAt)}',
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                ),
                const SizedBox(height: AnchSpacing.xs),
                Text(
                  '备份文件名称：${history.fileName}',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
    );
  }

  String _formatTimestamp(int millisecondsSinceEpoch) {
    final value = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}:'
        '${twoDigits(value.second)}';
  }
}

class _DataSummary {
  const _DataSummary({
    required this.itemCount,
    required this.attachmentCount,
    required this.archivedCount,
  });

  final int itemCount;
  final int attachmentCount;
  final int archivedCount;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.itemCount,
    required this.attachmentCount,
    required this.isLoading,
  });

  final int? itemCount;
  final int? attachmentCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final itemLabel = isLoading ? '读取中' : '${itemCount ?? 0} 条';
    final attachmentLabel = isLoading ? '读取中' : '${attachmentCount ?? 0} 个';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
      padding: const EdgeInsets.all(AnchSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AnchRadius.lg),
      ),
      child: Row(
        children: [
          _CountColumn(label: '已保存资料', value: itemLabel),
          Container(width: 1, height: 42, color: colors.divider),
          _CountColumn(label: '附件', value: attachmentLabel),
        ],
      ),
    );
  }
}

class _CountColumn extends StatelessWidget {
  const _CountColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AnchSpacing.xs),
          Text(label, style: TextStyle(fontSize: 12, color: colors.textMuted)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.danger = false,
    this.primary = false,
  });

  final AnchIconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool danger;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final color = danger
        ? colors.danger
        : primary
        ? colors.accentInk
        : colors.textPrimary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
      child: Material(
        color: primary ? colors.accent : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnchRadius.lg),
          side: BorderSide(color: primary ? colors.accent : colors.divider),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AnchRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AnchSpacing.md),
            child: Row(
              children: [
                AnchIcon(icon, color: color),
                const SizedBox(width: AnchSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: primary
                              ? colors.accentInk
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AnchIcon(
                  AnchIcons.chevronRight,
                  size: 20,
                  color: primary ? colors.accentInk : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
