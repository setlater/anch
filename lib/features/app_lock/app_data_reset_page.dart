import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';

/// 忘记 PIN／删除本机资料的强风险确认页面。
class AppDataResetPage extends StatefulWidget {
  final Future<void> Function() onConfirmReset;
  final Future<void> Function()? onPhysicalResetCompleted;
  final VoidCallback? onOpenBackupRestore;
  final bool physicalReset;

  const AppDataResetPage({
    super.key,
    required this.onConfirmReset,
    this.onPhysicalResetCompleted,
    this.onOpenBackupRestore,
    this.physicalReset = false,
  });

  @override
  State<AppDataResetPage> createState() => _AppDataResetPageState();
}

class _AppDataResetPageState extends State<AppDataResetPage> {
  bool _understandRisk = false;
  bool _isResetting = false;

  void _showConfirmResetDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final colors = dialogContext.anchColors;
        return AlertDialog(
          title: Text(
            '确认删除本机资料？',
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.danger),
          ),
          content: const Text(
            '本机资料、附件、安册 PIN 与本机加密密钥将被永久删除。只有已导出的加密备份及其密码可用于恢复。此操作无法撤销。',
            style: TextStyle(height: 1.4),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // 关掉二级确认 Dialog
                _executeReset();
              },
              child: Text(
                '确认删除',
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeReset() async {
    setState(() {
      _isResetting = true;
    });

    try {
      await widget.onConfirmReset();

      final onPhysicalResetCompleted = widget.onPhysicalResetCompleted;
      if (onPhysicalResetCompleted != null) {
        await onPhysicalResetCompleted();
        if (mounted) {
          setState(() {
            _isResetting = false;
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _isResetting = false;
      });

      // 成功 Dialog
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final colors = dialogContext.anchColors;
          final hasRestore = widget.onOpenBackupRestore != null;
          return AlertDialog(
            title: Text(
              '本机资料已删除',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.success,
              ),
            ),
            content: Text(
              widget.physicalReset
                  ? '本机资料、附件、PIN 与加密密钥已删除。请完全退出并重新启动应用。'
                  : '本机资料删除操作已完成。',
              style: const TextStyle(height: 1.4),
            ),
            actions: <Widget>[
              if (widget.physicalReset)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('我知道了'),
                )
              else if (hasRestore) ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (mounted) {
                      Navigator.pop(context, true); // 返回上一页
                    }
                  },
                  child: Text(
                    '稍后处理',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (mounted) {
                      widget.onOpenBackupRestore?.call();
                      Navigator.pop(context, true); // 返回上一页
                    }
                  },
                  child: const Text(
                    '前往备份恢复',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (mounted) {
                      Navigator.pop(context, true); // 返回上一页
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResetting = false;
      });

      // 失败 Dialog 不展示底层异常，避免泄露路径或安全实现细节。
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final colors = dialogContext.anchColors;
          return AlertDialog(
            title: Text(
              '删除失败',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.danger,
              ),
            ),
            content: Text(
              '删除未完成，本机现有资料可能仍保留。请重新启动安册并检查后，再决定是否重试。',
              style: const TextStyle(height: 1.4),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '删除本机资料',
        onBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 警告和说明主体 Card
            Card(
              elevation: 0,
              color: colors.dangerSoft,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colors.danger.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnchIcon(
                          AnchIcons.danger,
                          color: colors.danger,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '风险说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '删除本机资料是一项不可撤销的操作，将产生以下影响：',
                      style: TextStyle(fontSize: 14, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    _buildRiskItem(
                      AnchIcons.listRemove,
                      '永久删除当前资料、已归档资料、最近删除记录及全部字段数据',
                    ),
                    _buildRiskItem(AnchIcons.delete, '永久删除保存在安册内的全部附件'),
                    _buildRiskItem(AnchIcons.reset, '删除安册 PIN、应用锁设置和本机加密密钥'),
                    _buildRiskItem(
                      AnchIcons.backup,
                      '不会删除您手动导出至外部的已加密 .abk 备份文件',
                    ),
                    _buildRiskItem(
                      AnchIcons.restore,
                      '删除后只能使用已导出的加密备份和对应密码恢复；安册无法找回未备份资料',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 2. 第一层确认复选框
            CheckboxListTile(
              value: _understandRisk,
              onChanged: _isResetting
                  ? null
                  : (val) {
                      setState(() {
                        _understandRisk = val ?? false;
                      });
                    },
              title: const Text(
                '我已了解：删除后本机资料无法撤销，且安册无法帮助找回。',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: colors.danger,
            ),
            const SizedBox(height: 32),

            // 3. 删除按钮
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  disabledBackgroundColor: colors.dangerSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: (_understandRisk && !_isResetting)
                    ? _showConfirmResetDialog
                    : null,
                child: _isResetting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onError,
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Text(
                        '删除本机资料',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskItem(AnchIconData icon, String text) {
    final colors = context.anchColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnchIcon(icon, size: 18, color: colors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
