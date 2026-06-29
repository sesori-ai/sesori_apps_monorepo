import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(List<PregoMenuEntry> entries) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(
      body: Center(
        child: PregoAnchorMenu(
          menuWidth: 240,
          entries: entries,
          triggerBuilder: (context, toggle) => ElevatedButton(
            onPressed: toggle,
            child: const Text("Open"),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group("Android (flat) path", () {
    testWidgets("opens a flat menu, runs the tap callback, and dismisses", (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness([
          const PregoMenuLabel(text: "Section"),
          PregoMenuItem(title: "Alpha", subtitle: "first", isSelected: false, onTap: () => taps++),
          const PregoMenuDivider(),
          PregoMenuItem(title: "Beta", subtitle: null, isSelected: true, onTap: () {}),
        ]),
      );

      // The glass widget is never built on Android.
      expect(find.byType(GlassMenu), findsNothing);
      expect(find.text("SECTION"), findsNothing);

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Label (uppercased, matching the glass path) + flat (InkWell) rows show.
      expect(find.text("SECTION"), findsOneWidget);
      expect(find.widgetWithText(InkWell, "Alpha"), findsOneWidget);
      expect(find.widgetWithText(InkWell, "Beta"), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, "Alpha"));
      await tester.pumpAndSettle();

      expect(taps, 1);
      // Selecting an item closes the menu.
      expect(find.text("Alpha"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("a custom entry can close the menu via its close callback", (tester) async {
      await tester.pumpWidget(
        _harness([
          PregoMenuCustom(
            builder: (context, close) => TextButton(onPressed: close, child: const Text("Dismiss")),
          ),
          PregoMenuItem(title: "Alpha", subtitle: null, isSelected: false, onTap: () {}),
        ]),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();
      expect(find.text("Dismiss"), findsOneWidget);

      await tester.tap(find.text("Dismiss"));
      await tester.pumpAndSettle();
      // The menu (and its custom row) is gone.
      expect(find.text("Dismiss"), findsNothing);
      expect(find.widgetWithText(InkWell, "Alpha"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("clamps the menu width to the padded viewport on a narrow screen", (tester) async {
      // A menuWidth (320) wider than the 320dp viewport minus its 12+12 padding
      // must be shrunk to fit (→ 296), not just repositioned, or it overflows the
      // screen edge. Size the whole window so the dialog route sees the narrow
      // MediaQuery (it is pushed on the root navigator, above any local override).
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Scaffold(
            body: Center(
              child: PregoAnchorMenu(
                menuWidth: 320,
                menuScreenPadding: const EdgeInsets.all(12),
                entries: [
                  PregoMenuItem(title: "Alpha", subtitle: null, isSelected: false, onTap: () {}),
                ],
                triggerBuilder: (context, toggle) => ElevatedButton(
                  onPressed: toggle,
                  child: const Text("Open"),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(SingleChildScrollView)).width, lessThanOrEqualTo(296.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group("Apple (glass) path", () {
    testWidgets("renders a GlassMenu and routes item taps", (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness([
          const PregoMenuLabel(text: "Section"),
          PregoMenuItem(title: "Alpha", subtitle: "first", isSelected: false, onTap: () => taps++),
        ]),
      );

      // The glass popup is used on Apple platforms (no flat InkWell rows).
      expect(find.byType(GlassMenu), findsOneWidget);

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(GlassMenuItem, "Alpha"), findsOneWidget);

      await tester.tap(find.widgetWithText(GlassMenuItem, "Alpha"));
      await tester.pumpAndSettle();

      expect(taps, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
