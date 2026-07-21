import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

const _fabKey = Key("fab");

/// The scaffold's floating action is positioned by the inner Material
/// [Scaffold], which [PregoFloatingActionAlignment] steers without replacing —
/// so these guard that the centred variant really lands on the page's centre
/// line and that it does not disturb the default trailing placement.
Widget _harness({
  required PregoFloatingActionAlignment alignment,
  double bodyHeight = 10,
  double? paneWidth,
}) {
  final scaffold = PregoGlassScaffold(
    title: "Title",
    titleMode: PregoTopNavigationTitleMode.inline,
    automaticallyImplyLeading: false,
    floatingActionAlignment: alignment,
    floatingActionButton: const SizedBox(key: _fabKey, width: 120, height: 52),
    slivers: [SliverToBoxAdapter(child: SizedBox(height: bodyHeight))],
  );
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: paneWidth == null ? scaffold : Center(child: SizedBox(width: paneWidth, child: scaffold)),
  );
}

void main() {
  testWidgets("the centred alignment puts the action on the page's centre line", (tester) async {
    await tester.pumpWidget(_harness(alignment: PregoFloatingActionAlignment.center));
    await tester.pumpAndSettle();

    final fab = tester.getRect(find.byKey(_fabKey));
    final page = tester.getRect(find.byType(PregoGlassScaffold));
    expect(fab.center.dx, moreOrLessEquals(page.center.dx, epsilon: 0.5));
  });

  testWidgets("the default alignment leaves the action on the trailing edge", (tester) async {
    await tester.pumpWidget(_harness(alignment: PregoFloatingActionAlignment.end));
    await tester.pumpAndSettle();

    final fab = tester.getRect(find.byKey(_fabKey));
    final page = tester.getRect(find.byType(PregoGlassScaffold));
    // Scaffold's endFloat inset — the placement every other screen relies on.
    expect(page.right - fab.right, moreOrLessEquals(kFloatingActionButtonMargin, epsilon: 0.5));
  });

  testWidgets("both alignments park the action at the same height", (tester) async {
    await tester.pumpWidget(_harness(alignment: PregoFloatingActionAlignment.end));
    await tester.pumpAndSettle();
    final endTop = tester.getRect(find.byKey(_fabKey)).top;

    await tester.pumpWidget(_harness(alignment: PregoFloatingActionAlignment.center));
    await tester.pumpAndSettle();
    // Centring widens the action's box but must not move it vertically — the
    // Scaffold slot still owns clearing the keyboard and the home indicator.
    expect(tester.getRect(find.byKey(_fabKey)).top, moreOrLessEquals(endTop, epsilon: 0.5));
  });

  testWidgets("the centred alignment survives a pane narrower than its margins", (tester) async {
    // The centring box is the pane width minus both endFloat margins — a pane
    // narrower than that must clamp it to zero, not hand [SizedBox] a negative
    // width and fail BoxConstraints' assert while a split pane is dragged shut.
    await tester.pumpWidget(
      _harness(
        alignment: PregoFloatingActionAlignment.center,
        paneWidth: 2 * kFloatingActionButtonMargin - 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets("the widened centring box lets drags beside the action reach the page", (tester) async {
    await tester.pumpWidget(_harness(alignment: PregoFloatingActionAlignment.center, bodyHeight: 3000));
    await tester.pumpAndSettle();

    // A point level with the action but well outside it — inside the invisible
    // box centring stretches across the page. Nothing there may swallow the
    // drag, or the page would stop scrolling along its whole bottom band.
    final fab = tester.getRect(find.byKey(_fabKey));
    final beside = Offset(fab.left / 2, fab.center.dy);

    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(scrollable.controller!.offset, 0);

    await tester.dragFrom(beside, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(scrollable.controller!.offset, greaterThan(0));
  });
}
