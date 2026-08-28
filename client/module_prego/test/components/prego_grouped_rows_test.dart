import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(body: Center(child: child)),
  );
}

class const _StatefulGroupedRow({required final String label, super.key}) extends StatefulWidget {
  @override
  State<_StatefulGroupedRow> createState() => _StatefulGroupedRowState();
}

class _StatefulGroupedRowState() extends State<_StatefulGroupedRow> {
  final identity = Object();

  @override
  Widget build(BuildContext context) => PregoGroupedRow(title: Text(widget.label));
}

void main() {
  testWidgets("PregoGroupedRows renders a flat surface on every platform", (tester) async {
    await tester.pumpWidget(
      _harness(
        const PregoGroupedRows(
          children: [PregoGroupedRow(title: Text("Alpha"))],
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.ancestor(of: find.text("Alpha"), matching: find.byType(Material)).first,
    );
    expect(material.color, PregoDesignSystem.light.colors.bgSurface3);
  }, variant: TargetPlatformVariant.all());

  testWidgets("PregoGroupedRow routes taps and renders slots", (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        PregoGroupedRows(
          children: [
            PregoGroupedRow(
              icon: TablerRegular.bell,
              title: const Text("Notifications"),
              trailing: const Icon(TablerRegular.chevron_right),
              onTap: () => taps++,
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(TablerRegular.bell), findsOneWidget);
    expect(find.byIcon(TablerRegular.chevron_right), findsOneWidget);

    await tester.tap(find.text("Notifications"));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets("rows compose a hairline below themselves unless last", (tester) async {
    await tester.pumpWidget(
      _harness(
        const PregoGroupedRows(
          children: [
            PregoGroupedRow(title: Text("Alpha"), subtitle: Text("first")),
            PregoGroupedRow(title: Text("Beta")),
          ],
        ),
      ),
    );

    final hairlines = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color == PregoDesignSystem.light.colors.borderSecondary);
    expect(hairlines, hasLength(1));
  });

  testWidgets("keyed rows retain state when reordered", (tester) async {
    const alphaKey = ValueKey("alpha");
    const betaKey = ValueKey("beta");
    await tester.pumpWidget(
      _harness(
        const PregoGroupedRows(
          children: [
            _StatefulGroupedRow(key: alphaKey, label: "Alpha"),
            _StatefulGroupedRow(key: betaKey, label: "Beta"),
          ],
        ),
      ),
    );
    final alphaState = tester.state<_StatefulGroupedRowState>(find.byKey(alphaKey));
    final betaState = tester.state<_StatefulGroupedRowState>(find.byKey(betaKey));

    await tester.pumpWidget(
      _harness(
        const PregoGroupedRows(
          children: [
            _StatefulGroupedRow(key: betaKey, label: "Beta"),
            _StatefulGroupedRow(key: alphaKey, label: "Alpha"),
          ],
        ),
      ),
    );

    expect(tester.state<_StatefulGroupedRowState>(find.byKey(alphaKey)), same(alphaState));
    expect(tester.state<_StatefulGroupedRowState>(find.byKey(betaKey)), same(betaState));
  });

  testWidgets("subtitle rows grow to the tall min height, simple rows stay compact", (tester) async {
    await tester.pumpWidget(
      _harness(
        const PregoGroupedRows(
          children: [
            PregoGroupedRow(title: Text("Alpha"), subtitle: Text("first")),
            PregoGroupedRow(title: Text("Beta")),
          ],
        ),
      ),
    );

    final tallHeight = tester.getSize(find.widgetWithText(Container, "Alpha")).height;
    final compactHeight = tester.getSize(find.widgetWithText(Container, "Beta")).height;
    expect(tallHeight, greaterThanOrEqualTo(68));
    expect(compactHeight, greaterThanOrEqualTo(52));
    expect(compactHeight, lessThan(tallHeight));
  });
}
