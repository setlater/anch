@Tags(['security'])
library;

import 'package:anch/core/security/sensitive_clipboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClipboard implements SensitiveClipboardPort {
  String? value;
  final writes = <String>[];

  @override
  Future<String?> readText() async => value;

  @override
  Future<void> writeText(String value) async {
    this.value = value;
    writes.add(value);
  }
}

void main() {
  test('复制后自动清理仍属于应用的剪贴板内容', () async {
    final clipboard = _FakeClipboard();
    final controller = SensitiveClipboardController(
      clipboard: clipboard,
      clearDelay: const Duration(milliseconds: 1),
    );

    await controller.copy('sensitive-value');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(clipboard.writes, ['sensitive-value', '']);
    controller.dispose();
  });

  test('不覆盖用户在延时期间复制的新内容', () async {
    final clipboard = _FakeClipboard();
    final controller = SensitiveClipboardController(
      clipboard: clipboard,
      clearDelay: const Duration(milliseconds: 10),
    );

    await controller.copy('sensitive-value');
    clipboard.value = 'user-new-value';
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(clipboard.value, 'user-new-value');
    expect(clipboard.writes, ['sensitive-value']);
    controller.dispose();
  });
}
