import 'package:flutter/material.dart';

/// 搜索关键词高亮辅助器（仅供 UI 层调用）。
///
/// 架构约束：
/// - 禁止访问 Provider / Mapper / Policy / Composer
/// - 仅负责将字符串按关键词切分为高亮 InlineSpan
class AnchSearchHighlighter {
  const AnchSearchHighlighter._();

  /// 将 [text] 按 [keyword] 切分并返回带高亮的 [InlineSpan]。
  ///
  /// 若无匹配则返回 null（调用方应直接显示原始字符串）。
  static InlineSpan? buildHighlightSpan(
    String text,
    String keyword,
    TextStyle base,
    TextStyle highlighted,
  ) {
    final trimKeyword = keyword.trim();
    if (trimKeyword.isEmpty || text.isEmpty) return null;

    final lowercaseText = text.toLowerCase();
    final lowercaseKeyword = trimKeyword.toLowerCase();
    if (!lowercaseText.contains(lowercaseKeyword)) return null;

    final spans = <InlineSpan>[];
    int start = 0;

    while (true) {
      final index = lowercaseText.indexOf(lowercaseKeyword, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: base));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: base));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + trimKeyword.length),
          style: highlighted,
        ),
      );
      start = index + trimKeyword.length;
    }

    return TextSpan(children: spans);
  }
}
