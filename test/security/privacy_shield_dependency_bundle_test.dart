@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';
import 'package:anch/features/privacy/privacy_shield_coordinator.dart';
import 'package:anch/features/privacy/privacy_shield_dependency_bundle.dart';

void main() {
  group('PrivacyShieldDependencyBundle 单元测试', () {
    test('1. 验证 bundle 能够正确实例化，且 toString 已安全脱敏', () {
      final controller = PrivacyShieldController();
      final coordinator = PrivacyShieldCoordinator(controller: controller);

      final bundle = PrivacyShieldDependencyBundle(
        controller: controller,
        coordinator: coordinator,
      );

      expect(bundle.controller, equals(controller));
      expect(bundle.coordinator, equals(coordinator));

      final str = bundle.toString();
      expect(str, contains('<redacted>'));
      expect(str.contains('controller: PrivacyShieldController'), isFalse);
      expect(str.contains('coordinator: PrivacyShieldCoordinator'), isFalse);
      
      // 绝对不含有真实密码或敏感信息字眼
      expect(str.contains('PIN'), isFalse);
      expect(str.contains('salt'), isFalse);
      expect(str.contains('verifier'), isFalse);
      expect(str.contains('databaseKey'), isFalse);
    });
  });
}
