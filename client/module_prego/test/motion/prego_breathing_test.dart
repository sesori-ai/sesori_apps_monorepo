import "dart:math";

import "package:clock/clock.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The breath steps on a repeating timer, so these tests pump fixed durations
/// and never `pumpAndSettle`.
void main() {
  /// The breath follows the device clock, here the test's fake one.
  void clockTestWidgets(String description, WidgetTesterCallback callback) => testWidgets(
    description,
    (tester) => withClock(Clock(() => tester.binding.clock.now()), () => callback(tester)),
  );

  Widget harness(List<Widget> children, {bool disableAnimations = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: children),
    ),
  );

  const a = PregoBreathing(key: Key("a"), active: true, child: SizedBox.square(dimension: 10));
  const b = PregoBreathing(key: Key("b"), active: true, child: SizedBox.square(dimension: 10));

  double opacityOf(WidgetTester tester, {String key = "a"}) => tester
      .widget<FadeTransition>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(FadeTransition)))
      .opacity
      .value;

  clockTestWidgets("fades to about a third and back every 1.6 seconds, every glyph on one phase", (tester) async {
    await tester.pumpWidget(harness([a]));
    final breath = <double>[];
    for (var step = 0; step < 16; step++) {
      await tester.pump(const Duration(milliseconds: 100));
      breath.add(opacityOf(tester));
    }
    expect(breath.reduce(min), closeTo(0.35, 0.02));
    expect(breath.reduce(max), closeTo(1, 0.02));
    // A breath later, the same opacity.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(opacityOf(tester), closeTo(breath.last, 0.001));

    // One mounted mid-breath joins the same phase.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(harness([a, b]));
    for (var step = 0; step < 4; step++) {
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacityOf(tester, key: "b"), opacityOf(tester));
    }
  });

  clockTestWidgets("eases the breath out to full opacity and back in, never jumping", (tester) async {
    Widget glyph({required bool active}) =>
        PregoBreathing(key: const Key("a"), active: active, child: const SizedBox.square(dimension: 10));

    // Stop near the bottom of a breath, where a snap to full would show most.
    await tester.pumpWidget(harness([glyph(active: true)]));
    var bottom = 1.0;
    while (bottom > 0.4) {
      await tester.pump(const Duration(milliseconds: 25));
      bottom = opacityOf(tester);
    }

    Future<List<double>> sample({int steps = 20}) async => [
      for (var step = 0; step < steps; step++)
        await tester.pump(const Duration(milliseconds: 25)).then((_) => opacityOf(tester)),
    ];
    double largestStep(List<double> values) =>
        [for (var i = 1; i < values.length; i++) (values[i] - values[i - 1]).abs()].reduce(max);

    await tester.pumpWidget(harness([glyph(active: false)]));
    final easingOut = [bottom, opacityOf(tester), ...await sample()];
    expect(easingOut.last, 1);
    expect(largestStep(easingOut), lessThan(0.15));
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: "an inactive glyph follows no clock");

    await tester.pumpWidget(harness([glyph(active: true)]));
    // A whole breath, to reach its bottom wherever the shared phase is.
    final easingIn = [1.0, opacityOf(tester), ...await sample(steps: 80)];
    expect(largestStep(easingIn), lessThan(0.15));
    expect(easingIn.reduce(min), lessThan(0.9), reason: "breathing again");
  });

  testWidgets("an inactive glyph holds full opacity and schedules nothing", (tester) async {
    await tester.pumpWidget(
      harness([const PregoBreathing(key: Key("a"), active: false, child: SizedBox.square(dimension: 10))]),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(opacityOf(tester), 1);
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets("holds full opacity and schedules nothing under reduced motion", (tester) async {
    await tester.pumpWidget(harness([a], disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 800));

    expect(opacityOf(tester), 1);
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  clockTestWidgets("stops stepping while backgrounded and once no glyph breathes", (tester) async {
    await tester.pumpWidget(harness([a]));
    await tester.pump(const Duration(milliseconds: 100));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(opacityOf(tester), 1);
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.binding.delayed(const Duration(milliseconds: 30));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(harness(const []));
    await tester.pump();
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
