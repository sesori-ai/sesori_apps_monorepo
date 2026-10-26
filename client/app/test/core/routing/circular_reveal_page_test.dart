import "dart:async";
import "dart:math" as math;

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_mobile/core/routing/circular_reveal_page.dart";

const _screen = Size(400, 800);
const _home = Key("home");
const _page = Key("page");
const _fallback = Key("fallback");

/// The + near the bottom right; the farthest corner is the top left.
const _origin = FractionalOffset(0.9, 0.9);
final _centre = _origin.alongSize(_screen);
final _fullRadius = math.sqrt(360 * 360 + 720 * 720);

Future<GoRouter> _pumpApp({required WidgetTester tester}) async {
  await tester.binding.setSurfaceSize(_screen);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (_, _) => const ColoredBox(key: _home, color: Color(0xFF000000)),
        routes: [
          GoRoute(
            path: "new",
            pageBuilder: (_, state) => CircularRevealPage(
              key: state.pageKey,
              origin: _origin,
              fallbackTransitionsBuilder: (_, _, _, child) => KeyedSubtree(key: _fallback, child: child),
              child: const ColoredBox(key: _page, color: Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      darkTheme: ThemeData(brightness: Brightness.dark),
      routerConfig: router,
    ),
  );
  return router;
}

/// What paints around the page: the page below's dim, the circle's shadow and
/// tint, and the clipped page itself.
RenderObject _reveal({required WidgetTester tester}) =>
    tester.renderObject(find.ancestor(of: find.byKey(_page), matching: find.byType(CustomPaint)).first);

/// The bounds of the circle the page shows through.
Rect _circle({required WidgetTester tester}) {
  final clipPath = tester.widget<ClipPath>(
    find.ancestor(of: find.byKey(_page), matching: find.byType(ClipPath)).first,
  );
  final clipper = clipPath.clipper;
  if (clipper == null) throw StateError("The page is not clipped");
  return clipper.getClip(_screen).getBounds();
}

double _radius({required WidgetTester tester}) => _circle(tester: tester).width / 2;

/// The radius the page's route animation calls for right now, eased.
double _easedRadius({required WidgetTester tester}) {
  final animation = ModalRoute.of(tester.element(find.byKey(_page)))?.animation;
  if (animation == null) throw StateError("The page has no route animation");
  return _fullRadius * Curves.easeInOutCubic.transform(animation.value);
}

bool _swipeInProgress({required WidgetTester tester}) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).userGestureInProgress;

void main() {
  testWidgets("the page grows out of its origin over a still page, and shrinks back into it", (tester) async {
    final router = await _pumpApp(tester: tester);

    unawaited(router.push("/new"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Midway, the eased circle has grown partway to the farthest corner.
    expect(_circle(tester: tester).center, offsetMoreOrLessEquals(_centre, epsilon: 0.01));
    expect(_radius(tester: tester), closeTo(_easedRadius(tester: tester), 0.5));
    expect(_radius(tester: tester), closeTo(_fullRadius / 2, _fullRadius / 10));
    expect(tester.getRect(find.byKey(_home)), Offset.zero & _screen);

    await tester.pumpAndSettle();
    // Fully open, it covers the screen, corners included.
    expect(_circle(tester: tester), Offset.zero & _screen);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final shrinking = _radius(tester: tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_circle(tester: tester).center, offsetMoreOrLessEquals(_centre, epsilon: 0.01));
    expect(_radius(tester: tester), closeTo(_easedRadius(tester: tester), 0.5));
    expect(_radius(tester: tester), lessThan(shrinking));
    expect(tester.getRect(find.byKey(_home)), Offset.zero & _screen);

    await tester.pumpAndSettle();
    expect(find.byKey(_page), findsNothing);
    expect(find.byKey(_fallback), findsNothing);
  });

  testWidgets("the page below dims and the circle casts a shadow while it grows, gone once open", (tester) async {
    final router = await _pumpApp(tester: tester);

    unawaited(router.push("/new"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      _reveal(tester: tester),
      paints
        ..rect(rect: Offset.zero & _screen)
        ..circle(x: _centre.dx, y: _centre.dy + 2, hasMaskFilter: true)
        ..clipPath()
        ..rect(rect: Offset.zero & _screen, color: const Color(0xFFFFFFFF)),
    );
    // A light page gets no tint over the circle.
    expect(_reveal(tester: tester), paintsExactlyCountTimes(#drawCircle, 1));

    await tester.pumpAndSettle();
    // Fully open, only the page paints.
    expect(_reveal(tester: tester), paintsExactlyCountTimes(#drawRect, 1));
    expect(_reveal(tester: tester), paintsExactlyCountTimes(#drawCircle, 0));

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _reveal(tester: tester),
      paints
        ..rect(rect: Offset.zero & _screen)
        ..circle(x: _centre.dx, y: _centre.dy + 2, hasMaskFilter: true)
        ..clipPath(),
    );
  });

  testWidgets("on a dark page the circle also lightens while it grows", (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final router = await _pumpApp(tester: tester);

    unawaited(router.push("/new"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      _reveal(tester: tester),
      paints
        ..rect(rect: Offset.zero & _screen)
        ..circle(x: _centre.dx, y: _centre.dy, hasMaskFilter: true)
        ..clipPath()
        ..rect(rect: Offset.zero & _screen, color: const Color(0xFFFFFFFF))
        ..circle(x: _centre.dx, y: _centre.dy, hasMaskFilter: false),
    );

    await tester.pumpAndSettle();
    expect(_reveal(tester: tester), paintsExactlyCountTimes(#drawCircle, 0));
  });

  testWidgets("under reduced motion the page moves as its fallback does, with no circle", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = await _pumpApp(tester: tester);

    unawaited(router.push("/new"));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_page), findsOneWidget);
    expect(find.byKey(_fallback), findsOneWidget);
    expect(find.ancestor(of: find.byKey(_page), matching: find.byType(ClipPath)), findsNothing);
  });

  testWidgets(
    "an edge swipe moves the circle with the finger, and a short slow release springs it back open",
    (tester) async {
      final router = await _pumpApp(tester: tester);
      unawaited(router.push("/new"));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(5, 400));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      final before = _radius(tester: tester);
      expect(before, lessThan(_fullRadius));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      // A quarter of the width takes a quarter off the radius, without easing.
      expect(_radius(tester: tester), closeTo(before - _fullRadius / 4, 1));
      expect(_swipeInProgress(tester: tester), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, "/new");
      expect(_circle(tester: tester), Offset.zero & _screen);
      expect(_swipeInProgress(tester: tester), isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    "an edge swipe released past halfway, or flicked, closes the page",
    (tester) async {
      final router = await _pumpApp(tester: tester);

      unawaited(router.push("/new"));
      await tester.pumpAndSettle();
      await tester.timedDragFrom(const Offset(5, 400), const Offset(300, 0), const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, "/");
      expect(find.byKey(_page), findsNothing);
      expect(_swipeInProgress(tester: tester), isFalse);

      unawaited(router.push("/new"));
      await tester.pumpAndSettle();
      await tester.timedDragFrom(const Offset(5, 400), const Offset(80, 0), const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, "/");
      expect(find.byKey(_page), findsNothing);
      expect(_swipeInProgress(tester: tester), isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets("off iOS an edge drag leaves the page open", (tester) async {
    final router = await _pumpApp(tester: tester);
    unawaited(router.push("/new"));
    await tester.pumpAndSettle();

    await tester.timedDragFrom(const Offset(5, 400), const Offset(300, 0), const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, "/new");
    expect(_circle(tester: tester), Offset.zero & _screen);
  });
}
