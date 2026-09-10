import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

const double _rowHeight = 80;

Widget _harness(List<String> items) {
  return MaterialApp(
    home: Column(
      children: [
        PregoAnimatedList<String>(
          items: items,
          itemKey: ValueKey<String>.new,
          itemBuilder: (context, index, item) => SizedBox(
            key: ValueKey("row-$item"),
            height: _rowHeight,
            child: Text(item),
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets("rows size the column and a removed row closes in place", (tester) async {
    await tester.pumpWidget(_harness(["A", "B"]));
    expect(tester.getSize(find.byType(PregoAnimatedList<String>)).height, _rowHeight * 2);

    await tester.pumpWidget(_harness(["B"]));
    expect(find.text("A"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.getSize(find.byType(PregoAnimatedList<String>)).height, inExclusiveRange(_rowHeight, _rowHeight * 2));

    await tester.pumpAndSettle();
    expect(find.text("A"), findsNothing);
    expect(tester.getSize(find.byType(PregoAnimatedList<String>)).height, _rowHeight);
  });
}
