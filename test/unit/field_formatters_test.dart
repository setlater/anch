import 'package:anch/features/item_entry/utils/field_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = IdCardNumberFormatter();

  test('身份证号中间删除后保持光标位置', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '990000199001010011',
        selection: TextSelection.collapsed(offset: 8),
      ),
      const TextEditingValue(
        text: '99000019001010011',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );

    expect(result.text, '99000019001010011');
    expect(result.selection, const TextSelection.collapsed(offset: 8));
  });

  test('过滤非法字符后将光标映射到保留字符之后', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '1234'),
      const TextEditingValue(
        text: '12a34',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );

    expect(result.text, '1234');
    expect(result.selection, const TextSelection.collapsed(offset: 2));
  });
}
