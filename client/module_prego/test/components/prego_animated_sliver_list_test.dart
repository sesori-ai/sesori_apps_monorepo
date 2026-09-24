import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
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

  testWidgets("a row that returns while it is still closing keeps one state", (tester) async {
    Widget list(List<String> items) => MaterialApp(
      home: CustomScrollView(
        slivers: [
          PregoAnimatedSliverList<String>(
            items: items,
            itemKey: ValueKey<String>.new,
            itemBuilder: (context, index, item) => SizedBox(
              height: _rowHeight,
              child: _Instance(label: item),
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(list(["A", "B"]));
    await tester.pumpWidget(list(["B"]));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(list(["A", "B"]));
    final returning = _Instance.created;

    // Rebuilds while both copies of A are mounted must not swap or recreate them.
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(list(["A", "B"]));
      expect(_Instance.created, returning);
    }
    await tester.pumpAndSettle();

    expect(find.text("A#$returning"), findsOneWidget);
    expect(find.textContaining("A#"), findsOneWidget);
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

  testWidgets("an outgoing row gives up keyboard focus", (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget list(List<String> items) => MaterialApp(
      home: CustomScrollView(
        slivers: [
          PregoAnimatedSliverList<String>(
            items: items,
            itemKey: ValueKey<String>.new,
            itemBuilder: (context, index, item) => Focus(focusNode: focus, child: Text(item)),
          ),
        ],
      ),
    );

    await tester.pumpWidget(list(["A"]));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.pumpWidget(list([]));
    expect(find.text("A"), findsOneWidget);
    expect(focus.hasFocus, isFalse);
  });

  testWidgets("a filter change animates only the rows that land on screen", (tester) async {
    final items = [for (var i = 0; i < 100; i++) "$i"];
    Finder rowTransition(String item) => find.ancestor(of: find.text(item), matching: find.byType(SizeTransition));

    await tester.pumpWidget(_harness(["0"]));
    await tester.pumpWidget(_harness(items));

    // Animated rows start at zero height; animating all 100 built all 100.
    expect(find.byType(SizeTransition).evaluate().length, lessThan(30));

    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.getSize(rowTransition("1")).height, inExclusiveRange(0, _rowHeight));
    expect(tester.getSize(rowTransition("7")).height, inExclusiveRange(0, _rowHeight));
    expect(tester.getSize(rowTransition("13")).height, _rowHeight);
  });

  testWidgets("reduced motion removes a row without a transition delay", (tester) async {
    await tester.pumpWidget(_harness(["A"], disableAnimations: true));

    await tester.pumpWidget(_harness([], disableAnimations: true));
    await tester.pump();

    expect(find.text("A"), findsNothing);
  });
}

class const _Instance({required final String label}) extends StatefulWidget {
  static int created = 0;

  @override
  State<_Instance> createState() => _InstanceState();
}

class _InstanceState() extends State<_Instance> {
  final int id = ++_Instance.created;

  @override
  Widget build(BuildContext context) => Text("${widget.label}#$id");
}
