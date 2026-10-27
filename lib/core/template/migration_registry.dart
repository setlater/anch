import 'migration_strategy.dart';

/// 资料卡片 V1 到 V2 储蓄卡迁移策略（静态示例，不做复杂业务实现）
class DebitCardV1ToV2MigrationStrategy implements MigrationStrategy {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  String? transform(String fieldKey, String? value) {
    // 仅作空白字符过滤等简单结构清洗，不改变业务语义
    if (fieldKey == 'bank_name' && value != null) {
      return value.trim();
    }
    return value;
  }
}

/// 统一 Schema 迁移策略注册中心与路径解算器
class MigrationRegistry {
  static final List<MigrationStrategy> _strategies = [
    DebitCardV1ToV2MigrationStrategy(),
  ];

  /// 允许在测试期动态添加迁移策略
  static void register(MigrationStrategy strategy) {
    _strategies.add(strategy);
  }

  /// 获取当前所有已注册的迁移策略
  static List<MigrationStrategy> get strategies =>
      List.unmodifiable(_strategies);

  /// 根据当前版本与目标版本，解算一条逐级向上迁移的策略路径。
  /// 返回 null 代表没有可行的迁移路径。
  static List<MigrationStrategy>? findPath(int fromVersion, int toVersion) {
    if (fromVersion == toVersion) return [];
    if (fromVersion > toVersion) return null; // 仅支持低版本向高版本迁移

    final path = <MigrationStrategy>[];
    int current = fromVersion;

    while (current < toVersion) {
      MigrationStrategy? nextStep;
      for (final strategy in _strategies) {
        if (strategy.fromVersion == current &&
            strategy.toVersion <= toVersion) {
          if (nextStep == null || strategy.toVersion > nextStep.toVersion) {
            nextStep = strategy;
          }
        }
      }
      if (nextStep == null) {
        return null; // 无法解算后续路径
      }
      path.add(nextStep);
      current = nextStep.toVersion;
    }
    return path;
  }

  /// 判断从 fromVersion 到 toVersion 是否存在可行的迁移路径
  static bool hasPath(int fromVersion, int toVersion) {
    return findPath(fromVersion, toVersion) != null;
  }
}
