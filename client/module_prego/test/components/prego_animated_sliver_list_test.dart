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

  testWidgets("swapping 10,000 rows for 5 animates only the rows on screen", (tester) async {
    await tester.pumpWidget(_harness([for (var i = 0; i < 10000; i++) "row $i"]));

    await tester.pumpWidget(_harness(["A", "B", "C", "D", "E"]));
    // One ticker per animated row: the five new rows and the first 13 old
    // ones, as many as the 600 px test surface fits at 48 px or more each.
    expect(tester.binding.transientCallbackCount, 5 + 13);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text("A"), findsOneWidget);
    expect(find.text("row 0"), findsOneWidget);
    expect(find.text("row 20"), findsNothing);

    await tester.pumpAndSettle();
    expect(find.textContaining("row "), findsNothing);
    expect(find.byType(SizeTransition), findsNWidgets(5));
  });

  testWidgets("a row that returns while it is still closing gets a key of its own", (tester) async {
    await tester.pumpWidget(_harness(["A", "B"]));
    await tester.pumpWidget(_harness(["B"]));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(_harness(["A", "B"]));
    await tester.pump(const Duration(milliseconds: 40));
    final copies = find.ancestor(of: find.text("A"), matching: find.byType(SizeTransition));
    final keys = [for (final element in copies.evaluate()) element.widget.key];
    expect(keys, hasLength(2));
    expect(keys.toSet(), hasLength(2));
  });

  testWidgets("rows appended below the viewport appear without animating", (tester) async {
    final items = [for (var i = 0; i < 20; i++) "$i"];
    await tester.pumpWidget(_harness(items));

    await tester.pumpWidget(_harness([...items, "20", "21"]));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets("a scrolled list animates only the rows that land in view", (tester) async {
    final items = [for (var i = 0; i < 100; i++) "$i"];
    await tester.pumpWidget(_harness(items));
    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(10 * _rowHeight);
    await tester.pump();

    // Rows leaving above the viewport go at once and shift every index after
    // them; the added row lands at index 13, in view.
    final next = [...items.sublist(5, 18), "new", ...items.sublist(18)];
    await tester.pumpWidget(_harness(next));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pump(const Duration(milliseconds: 130));
    final opening = find.ancestor(of: find.text("new"), matching: find.byType(SizeTransition));
    expect(tester.getSize(opening).height, inExclusiveRange(0, _rowHeight));

    await tester.pumpAndSettle();
    await tester.pumpWidget(_harness(["above", ...next]));
    expect(tester.binding.transientCallbackCount, 0);
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
