import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

const double _rowHeight = 80;

Widget _harness(List<String> items, {bool disableAnimations = false, VoidCallback? onTap}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: CustomScrollView(
          slivers: [
            PregoAnimatedSliverList<String>(
              items: items,
              itemKey: ValueKey<String>.new,
              itemBuilder: (context, index, item) => GestureDetector(
                key: ValueKey("row-$item"),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: SizedBox(
                  height: _rowHeight,
                  child: Text(item),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("removed row closes while the following row moves into place", (tester) async {
    await tester.pumpWidget(_harness(["A", "B"]));
    expect(tester.getTopLeft(find.byKey(const ValueKey("row-B"))).dy, _rowHeight);

    await tester.pumpWidget(_harness(["B"]));
    expect(find.text("A"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 130));
    final movingTop = tester.getTopLeft(find.byKey(const ValueKey("row-B"))).dy;
    expect(movingTop, greaterThan(0));
    expect(movingTop, lessThan(_rowHeight));

    await tester.pumpAndSettle();
    expect(find.text("A"), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey("row-B"))).dy, 0);
  });

  testWidgets("the last row remains mounted for its closing transition", (tester) async {
    await tester.pumpWidget(_harness(["A"]));

    await tester.pumpWidget(_harness([]));
    expect(find.text("A"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.getSize(find.byType(SizeTransition)).height, inExclusiveRange(0, _rowHeight));

    await tester.pumpAndSettle();
    expect(find.text("A"), findsNothing);
  });

  testWidgets("an outgoing row is no longer interactive or exposed to semantics", (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    void onTap() => taps++;

    await tester.pumpWidget(_harness(["A"], onTap: onTap));
    expect(find.bySemanticsLabel("A"), findsOneWidget);

    await tester.pumpWidget(_harness([], onTap: onTap));
    expect(find.text("A"), findsOneWidget);
    expect(find.bySemanticsLabel("A"), findsNothing);

    await tester.tap(find.text("A"), warnIfMissed: false);
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets("reduced motion removes a row without a transition delay", (tester) async {
    await tester.pumpWidget(_harness(["A"], disableAnimations: true));

    await tester.pumpWidget(_harness([], disableAnimations: true));
    await tester.pump();

    expect(find.text("A"), findsNothing);
  });
}
