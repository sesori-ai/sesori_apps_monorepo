import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("lays out two equal-width sheet actions", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: const Scaffold(
          body: PregoSheetActions(
            secondary: SizedBox(key: Key("secondary"), height: 44),
            primary: SizedBox(key: Key("primary"), height: 44),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key("secondary"))).width, tester.getSize(find.byKey(const Key("primary"))).width);
    expect(
      tester.getTopLeft(find.byKey(const Key("primary"))).dx -
          tester.getTopRight(find.byKey(const Key("secondary"))).dx,
      PregoSpacing.md,
    );
  });
}
