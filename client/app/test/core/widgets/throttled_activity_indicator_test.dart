import "package:flutter/material.dart";
import "package:flutter/semantics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/throttled_activity_indicator.dart";

void main() {
  Widget wrap(
    Widget child, {
    bool reduceMotion = false,
    bool tickerEnabled = true,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: TickerMode(
          enabled: tickerEnabled,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  List<double> transform(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(ThrottledActivityIndicator),
      matching: find.byType(Transform),
    );
    return List<double>.of(tester.widget<Transform>(finder).transform.storage);
  }

  testWidgets("steps at a fixed low frequency behind a repaint boundary", (tester) async {
    await tester.pumpWidget(
      wrap(const ThrottledActivityIndicator(strokeWidth: 2, color: Colors.blue)),
    );

    expect(
      find.descendant(
        of: find.byType(ThrottledActivityIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNotNull,
    );

    final initialTransform = transform(tester);
    await tester.pump(const Duration(milliseconds: 124));
    expect(transform(tester), initialTransform);

    await tester.pump(const Duration(milliseconds: 1));
    expect(transform(tester), isNot(initialTransform));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets("stops while TickerMode is disabled and resumes when enabled", (tester) async {
    const indicator = ThrottledActivityIndicator(
      key: ValueKey("indicator"),
      strokeWidth: 2,
      color: Colors.blue,
    );
    await tester.pumpWidget(wrap(indicator, tickerEnabled: false));

    final disabledTransform = transform(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(transform(tester), disabledTransform);

    await tester.pumpWidget(wrap(indicator));
    await tester.pump(const Duration(milliseconds: 125));
    final enabledTransform = transform(tester);
    expect(enabledTransform, isNot(disabledTransform));

    await tester.pumpWidget(wrap(indicator, tickerEnabled: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(transform(tester), enabledTransform);
  });

  testWidgets("reduced motion stays static with loading-spinner semantics", (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const ThrottledActivityIndicator(strokeWidth: 2, color: Colors.blue),
        reduceMotion: true,
      ),
    );

    final initialTransform = transform(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(transform(tester), initialTransform);
    expect(tester.hasRunningAnimations, isFalse);

    final data = tester.getSemantics(find.byType(ThrottledActivityIndicator)).getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);
    expect(data.value, isEmpty);

    handle.dispose();
  });
}
