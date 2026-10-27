/// 字段体系 Schema 版本生命周期定义
class SchemaVersion {
  /// v1：初始结构
  static const int v1 = 1;

  /// v2：字段扩展版本
  static const int v2 = 2;

  /// v3：兼容迁移版本（未来）
  static const int v3 = 3;

  /// 判断 template 模板版本是否与 draft 传入的数据版本兼容
  /// 规则：
  /// - 模板版本 [templateVersion] 必须大于或等于数据版本 [draftVersion] (即向下兼容模式)
  static bool isCompatible({
    required int templateVersion,
    required int draftVersion,
  }) {
    return templateVersion >= draftVersion;
  }
}
