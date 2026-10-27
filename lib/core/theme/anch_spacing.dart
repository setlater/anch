/// 安册间距 token。
///
/// 用途：统一页面内边距、组件间距、列表间距。
abstract final class AnchSpacing {
  AnchSpacing._();

  /// 极小间距，4pt
  static const double xs = 4;

  /// 小间距，8pt
  static const double sm = 8;

  /// 中间距，12pt
  static const double md = 12;

  /// 大间距，16pt
  static const double lg = 16;

  /// 较大间距，20pt
  static const double xl = 20;

  /// 超大间距，24pt
  static const double xxl = 24;

  /// 页面大区块间距。
  static const double sectionGap = 24;

  /// 紧凑与常规手机页面水平内边距。
  static const double page = 16;

  /// 宽度不小于 600 的页面水平内边距。
  static const double pageWide = 24;
}
