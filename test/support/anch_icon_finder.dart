import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter_test/flutter_test.dart';

/// 按安册语义图标查找组件，不绑定 SVG 路径或 Solar 原始资源名。
Finder findAnchIcon(AnchIconData icon) => find.byWidgetPredicate(
  (widget) => widget is AnchIcon && widget.icon == icon,
  description: 'AnchIcon with the requested semantic icon',
);
