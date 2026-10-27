/// 轻量级 Schema 迁移策略定义基类
abstract class MigrationStrategy {
  /// 起始版本
  int get fromVersion;

  /// 目标版本
  int get toVersion;

  /// 转换单个字段值
  /// 仅做结构或格式转换，不改变业务语义，不允许引入任何 UI 或 Policy 安全逻辑。
  String? transform(String fieldKey, String? value);
}
