import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_icons.dart';
import 'anch_icon.dart';

enum AnchMemberAvatarKind { family, me, initial }

/// 安册统一成员头像。
///
/// 系统「家庭」和「我」保留专属图标，其他成员只显示名称的首个可见字符。
class AnchMemberAvatar extends StatelessWidget {
  const AnchMemberAvatar({
    super.key,
    required this.memberId,
    required this.name,
    this.size = 36,
    this.selected = false,
  });

  final String memberId;
  final String name;
  final double size;
  final bool selected;

  AnchMemberAvatarKind get kind {
    if (memberId == systemFamilyMemberId) return AnchMemberAvatarKind.family;
    if (memberId == systemMeMemberId) return AnchMemberAvatarKind.me;
    return AnchMemberAvatarKind.initial;
  }

  String get initial {
    final trimmedName = name.trim();
    return trimmedName.isEmpty ? '人' : trimmedName.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final isFamily = kind == AnchMemberAvatarKind.family;
    final backgroundColor = isFamily || selected
        ? colors.accentSoft
        : colors.surfaceSoft;
    final foregroundColor = isFamily || selected
        ? colors.accentDeep
        : colors.textSecondary;

    return Semantics(
      image: true,
      label: '${name.trim().isEmpty ? '成员' : name.trim()}头像',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('anch_member_avatar'),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.accent : colors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: switch (kind) {
            AnchMemberAvatarKind.family => AnchIcon(
              AnchIcons.home,
              key: const Key('anch_member_avatar_family'),
              size: size * 0.54,
              color: foregroundColor,
            ),
            AnchMemberAvatarKind.me => AnchIcon(
              AnchIcons.member,
              key: const Key('anch_member_avatar_me'),
              size: size * 0.54,
              color: foregroundColor,
            ),
            AnchMemberAvatarKind.initial => Text(
              initial,
              key: const Key('anch_member_avatar_initial'),
              style: TextStyle(
                color: foregroundColor,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          },
        ),
      ),
    );
  }
}
