import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/review_tools/presentation/prego_review_action.dart";

void main() {
  testWidgets("review actions are focusable and activate with Enter and Space", (tester) async {
    var activationCount = 0;
    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Scaffold(
          body: PregoReviewAction(
            label: "Run review action",
            text: "Run",
            onPressed: () => activationCount += 1,
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.bySemanticsLabel("Run review action"), findsOneWidget);
    expect(material.FocusManager.instance.primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(activationCount, 2);
  });

  testWidgets("review actions expose their disabled state", (tester) async {
    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogLightTheme,
        home: const material.Scaffold(
          body: PregoReviewAction(label: "Unavailable action", text: "Unavailable", onPressed: null),
        ),
      ),
    );

    expect(find.bySemanticsLabel("Unavailable action"), findsOneWidget);
    expect(tester.widget<material.TextButton>(find.byType(material.TextButton)).onPressed, isNull);
  });
}
