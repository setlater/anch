import 'screen_protection_controller.dart';
import 'screen_protection_settings_manager.dart';

class ScreenProtectionDependencyBundle {
  const ScreenProtectionDependencyBundle({
    required this.controller,
    required this.settingsManager,
  });

  final ScreenProtectionController controller;
  final ScreenProtectionSettingsManager settingsManager;
}
