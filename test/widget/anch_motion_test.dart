import 'package:anch/core/theme/anch_motion.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('减少动态效果时，Android 页面转场直接显示目标页面', (tester) async {
    const child = SizedBox(key: Key('motion_destination'));
    late Widget transition;

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(
          tester.view,
        ).copyWith(disableAnimations: true),
        child: Builder(
          builder: (context) {
            final route = MaterialPageRoute<void>(builder: (_) => child);
            final builder = AnchMotion
                .pageTransitionsTheme
                .builders[TargetPlatform.android]!;
            transition = builder.buildTransitions(
              route,
              context,
              const AlwaysStoppedAnimation<double>(0),
              const AlwaysStoppedAnimation<double>(0),
              child,
            );
            return transition;
          },
        ),
      ),
    );

    expect(identical(transition, child), isTrue);
    expect(find.byKey(const Key('motion_destination')), findsOneWidget);
  });

  testWidgets('减少动态效果时，底部弹层不保留进入或退出时长', (tester) async {
    final observer = _RouteObserver();

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(
          tester.view,
        ).copyWith(disableAnimations: true),
        child: MaterialApp(
          theme: AnchTheme.light,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  showAnchBottomSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      key: Key('motion_bottom_sheet'),
                      height: 80,
                    ),
                  );
                },
                child: const Text('打开弹层'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开弹层'));
    await tester.pump();

    final route = observer.lastPushedRoute;
    expect(route, isA<ModalBottomSheetRoute<void>>());
    final bottomSheetRoute = route! as ModalBottomSheetRoute<void>;
    expect(bottomSheetRoute.transitionDuration, Duration.zero);
    expect(bottomSheetRoute.reverseTransitionDuration, Duration.zero);
    expect(find.byKey(const Key('motion_bottom_sheet')), findsOneWidget);
  });
}
