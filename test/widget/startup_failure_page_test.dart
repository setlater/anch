import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/widgets/anch_startup_failure_page.dart';
import 'package:anch/core/security/app_startup_failure.dart';

void main() {
  group('AnchStartupFailurePage Widget 测试', () {
    testWidgets('验证 1. 错误页正确渲染主要标题和信息，并安全脱敏', (WidgetTester tester) async {
      final mockFailure = AppStartupException(
        AppStartupFailureType.databaseKeyMismatch,
        '模拟密钥不匹配错误。',
      );

      await tester.pumpWidget(AnchStartupFailureApp(failure: mockFailure));

      // 1. 验证启动失败不暴露底层实现细节
      expect(find.text('无法打开本机资料'), findsOneWidget);

      // 2. 验证安全阻断与数据保留提示
      expect(find.textContaining('安全保护已生效'), findsOneWidget);
      expect(find.textContaining('请勿清除应用数据'), findsOneWidget);
      expect(find.textContaining('开发验证阶段'), findsNothing);

      // 3. 验证没有显示任何敏感密钥字样
      expect(find.textContaining('key'), findsNothing);
      expect(find.textContaining('dev-placeholder'), findsNothing);

      // 4. 验证不包含“继续”、“进入App”及“删除/重置”等动作性按钮
      expect(find.text('继续'), findsNothing);
      expect(find.text('进入 App'), findsNothing);
      expect(find.text('删除'), findsNothing);
      expect(find.text('重置'), findsNothing);

      // 5. 验证正确显示了错误类型分类名
      expect(find.text('db_credential_mismatch'), findsOneWidget);
    });

    testWidgets('验证 2. formalSecurityModeBlocked 阻断异常正确渲染安全阻断标题和建议措施', (
      WidgetTester tester,
    ) async {
      final mockFailure = AppStartupException(
        AppStartupFailureType.formalSecurityModeBlocked,
        'formal security mode is not enabled in this build stage',
      );

      await tester.pumpWidget(AnchStartupFailureApp(failure: mockFailure));
      await tester.pumpAndSettle();

      // 1. 验证面向用户的安全配置标题
      expect(find.text('安全配置异常'), findsOneWidget);

      // 2. 验证不向用户暴露构建参数与内部模式
      expect(find.textContaining('当前版本的安全配置不完整'), findsOneWidget);
      expect(find.textContaining('securityValidation'), findsNothing);

      // 3. 验证给出可执行且不破坏数据的处理建议
      expect(find.textContaining('请重新安装来源可信的正式版本'), findsOneWidget);

      // 4. 验证正确显示了错误类型分类名
      expect(find.text('formal_blocked'), findsOneWidget);
    });
  });
}
