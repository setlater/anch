import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/core/widgets/anch_member_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildAvatar({required String memberId, required String name}) {
    return MaterialApp(
      theme: AnchTheme.light,
      home: Scaffold(
        body: AnchMemberAvatar(memberId: memberId, name: name),
      ),
    );
  }

  testWidgets('系统家庭和我保留专属语义图标', (tester) async {
    await tester.pumpWidget(
      buildAvatar(memberId: systemFamilyMemberId, name: '家庭'),
    );
    expect(
      tester
          .widget<AnchIcon>(find.byKey(const Key('anch_member_avatar_family')))
          .icon,
      same(AnchIcons.home),
    );
    expect(find.byKey(const Key('anch_member_avatar_initial')), findsNothing);

    await tester.pumpWidget(buildAvatar(memberId: systemMeMemberId, name: '我'));
    expect(
      tester
          .widget<AnchIcon>(find.byKey(const Key('anch_member_avatar_me')))
          .icon,
      same(AnchIcons.member),
    );
    expect(find.byKey(const Key('anch_member_avatar_initial')), findsNothing);
  });

  testWidgets('普通成员统一显示名称首个可见字符', (tester) async {
    await tester.pumpWidget(
      buildAvatar(memberId: 'fictional-member', name: '  小明'),
    );
    expect(find.text('小'), findsOneWidget);
    expect(find.byType(AnchIcon), findsNothing);

    await tester.pumpWidget(
      buildAvatar(memberId: 'emoji-member', name: '👨‍👩‍👧 家庭成员'),
    );
    expect(find.text('👨‍👩‍👧'), findsOneWidget);

    await tester.pumpWidget(buildAvatar(memberId: 'blank-member', name: '   '));
    expect(find.text('人'), findsOneWidget);
  });
}
