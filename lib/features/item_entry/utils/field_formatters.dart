import 'package:flutter/services.dart';

/// 身份证位置感知格式约束格式器
class IdCardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final resultText = _sanitize(newValue.text);

    // 常规编辑不重建 TextEditingValue，保留输入法正在维护的光标和 composing 区域。
    if (resultText == newValue.text) return newValue;

    return TextEditingValue(
      text: resultText,
      selection: TextSelection(
        baseOffset: _resultOffsetAt(
          newValue.text,
          newValue.selection.baseOffset,
        ),
        extentOffset: _resultOffsetAt(
          newValue.text,
          newValue.selection.extentOffset,
        ),
      ),
    );
  }

  String _sanitize(String text) {
    // 如果整体长度超过 18，限制到 18。
    final limitText = text.substring(0, text.length > 18 ? 18 : text.length);

    final buffer = StringBuffer();
    for (var i = 0; i < limitText.length; i++) {
      final char = limitText[i];
      if (i < 17) {
        // 前 17 位只允许纯数字
        if (RegExp(r'[0-9]').hasMatch(char)) {
          buffer.write(char);
        } else {
          // 非数字直接跳过
          continue;
        }
      } else if (i == 17) {
        // 第 18 位只允许数字或大小写 X/x，并把 x 自动转为 X
        if (RegExp(r'[0-9Xx]').hasMatch(char)) {
          buffer.write(char.toUpperCase());
        } else {
          continue;
        }
      }
    }

    return buffer.toString();
  }

  int _resultOffsetAt(String source, int offset) {
    final clampedOffset = offset.clamp(0, source.length);
    return _sanitize(source.substring(0, clampedOffset)).length;
  }
}

/// 限制只能输入纯数字（不包括空格等其他任何字符，如卡号、整数使用）
class PureNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (RegExp(r'[0-9]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    final resultText = buffer.toString();
    return TextEditingValue(
      text: resultText,
      selection: TextSelection.collapsed(offset: resultText.length),
    );
  }
}

/// 电话号码允许的字符：数字、空格、+、-、左右括号
class PhoneCharactersFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (RegExp(r'[0-9\s+\-()]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    final resultText = buffer.toString();
    return TextEditingValue(
      text: resultText,
      selection: TextSelection.collapsed(offset: resultText.length),
    );
  }
}

/// 小数值允许的字符：数字，且至多只包含一个小数点
class DecimalNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    var dotCount = 0;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '.') {
        dotCount++;
        if (dotCount == 1) {
          buffer.write(char);
        }
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    final resultText = buffer.toString();
    return TextEditingValue(
      text: resultText,
      selection: TextSelection.collapsed(offset: resultText.length),
    );
  }
}
