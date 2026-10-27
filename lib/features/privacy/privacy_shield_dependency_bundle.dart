import 'privacy_shield_controller.dart';
import 'privacy_shield_coordinator.dart';

/// 封装防窥机制核心组件的依赖包，方便注入容器向子树集中透传。
class PrivacyShieldDependencyBundle {
  const PrivacyShieldDependencyBundle({
    required this.controller,
    required this.coordinator,
  });

  final PrivacyShieldController controller;
  final PrivacyShieldCoordinator coordinator;

  @override
  String toString() =>
      'PrivacyShieldDependencyBundle(controller: <redacted>, coordinator: <redacted>)';
}
