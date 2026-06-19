import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

/// Regression guard for the install-commands disclosure in `_BridgeOfflineView`
/// (`bridge_offline_view.dart`). That view animates the disclosure open/closed
/// with the subtree reproduced verbatim below:
///
///   AnimatedSize(
///     alignment: Alignment.topCenter,
///     child: Visibility(visible: _showInstallCommands, maintainState: true, child: ...),
///   )
///
/// A review raised the concern that `AnimatedSize` would not animate because
/// "only the opacity changes / the child is always the same size". That holds
/// for `Visibility(maintainSize: true)` (which keeps the slot sized and toggles
/// an `Opacity`), but NOT for the configuration used here. With the default
/// `maintainSize: false`, `Visibility` wraps the child in an `Offstage` that
/// collapses to **zero height** when hidden, so the child's laid-out size
/// genuinely changes 0 ↔ full height — which is exactly what drives
/// `AnimatedSize`. These tests assert the height is mid-transition partway
/// through the animation (not snapped to either endpoint), proving it animates.
void main() {
  const expandedHeight = 200.0;
  const animationDuration = Duration(milliseconds: 220);

  Widget harness({required ValueNotifier<bool> visible}) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, isVisible, _) => AnimatedSize(
              duration: animationDuration,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Visibility(
                visible: isVisible,
                maintainState: true,
                child: const SizedBox(
                  width: 100,
                  height: expandedHeight,
                  child: ColoredBox(color: Color(0xFF000000)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double animatedSizeHeight(WidgetTester tester) => tester.getSize(find.byType(AnimatedSize)).height;

  testWidgets("collapsed disclosure occupies zero height", (tester) async {
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(harness(visible: visible));
    await tester.pumpAndSettle();

    expect(animatedSizeHeight(tester), 0.0);
  });

  testWidgets("expanding animates the height between the two endpoints", (tester) async {
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(harness(visible: visible));
    await tester.pumpAndSettle();

    // Open the disclosure.
    visible.value = true;
    await tester.pump(); // process the rebuild, start the animation
    await tester.pump(const Duration(milliseconds: 110)); // ~halfway through 220ms

    final midHeight = animatedSizeHeight(tester);
    // If AnimatedSize did not animate it would snap straight to expandedHeight
    // (or stay at 0); a value strictly in between proves a running animation.
    expect(midHeight, greaterThan(0.0));
    expect(midHeight, lessThan(expandedHeight));

    await tester.pumpAndSettle();
    expect(animatedSizeHeight(tester), expandedHeight);
  });

  testWidgets("collapsing animates the height back down", (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);

    await tester.pumpWidget(harness(visible: visible));
    await tester.pumpAndSettle();
    expect(animatedSizeHeight(tester), expandedHeight);

    // Close the disclosure.
    visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));

    final midHeight = animatedSizeHeight(tester);
    expect(midHeight, greaterThan(0.0));
    expect(midHeight, lessThan(expandedHeight));

    await tester.pumpAndSettle();
    expect(animatedSizeHeight(tester), 0.0);
  });
}
