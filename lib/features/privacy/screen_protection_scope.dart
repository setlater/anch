import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/dependency_provider.dart';
import '../../core/security/screen_protection_controller.dart';
import '../../core/security/app_startup_failure.dart';
import '../../core/widgets/anch_startup_failure_page.dart';
import '../../core/theme/anch_colors.dart';

class ScreenProtectionScope extends StatefulWidget {
  const ScreenProtectionScope({
    required this.child,
    this.sensitive = true,
    super.key,
  });

  final Widget child;
  final bool sensitive;

  @override
  State<ScreenProtectionScope> createState() => _ScreenProtectionScopeState();
}

class _ScreenProtectionScopeState extends State<ScreenProtectionScope> {
  ScreenProtectionController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DependencyProvider.maybeOf(
      context,
    )?.screenProtectionBundle?.controller;
    if (identical(next, _controller)) return;
    if (_controller != null) {
      unawaited(_controller!.setContentSensitivity(this, null));
    }
    _controller = next;
    if (next != null) {
      unawaited(next.setContentSensitivity(this, widget.sensitive));
    }
  }

  @override
  void didUpdateWidget(ScreenProtectionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensitive == widget.sensitive || _controller == null) return;
    unawaited(_controller!.setContentSensitivity(this, widget.sensitive));
  }

  @override
  void dispose() {
    if (_controller != null) {
      unawaited(_controller!.setContentSensitivity(this, null));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final failed = controller.hasProtectionFailure;
        final blocked =
            failed ||
            (controller.requiresProtection(widget.sensitive) &&
                !controller.isForegroundProtected);
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Offstage(
              offstage: blocked,
              child: ExcludeFocus(excluding: blocked, child: widget.child),
            ),
            if (blocked)
              Material(
                color: context.anchColors.background,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(failed ? '无法启用屏幕保护' : '正在启用屏幕保护'),
                      if (failed)
                        TextButton(
                          onPressed: () =>
                              unawaited(controller.retryProtection()),
                          child: const Text('重试屏幕保护'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ScreenProtectionLifecycleObserver extends StatefulWidget {
  const ScreenProtectionLifecycleObserver({
    required this.controller,
    required this.child,
    super.key,
  });

  final ScreenProtectionController controller;
  final Widget child;

  @override
  State<ScreenProtectionLifecycleObserver> createState() =>
      _ScreenProtectionLifecycleObserverState();
}

class _ScreenProtectionLifecycleObserverState
    extends State<ScreenProtectionLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(widget.controller.handleLifecycleState(state));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final failed = widget.controller.hasProtectionFailure;
      return Stack(
        fit: StackFit.expand,
        textDirection: TextDirection.ltr,
        children: [
          Offstage(
            offstage: failed,
            child: ExcludeFocus(excluding: failed, child: widget.child),
          ),
          if (failed)
            AnchStartupFailureApp(
              failure: AppStartupException(
                AppStartupFailureType.screenProtectionUnavailable,
                '屏幕内容保护暂不可用。',
              ),
              onRetry: () => unawaited(widget.controller.retryProtection()),
            ),
        ],
      );
    },
  );
}
