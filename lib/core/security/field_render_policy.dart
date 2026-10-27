// This file is the ONLY source of truth for field safety rules.
// No UI logic is allowed here.

import '../template/sensitive_level.dart';
export '../template/sensitive_level.dart';

/// 资料字段渲染安全规则策略判断层。
///
/// 职责：仅负责判断各种展示与复制安全规则（返回布尔值），不参与生成任何具体的字符串（如掩码 `******`）。
class FieldRenderPolicy {
  /// 是否在 UI 层渲染该级别的字段。
  /// forbidden 返回 false，表示完全不渲染（直接过滤），其余级别返回 true。
  static bool shouldRenderField(SensitiveLevel level) {
    return level != SensitiveLevel.forbidden;
  }

  /// 是否需要对该级别字段进行掩码处理。
  /// high 级别返回 true，其余返回 false。
  static bool shouldMaskField(SensitiveLevel level) {
    return level == SensitiveLevel.high;
  }

  /// 是否允许展示特定 Key 的字段 (如全局禁止 note 字段)
  static bool shouldRenderFieldKey(String fieldKey) {
    return fieldKey != 'note';
  }

  /// 综合安全规则过滤判断：某个字段是否应当在 UI/Builder 中展示
  static bool isFieldAllowed(String fieldKey, SensitiveLevel level) {
    return shouldRenderFieldKey(fieldKey) && shouldRenderField(level);
  }
}
