import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('选择弹窗提供统一标题、说明、选项组和独立取消操作', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: AnchBottomSheetFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnchBottomSheetHeader(
                  title: '选择附件来源',
                  description: '还可添加 4 个附件',
                ),
                AnchBottomSheetOptionGroup(
                  children: [
                    AnchBottomSheetOption(
                      icon: AnchIcons.photoLibrary,
                      title: '从相册选择',
                      description: '推荐添加图片',
                      onTap: () {},
                    ),
                  ],
                ),
                AnchBottomSheetDismissAction(onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('选择附件来源'), findsOneWidget);
    expect(find.text('还可添加 4 个附件'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('从相册选择')), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('内容超过可用高度时可滚动且不溢出', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 240,
              child: AnchBottomSheetFrame(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnchBottomSheetHeader(title: '资料操作'),
                    AnchBottomSheetOptionGroup(
                      children: [
                        AnchBottomSheetOption(
                          icon: AnchIcons.success,
                          title: '设为置顶',
                          onTap: () {},
                        ),
                        AnchBottomSheetOption(
                          icon: AnchIcons.archive,
                          title: '归档资料',
                          onTap: () {},
                        ),
                        AnchBottomSheetOption(
                          icon: AnchIcons.edit,
                          title: '编辑',
                          onTap: () {},
                        ),
                      ],
                    ),
                    AnchBottomSheetDismissAction(onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平面档案方案仅使用细分隔线和无底色取消行', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: AnchBottomSheetFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnchBottomSheetHeader(title: '资料操作'),
                AnchBottomSheetOptionGroup(
                  children: [
                    AnchBottomSheetOption(
                      icon: AnchIcons.edit,
                      title: '编辑',
                      onTap: () {},
                    ),
                    AnchBottomSheetOption(
                      icon: AnchIcons.delete,
                      title: '删除',
                      isDestructive: true,
                      onTap: () {},
                    ),
                  ],
                ),
                AnchBottomSheetDismissAction(onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(Divider), findsNWidgets(3));
  });
}
