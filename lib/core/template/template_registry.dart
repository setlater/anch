import 'builtin_templates.dart';
import 'category_definition.dart';
import 'field_definition.dart';
import 'field_value_type.dart';
import 'sensitive_level.dart';
import 'type_definition.dart';
import 'schema_compatibility_resolver.dart';

/// TemplateRegistry is a static schema configuration resolver with runtime lookup behavior. It does not mutate state.
class TemplateRegistry {
  /// 测试专用开关：绕过新建类型过滤
  static bool showAllTemplatesForTesting = false;

  /// 未知/历史字段的兜底定义（通常用于兼容高版本向低版本备份恢复时的非预期属性）
  static const FieldDefinition unknownFieldDefinition = FieldDefinition(
    fieldKey: 'unknown_field',
    label: '历史/未知字段',
    valueType: FieldValueType.text,
    sensitiveLevel: SensitiveLevel.medium,
    copyable: true,
  );

  /// 所有合法的 fieldKey 集合（只读，且全部来自 static registry）
  static final Set<String> allFieldKeys = {
    unknownFieldDefinition.fieldKey,
    ...BuiltinTemplates.types.expand(
      (type) => type.fields.map((f) => f.fieldKey),
    ),
  };

  /// 根据唯一子类型标识 key 获取对应的模板定义（带兼容性 Fallback 支持）
  static TypeDefinition? getTemplate(String typeKey, [int? version]) {
    return SchemaCompatibilityResolver.resolveCompatibleTemplate(
      typeKey,
      version,
    );
  }

  /// 优先使用当前版本字段，历史字段沿用内置定义的首次匹配，不产生 UI 依赖。
  static final Map<String, FieldDefinition> _fallbackFieldDefinitions = () {
    final result = <String, FieldDefinition>{};
    for (final type in BuiltinTemplates.types) {
      for (final field in type.fields) {
        result.putIfAbsent(field.fieldKey, () => field);
      }
    }
    return result;
  }();

  static FieldDefinition? fieldDefinitionByKey(
    TypeDefinition? typeDef,
    String key,
  ) {
    if (typeDef != null) {
      for (final field in typeDef.fields) {
        if (field.fieldKey == key) return field;
      }
    }
    return _fallbackFieldDefinitions[key];
  }

  /// 获取指定大类下的所有子类型模板定义 (仅返回各子类型的最新版本)
  static List<TypeDefinition> getTypesByCategory(String categoryKey) {
    final Map<String, TypeDefinition> latestMap = {};
    for (final type in BuiltinTemplates.types) {
      if (type.categoryKey == categoryKey) {
        final existing = latestMap[type.typeKey];
        if (existing == null || type.version > existing.version) {
          latestMap[type.typeKey] = type;
        }
      }
    }
    return latestMap.values.toList();
  }

  /// 新建入口使用的最新类型，展示名称与字段共用同一定义。
  static List<TypeDefinition> getCreatableTypes() => [
    for (final category in getCategories())
      ...getTypesByCategory(category.categoryKey).where(
        (type) => type.isAvailableForCreation || showAllTemplatesForTesting,
      ),
  ];

  /// 获取所有内置的资料大类定义
  static List<CategoryDefinition> getCategories() {
    return BuiltinTemplates.categories;
  }

  /// 声明被弃用的字段：子类型标识 (typeKey) -> 版本号 -> 被弃用字段键集合（私有存储）
  static final Map<String, Map<int, Set<String>>> _deprecatedFields = {
    'debit_card': {
      2: {'account_type'},
    },
  };

  /// 判断指定模板的特定版本中，某个字段是否已被弃用
  static bool isFieldDeprecated(String typeKey, String fieldKey, int version) {
    final typeDep = _deprecatedFields[typeKey];
    if (typeDep == null) return false;
    final verDep = typeDep[version];
    if (verDep == null) return false;
    return verDep.contains(fieldKey);
  }
}
