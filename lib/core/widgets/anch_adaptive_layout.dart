import 'package:flutter/material.dart';

/// 按应用窗口宽度划分的全局布局等级。
///
/// 仅用于页面级结构决策；组件内部应继续依据父容器约束重排。
enum AnchWindowWidthClass { compact, medium, expanded }

/// 按应用可用窗口高度划分的全局布局等级。
///
/// 低高度通常来自横屏、分屏或软键盘展开。它不用于猜测设备类型，
/// 仅让主动声明支持紧凑模式的页面收起非关键留白。
enum AnchWindowHeightClass { compact, medium, expanded }

abstract final class AnchLayoutBreakpoints {
  AnchLayoutBreakpoints._();

  static const double mediumWidth = 600;
  static const double expandedWidth = 840;
  static const double mediumHeight = 480;
  static const double expandedHeight = 900;
  static const double maxContentWidth = 840;

  static AnchWindowWidthClass forWindowWidth(double width) {
    if (width < mediumWidth) return AnchWindowWidthClass.compact;
    if (width < expandedWidth) return AnchWindowWidthClass.medium;
    return AnchWindowWidthClass.expanded;
  }

  static AnchWindowHeightClass forWindowHeight(double height) {
    if (height < mediumHeight) return AnchWindowHeightClass.compact;
    if (height < expandedHeight) return AnchWindowHeightClass.medium;
    return AnchWindowHeightClass.expanded;
  }
}

/// 将当前窗口等级提供给页面级布局。
class AnchLayoutScope extends InheritedWidget {
  const AnchLayoutScope({
    super.key,
    required this.widthClass,
    required this.heightClass,
    required super.child,
  });

  final AnchWindowWidthClass widthClass;
  final AnchWindowHeightClass heightClass;

  static AnchWindowWidthClass of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AnchLayoutScope>()
            ?.widthClass ??
        AnchLayoutBreakpoints.forWindowWidth(MediaQuery.sizeOf(context).width);
  }

  static AnchWindowHeightClass heightOf(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.bottom;
    return context
            .dependOnInheritedWidgetOfExactType<AnchLayoutScope>()
            ?.heightClass ??
        (availableHeight > 0
            ? AnchLayoutBreakpoints.forWindowHeight(availableHeight)
            : AnchWindowHeightClass.medium);
  }

  @override
  bool updateShouldNotify(AnchLayoutScope oldWidget) {
    return widthClass != oldWidget.widthClass ||
        heightClass != oldWidget.heightClass;
  }
}

/// 将多个等宽子项在空间不足时由横排改为纵排。
///
/// 最小宽度按父容器的实际约束计算，避免使用设备型号或全局屏幕宽度。
class AnchResponsiveColumns extends StatelessWidget {
  const AnchResponsiveColumns({
    super.key,
    required this.children,
    required this.minChildWidth,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minChildWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.length < 2) {
      return children.isEmpty ? const SizedBox.shrink() : children.single;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final requiredWidth =
            children.length * minChildWidth + (children.length - 1) * spacing;
        if (constraints.maxWidth >= requiredWidth) {
          return Row(
            key: const Key('anch_responsive_columns_row'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                Expanded(child: children[index]),
                if (index < children.length - 1) SizedBox(width: spacing),
              ],
            ],
          );
        }

        return Column(
          key: const Key('anch_responsive_columns_column'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1) SizedBox(height: spacing),
            ],
          ],
        );
      },
    );
  }
}

/// 根据卡片最小可读宽度计算网格列数。
abstract final class AnchAdaptiveGrid {
  AnchAdaptiveGrid._();

  static int columnCountFor({
    required double availableWidth,
    required double minTileWidth,
    required double spacing,
    int maxColumns = 4,
  }) {
    final count = ((availableWidth + spacing) / (minTileWidth + spacing))
        .floor();
    if (count < 1) return 1;
    return count > maxColumns ? maxColumns : count;
  }
}
