import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets("renders the Figma track size and reports toggles", (tester) async {
    bool? received;
    await tester.pumpWidget(
      _harness(PregoSwitch(value: false, onChanged: (value) => received = value)),
    );

    expect(tester.getSize(find.byType(PregoSwitch)), const Size(64, 28));

    await tester.tap(find.byType(PregoSwitch));
    await tester.pumpAndSettle();
    expect(received, isTrue);
  });

  testWidgets("exposes toggle semantics and disables without a callback", (tester) async {
    await tester.pumpWidget(_harness(const PregoSwitch(value: true, onChanged: null)));

    expect(
      tester.getSemantics(find.byType(PregoSwitch)),
      matchesSemantics(hasToggledState: true, isToggled: true, hasEnabledState: true),
    );

    await tester.tap(find.byType(PregoSwitch));
    await tester.pumpAndSettle();
    // No onChanged to observe; reaching here without errors is the guard.
  });

  testWidgets("track fills with the brand colour when on", (tester) async {
    await tester.pumpWidget(_harness(PregoSwitch(value: true, onChanged: (_) {})));
    await tester.pumpAndSettle();

    final track = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byType(PregoSwitch), matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.borderRadius != null && decoration.color != null);
    expect(track.color, PregoDesignSystem.light.colors.bgBrandSolid);
  });
}
