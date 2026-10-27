import 'dart:async';

/// 平台剪贴板的最小边界，便于在不暴露复制内容的前提下测试自动清理规则。
abstract interface class SensitiveClipboardPort {
  Future<void> writeText(String value);

  Future<String?> readText();
}

/// 将敏感内容复制到系统剪贴板后，延时清理且不覆盖用户后来复制的内容。
class SensitiveClipboardController {
  SensitiveClipboardController({
    required this.clipboard,
    this.clearDelay = const Duration(seconds: 60),
  });

  final SensitiveClipboardPort clipboard;
  final Duration clearDelay;
  Timer? _clearTimer;
  int _generation = 0;

  Future<void> copy(String value) async {
    await clipboard.writeText(value);
    _clearTimer?.cancel();
    final generation = ++_generation;
    _clearTimer = Timer(clearDelay, () {
      unawaited(_clearIfStillOwned(value, generation));
    });
  }

  Future<void> _clearIfStillOwned(String value, int generation) async {
    if (generation != _generation) return;
    final current = await clipboard.readText();
    if (generation == _generation && current == value) {
      await clipboard.writeText('');
    }
  }

  void dispose() {
    _generation++;
    _clearTimer?.cancel();
  }
}
