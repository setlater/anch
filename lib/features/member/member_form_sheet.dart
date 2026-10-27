import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../app/dependency_provider.dart';
import '../../core/repository/models/member_model.dart';
import '../../core/repository/models/save_member_input.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../privacy/screen_protection_scope.dart';

/// 家庭成员表单 BottomSheet。
///
/// 用途：在成员主页、资料整理流程中新增或编辑成员称呼和备注。
class MemberFormSheet extends StatefulWidget {
  final MemberModel? existingMember;
  final int itemCount;

  const MemberFormSheet({super.key, this.existingMember, this.itemCount = 0});

  @override
  State<MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends State<MemberFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingMember?.name ?? '',
    );
    _noteController = TextEditingController(
      text: widget.existingMember?.note ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = '称呼不能为空';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final memberRepo = DependencyProvider.of(context).memberRepo;
      final savedId = await memberRepo.saveMember(
        SaveMemberInput(
          id: widget.existingMember?.id,
          memberType: widget.existingMember?.memberType ?? 'person',
          name: name,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          sortOrder: widget.existingMember?.sortOrder ?? 0,
          isSystem: widget.existingMember?.isSystem ?? false,
          isArchived: widget.existingMember?.isArchived ?? false,
        ),
      );
      if (mounted) {
        Navigator.pop(context, savedId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = '保存失败，请重试';
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.anchColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AnchRadius.lg),
          ),
          title: Text(
            '确认删除该成员吗？',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.anchColors.textPrimary,
            ),
          ),
          content: Text(
            widget.itemCount > 0
                ? '该成员下的 ${widget.itemCount} 条资料不会被删除，将安全地移入“家庭”归属中。'
                : '确认删除该成员？此操作不可撤销。',
            style: TextStyle(
              fontSize: 13,
              color: context.anchColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                '取消',
                style: TextStyle(color: context.anchColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                '确认删除',
                style: TextStyle(
                  color: context.anchColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isSaving = true;
        _errorText = null;
      });
      try {
        final memberRepo = DependencyProvider.of(context).memberRepo;
        await memberRepo.archiveMember(widget.existingMember!.id);
        if (mounted) {
          Navigator.pop(context, 'deleted');
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorText = '删除失败，请重试';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ScreenProtectionScope(child: _buildSheet(context));

  Widget _buildSheet(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.anchColors.surfaceSoft,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AnchRadius.lg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AnchSpacing.page,
          AnchSpacing.md,
          AnchSpacing.page,
          AnchSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部拖拽手柄指示器
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AnchSpacing.md),
                    decoration: BoxDecoration(
                      color: context.anchColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 标题与删除操作
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingMember == null ? '添加成员' : '编辑成员',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.anchColors.textPrimary,
                      ),
                    ),
                    if (widget.existingMember != null &&
                        !widget.existingMember!.isSystem)
                      IconButton(
                        tooltip: '删除成员',
                        icon: AnchIcon(
                          AnchIcons.delete,
                          color: context.anchColors.danger,
                        ),
                        onPressed: _isSaving ? null : _delete,
                      ),
                  ],
                ),
                const SizedBox(height: AnchSpacing.md),
                if (_errorText != null) ...[
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: context.anchColors.danger,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AnchSpacing.sm),
                ],
                // 称呼输入
                TextFormField(
                  controller: _nameController,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '称呼',
                    hintText: '如：爸爸、大宝、我的车',
                    counterText: '',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AnchSpacing.md),
                // 备注输入
                TextFormField(
                  controller: _noteController,
                  maxLength: 100,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '备注（选填）',
                    hintText: '描述或附加说明...',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AnchSpacing.xl),
                // 按钮操作区
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: context.anchColors.borderStrong,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AnchRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AnchSpacing.md,
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            color: context.anchColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AnchSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.anchColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AnchRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AnchSpacing.md,
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.anchColors.accentInk,
                                ),
                              )
                            : Text(
                                '确定',
                                style: TextStyle(
                                  color: context.anchColors.accentInk,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
