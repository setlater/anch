@Tags(['security'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/security/app_startup_failure.dart';
import 'package:anch/core/widgets/anch_startup_failure_page.dart';

void main() {
  final forbiddenWords = [
    'databaseKey',
    'backupPassword',
    'appPin',
    'pin',
    'salt',
    'verifier',
    'secureStorage',
    'keystore',
    'keychain',
    'token',
    'secret',
    'privateKey',
    '/home/',
    '/data/data/',
    'content://',
    'file://',
  ];

  group('安册 运行态与 UI 文本脱敏安全专项测试', () {
    test('1. 验证各种 AnchSecurityRuntimeConfig 的 toString() 彻底脱敏', () {
      final configs = [
        AnchSecurityRuntimeConfig.fromRawEnvironment({}),
        AnchSecurityRuntimeConfig.fromRawEnvironment({'ANCH_SECURITY_MODE': 'dev'}),
        AnchSecurityRuntimeConfig.fromRawEnvironment({
          'ANCH_SECURITY_MODE': 'securityValidation',
          'ANCH_USE_ENCRYPTED_DB': 'true',
        }),
        AnchSecurityRuntimeConfig.fromRawEnvironment({'ANCH_SECURITY_MODE': 'formal'}),
        AnchSecurityRuntimeConfig.fromRawEnvironment({'ANCH_SECURITY_MODE': 'unknown_mode_xyz'}),
      ];

      for (final config in configs) {
        final logStr = config.toString();
        for (final word in forbiddenWords) {
          expect(
            logStr.contains(word),
            isFalse,
            reason: 'config.toString() 泄露了敏感词 "$word": $logStr',
          );
        }
      }
    });

    test('2. 验证 AppStartupException 的 toString() 彻底脱敏，不含敏感名词', () {
      final exceptions = [
        AppStartupException(AppStartupFailureType.databaseKeyMismatch, 'db_key_mismatch'),
        AppStartupException(AppStartupFailureType.invalidStoredKey, 'invalid_key'),
        AppStartupException(AppStartupFailureType.formalSecurityModeBlocked, 'formal_blocked'),
        AppStartupException(AppStartupFailureType.databaseCorrupted, 'db_corrupted'),
      ];

      for (final ex in exceptions) {
        final logStr = ex.toString();
        for (final word in forbiddenWords) {
          expect(
            logStr.contains(word),
            isFalse,
            reason: 'AppStartupException.toString() 泄露了敏感词 "$word": $logStr',
          );
        }
      }
    });

    testWidgets('3. 验证启动失败页 (加密数据库启动失败) 渲染树中的所有文本节点彻底脱敏', (WidgetTester tester) async {
      final failure = AppStartupException(
        AppStartupFailureType.databaseKeyMismatch,
        '模拟启动故障',
      );

      await tester.pumpWidget(AnchStartupFailureApp(failure: failure));
      await tester.pumpAndSettle();

      final allTexts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? '').toList();

      for (final text in allTexts) {
        for (final word in forbiddenWords) {
          // 不区分大小写判断
          expect(
            text.toLowerCase().contains(word.toLowerCase()),
            isFalse,
            reason: '错误页文本节点中泄露了敏感词 "$word": "$text"',
          );
        }
      }
    });

    testWidgets('4. 验证 formal 阻断页渲染树中的所有文本节点彻底脱敏', (WidgetTester tester) async {
      final failure = AppStartupException(
        AppStartupFailureType.formalSecurityModeBlocked,
        'formal security mode is not enabled in this build stage',
      );

      await tester.pumpWidget(AnchStartupFailureApp(failure: failure));
      await tester.pumpAndSettle();

      final allTexts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? '').toList();

      for (final text in allTexts) {
        for (final word in forbiddenWords) {
          expect(
            text.toLowerCase().contains(word.toLowerCase()),
            isFalse,
            reason: '阻断页文本节点中泄露了敏感词 "$word": "$text"',
          );
        }
      }
    });
  });
}
