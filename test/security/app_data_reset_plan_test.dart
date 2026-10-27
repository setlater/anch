@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_data_reset_plan.dart';

void main() {
  group('AppDataResetPlan 单元测试', () {
    test('1. 物理重置包含本机清理步骤且保留外部备份', () {
      const plan = AppDataResetPlans.forgotPinPhysical;
      expect(plan.mode, AppDataResetMode.physicalDelete);
      expect(plan.clearBusinessData, isTrue);
      expect(plan.clearPin, isTrue);
      expect(plan.disableAppLock, isTrue);
      expect(plan.deleteDatabaseFile, isTrue);
      expect(plan.clearDatabaseKey, isTrue);
      expect(plan.deleteBackupFiles, isFalse);
    });

    test('2. isDestructive 在有任何清理任务时为 true，否则为 false', () {
      const planEmpty = AppDataResetPlan(
        mode: AppDataResetMode.physicalDelete,
        clearBusinessData: false,
        clearPin: false,
        disableAppLock: false,
        deleteDatabaseFile: false,
        clearDatabaseKey: false,
        deleteBackupFiles: false,
      );
      expect(planEmpty.isDestructive, isFalse);

      const planPinOnly = AppDataResetPlan(
        mode: AppDataResetMode.physicalDelete,
        clearBusinessData: false,
        clearPin: true,
        disableAppLock: false,
        deleteDatabaseFile: false,
        clearDatabaseKey: false,
        deleteBackupFiles: false,
      );
      expect(planPinOnly.isDestructive, isTrue);
    });

    test('3. toString() 实现脱敏，绝不输出 PIN、databaseKey 或敏感数据字眼', () {
      const plan = AppDataResetPlans.forgotPinPhysical;
      final str = plan.toString();

      expect(str, contains('AppDataResetPlan'));
      expect(str, contains('mode: physicalDelete'));
      expect(str, contains('clearPin: true'));

      // ⚠️ 【安全边界】确保绝无敏感信息泄露
      expect(str, isNot(contains('PIN:')));
      expect(str, isNot(contains('databaseKey:')));
      expect(str, isNot(contains('path')));
      expect(str, isNot(contains('sqlite')));
    });
  });
}
