import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/throttled_activity_indicator.dart";

void main() {
  Widget wrap(Widget child, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: child,
          ),
        ),
      ),
    );
  }

  double rotationOf(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(Transform),
      ),
    );
    return transform.transform.getRotation().entry(1, 0);
  }

  testWidgets("steps the arc rotation on its own timer", (tester) async {
    await tester.pumpWidget(
      wrap(const ThrottledActivityIndicator(strokeWidth: 2, color: Colors.blue)),
    );
    final initial = rotationOf(tester);

    // One 125ms tick advances the rotation by a discrete step.
    await tester.pump(const Duration(milliseconds: 130));
    expect(rotationOf(tester), isNot(initial));

    // The arc itself is a fixed-sweep determinate indicator — no ticker.
    final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(indicator.value, isNotNull);
  });

  testWidgets("renders a static arc when the OS asks for reduced motion", (tester) async {
    await tester.pumpWidget(
      wrap(
        const ThrottledActivityIndicator(strokeWidth: 2, color: Colors.blue),
        reduceMotion: true,
      ),
    );
    final initial = rotationOf(tester);

    await tester.pump(const Duration(seconds: 1));
    expect(rotationOf(tester), initial);

    // No pending tick timer: pumping past many intervals scheduled nothing.
    // (testWidgets itself fails the test if a periodic timer leaks.)
  });

  testWidgets("cancels its timer when unmounted mid-spin", (tester) async {
    await tester.pumpWidget(
      wrap(const ThrottledActivityIndicator(strokeWidth: 2, color: Colors.blue)),
    );
    await tester.pump(const Duration(milliseconds: 130));

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    // Test completes without the framework reporting a leaked periodic timer.
  });
}
