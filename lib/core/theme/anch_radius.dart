/// 石墨资料册圆角 token。
abstract final class AnchRadius {
  AnchRadius._();

  /// 输入框与平面操作项。
  static const double sm = 8;

  /// 搜索、按钮与选择项。
  static const double md = 12;

  /// 资料、字段与号码分组。
  static const double lg = 14;

  /// 对话框、Bottom Sheet 与模态容器。
  static const double xl = 16;

  /// 兼容旧调用；不得用于普通页面大卡片。
  static const double xxl = 16;

  /// 小型状态签注。
  static const double status = 6;

  /// 浮动主操作。
  static const double fab = 15;

  /// 只用于确有胶囊语义的控件，不作为默认标签圆角。
  static const double pill = 999;
}
