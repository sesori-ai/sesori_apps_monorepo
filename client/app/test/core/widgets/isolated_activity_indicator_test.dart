import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/isolated_activity_indicator.dart";

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

  testWidgets("isolates the spinner's repaints behind its own boundary", (tester) async {
    await tester.pumpWidget(
      wrap(const IsolatedActivityIndicator(strokeWidth: 2, color: Colors.blue)),
    );

    expect(
      find.descendant(
        of: find.byType(IsolatedActivityIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );

    // The spinner itself is the stock indeterminate indicator, so ticker
    // muting on covered routes comes from the framework.
    final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(indicator.value, isNull);
  });

  testWidgets("renders a static arc when the OS asks for reduced motion", (tester) async {
    await tester.pumpWidget(
      wrap(
        const IsolatedActivityIndicator(strokeWidth: 2, color: Colors.blue),
        reduceMotion: true,
      ),
    );

    final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(indicator.value, isNotNull);

    // A determinate arc schedules no animation frames.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
