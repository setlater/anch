import 'schema_version.dart';
import 'type_definition.dart';
import 'builtin_templates.dart';

/// 负责子类型模板的版本兼容性与 Fallback 计算判定
class SchemaCompatibilityResolver {
  /// 根据唯一子类型标识 key 和所需版本号获取匹配的兼容模板。
  /// 规则：
  /// 1. 如果指定了 version，尝试精确匹配。
  /// 2. 如果精确匹配失败或者 version 为 null，尝试 fallback 到最新的 compatible version
  ///    (即所有已注册的同类型模板中，版本最新且能够兼容所需版本的模板)。
  /// 3. 如果完全没有兼容版本，则返回 null。
  static TypeDefinition? resolveCompatibleTemplate(
    String typeKey,
    int? version,
  ) {
    if (version != null) {
      // 1. 尝试精确匹配
      for (final type in BuiltinTemplates.types) {
        if (type.typeKey == typeKey && type.version == version) {
          return type;
        }
      }
    }

    // 2. 精确匹配未找到，或者 version 为 null，获取该 typeKey 下的所有注册版本
    final allTemplates = BuiltinTemplates.types
        .where((type) => type.typeKey == typeKey)
        .toList();
    if (allTemplates.isEmpty) {
      return null;
    }

    // 按版本号从大到小排序，最新版本优先
    allTemplates.sort((a, b) => b.version.compareTo(a.version));

    if (version == null) {
      // 如果未指定版本，默认返回最新的最新版本
      return allTemplates.first;
    }

    // 3. 寻找与所请求版本兼容的最新已注册版本
    for (final type in allTemplates) {
      if (SchemaVersion.isCompatible(
        templateVersion: type.version,
        draftVersion: version,
      )) {
        return type;
      }
    }

    return null;
  }
}
