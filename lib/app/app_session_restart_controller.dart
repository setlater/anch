/// 协调一次完整的应用会话重建。
///
/// 物理清空本机资料会关闭当前数据库并删除其密钥，后续页面不能继续使用
/// 旧依赖树。该控制器由应用根节点持有，并确保同一时刻只执行一次重建。
class AppSessionRestartController {
  AppSessionRestartController({required this.restartSessionCallback});

  final Future<void> Function() restartSessionCallback;
  Future<void>? _inFlightRestart;

  Future<void> restart() {
    final inFlightRestart = _inFlightRestart;
    if (inFlightRestart != null) return inFlightRestart;

    final restart = Future<void>.sync(restartSessionCallback);
    _inFlightRestart = restart;
    restart.then<void>(
      (_) {
        if (identical(_inFlightRestart, restart)) {
          _inFlightRestart = null;
        }
      },
      onError: (Object _, StackTrace _) {
        if (identical(_inFlightRestart, restart)) {
          _inFlightRestart = null;
        }
      },
    );
    return restart;
  }
}
