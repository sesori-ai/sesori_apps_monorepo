import "package:flutter/material.dart";
import "package:flutter/semantics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/isolated_activity_indicator.dart";

void main() {
  Widget wrap(Widget child, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Center(
          child: SizedBox.square(dimension: 20, child: child),
        ),
      ),
    );
  }

  testWidgets("uses a smooth indeterminate spinner behind a repaint boundary", (tester) async {
    final handle = tester.ensureSemantics();
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
    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNull,
    );
    expect(tester.hasRunningAnimations, isTrue);

    final data = tester.getSemantics(find.byType(IsolatedActivityIndicator)).getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);

    handle.dispose();
  });

  testWidgets("reduced motion stays static with loading-spinner semantics", (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const IsolatedActivityIndicator(strokeWidth: 2, color: Colors.blue),
        reduceMotion: true,
      ),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);

    final data = tester.getSemantics(find.byType(IsolatedActivityIndicator)).getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);
    expect(data.value, isEmpty);

    handle.dispose();
  });
}
