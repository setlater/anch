import 'package:flutter/foundation.dart';

bool _licensesRegistered = false;

/// 注册未由 Dart 包元数据自动收集的本地资源许可。
void registerAnchThirdPartyLicenses() {
  if (_licensesRegistered) return;
  _licensesRegistered = true;

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Solar Icons 1.2.5'],
      '''
Solar Icons 1.2.5
Copyright © 480 Design

Source: https://github.com/480-Design/Solar-Icon-Set
License: Creative Commons Attribution 4.0 International (CC BY 4.0)
License URL: https://creativecommons.org/licenses/by/4.0/

适配说明：资源按安册的语义命名和目录结构重新组织，并在应用运行时着色；原许可条款不变。
''',
    );
  });
}
