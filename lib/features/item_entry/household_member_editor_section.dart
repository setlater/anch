import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_motion.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_section_header.dart';
import 'controllers/household_member_draft_controller.dart';
import 'household_member_draft.dart';
import 'utils/field_formatters.dart';

class HouseholdMemberEditorSection extends StatefulWidget {
  const HouseholdMemberEditorSection({
    super.key,
    required this.members,
    required this.onChanged,
  });
  final List<HouseholdMemberDraft> members;
  final ValueChanged<List<HouseholdMemberDraft>> onChanged;
  @override
  State<HouseholdMemberEditorSection> createState() =>
      _HouseholdMemberEditorSectionState();
}

class _HouseholdMemberEditorSectionState
    extends State<HouseholdMemberEditorSection> {
  static const _controller = HouseholdMemberDraftController();
  late List<HouseholdMemberDraft> _members;
  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
  }

  @override
  void didUpdateWidget(covariant HouseholdMemberEditorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.members, widget.members)) {
      _members = List.of(widget.members);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_members.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnchSectionHeader(
            title: '户内成员（可选）',
            trailingText: '添加成员',
            action: () => _showAddEditMemberBottomSheet(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AnchSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AnchSpacing.lg),
            decoration: BoxDecoration(
              color: context.anchColors.surface,
              borderRadius: BorderRadius.circular(AnchRadius.lg),
              border: Border.all(color: context.anchColors.divider),
            ),
            child: Column(
              children: [
                Text(
                  '可添加户内成员信息，也可以只上传户口本照片后保存',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.anchColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AnchSpacing.md),
                OutlinedButton.icon(
                  key: const Key('add-member-empty-btn'),
                  icon: const AnchIcon(AnchIcons.add, size: 16),
                  label: const Text('添加成员'),
                  onPressed: () => _showAddEditMemberBottomSheet(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.anchColors.accentDeep,
                    side: BorderSide(color: context.anchColors.accentDeep),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AnchRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnchSectionHeader(
          title: '户内成员（可选）',
          trailingText: '添加成员',
          action: () => _showAddEditMemberBottomSheet(),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AnchSpacing.sm),
        Column(
          children: List.generate(_members.length, (index) {
            final member = _members[index];
            final displayName = member.name.isNotEmpty ? member.name : '未填写姓名';
            final displayIdNumber = member.idNumber.isNotEmpty ? '******' : '';

            return Container(
              margin: const EdgeInsets.only(bottom: AnchSpacing.sm),
              padding: const EdgeInsets.all(AnchSpacing.md),
              decoration: BoxDecoration(
                color: context.anchColors.surface,
                borderRadius: BorderRadius.circular(AnchRadius.lg),
                border: Border.all(color: context.anchColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.anchColors.textSecondary,
                              ),
                            ),
                            if (member.relation.isNotEmpty) ...[
                              const SizedBox(width: AnchSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.anchColors.background,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  member.relation,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.anchColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (displayIdNumber.isNotEmpty) ...[
                          const SizedBox(height: AnchSpacing.xs),
                          Text(
                            '身份证号: $displayIdNumber',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.anchColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: AnchIcon(
                      AnchIcons.edit,
                      size: 20,
                      color: context.anchColors.textSecondary,
                    ),
                    onPressed: () =>
                        _showAddEditMemberBottomSheet(index: index),
                  ),
                  IconButton(
                    icon: AnchIcon(
                      AnchIcons.delete,
                      size: 20,
                      color: context.anchColors.danger,
                    ),
                    onPressed: () => _confirmDeleteMember(index),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  void _showAddEditMemberBottomSheet({int? index}) {
    HouseholdMemberDraft? member;
    if (index != null) {
      member = _members[index];
    }

    final nameCtrl = TextEditingController(text: member?.name ?? '');
    final relationCtrl = TextEditingController(text: member?.relation ?? '');
    final idNumCtrl = TextEditingController(text: member?.idNumber ?? '');
    final formerCtrl = TextEditingController(text: member?.formerName ?? '');
    final ethnicityCtrl = TextEditingController(text: member?.ethnicity ?? '');
    final nativeCtrl = TextEditingController(text: member?.nativePlace ?? '');
    final birthCtrl = TextEditingController(text: member?.birthPlace ?? '');

    String? errorMessage;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.anchColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AnchRadius.lg),
        ),
      ),
      sheetAnimationStyle: AnchMotion.bottomSheetAnimationStyle(context),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(AnchSpacing.lg),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              index == null ? '添加户内成员' : '编辑户内成员',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.anchColors.textSecondary,
                              ),
                            ),
                            IconButton(
                              icon: const AnchIcon(AnchIcons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        Text(
                          '基本信息',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.anchColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AnchSpacing.sm),
                        _buildBottomSheetTextField('成员姓名', nameCtrl),
                        _buildBottomSheetTextField('与户主关系', relationCtrl),
                        _buildBottomSheetTextField(
                          '身份证号',
                          idNumCtrl,
                          formatters: [IdCardNumberFormatter()],
                        ),
                        const SizedBox(height: AnchSpacing.md),
                        Text(
                          '更多信息',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.anchColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AnchSpacing.sm),
                        _buildBottomSheetTextField('曾用名', formerCtrl),
                        _buildBottomSheetTextField('民族', ethnicityCtrl),
                        _buildBottomSheetTextField('籍贯', nativeCtrl),
                        _buildBottomSheetTextField('出生地', birthCtrl),
                        const SizedBox(height: AnchSpacing.lg),
                        if (errorMessage != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AnchSpacing.sm,
                            ),
                            child: Text(
                              errorMessage!,
                              key: const Key('member-form-error-text'),
                              style: TextStyle(
                                color: context.anchColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: context.anchColors.divider,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AnchRadius.md,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                    color: context.anchColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AnchSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final name = nameCtrl.text.trim();
                                  final relation = relationCtrl.text.trim();
                                  final idNum = idNumCtrl.text.trim();
                                  final former = formerCtrl.text.trim();
                                  final ethnicity = ethnicityCtrl.text.trim();
                                  final native = nativeCtrl.text.trim();
                                  final birth = birthCtrl.text.trim();

                                  final updated = HouseholdMemberDraft(
                                    id: member?.id,
                                    name: name,
                                    relation: relation,
                                    idNumber: idNum,
                                    formerName: former,
                                    ethnicity: ethnicity,
                                    nativePlace: native,
                                    birthPlace: birth,
                                    sortOrder: member?.sortOrder ?? 0,
                                  );

                                  final validationError = _controller.validate(
                                    _members,
                                    updated,
                                    editingIndex: index,
                                  );
                                  if (validationError != null) {
                                    setSheetState(() {
                                      errorMessage = validationError;
                                    });
                                    return;
                                  }

                                  setState(() {
                                    _members = _controller.upsert(
                                      _members,
                                      updated,
                                      editingIndex: index,
                                    );
                                  });

                                  widget.onChanged(_members);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      context.anchColors.accentDeep,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AnchRadius.md,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '保存',
                                  style: TextStyle(
                                    color: context.anchColors.accentInk,
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
          },
        );
      },
    );
  }

  Widget _buildBottomSheetTextField(
    String label,
    TextEditingController controller, {
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AnchSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.anchColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            inputFormatters: formatters,
            enableInteractiveSelection: true,
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: editableTextState.contextMenuButtonItems,
              );
            },
            style: TextStyle(
              fontSize: 14,
              color: context.anchColors.textSecondary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AnchSpacing.md,
                vertical: AnchSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AnchRadius.md),
                borderSide: BorderSide(color: context.anchColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AnchRadius.md),
                borderSide: BorderSide(color: context.anchColors.accentDeep),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AnchRadius.md),
                borderSide: BorderSide(color: context.anchColors.divider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMember(int index) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除成员'),
          content: const Text('确定要删除该户内成员信息吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: context.anchColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _members = _controller.remove(_members, index);
                });
                widget.onChanged(_members);
                Navigator.pop(context);
              },
              child: Text(
                '删除',
                style: TextStyle(color: context.anchColors.danger),
              ),
            ),
          ],
        );
      },
    );
  }
}
