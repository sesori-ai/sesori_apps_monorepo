import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group("Android (flat) path", () {
    testWidgets("PregoCard renders a flat Material surface, never a GlassContainer", (tester) async {
      await tester.pumpWidget(_harness(const PregoCard(child: Text("Body"))));

      expect(find.byType(GlassContainer), findsNothing);
      expect(find.text("Body"), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("PregoListTile renders a flat InkWell row and routes taps", (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          PregoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PregoListTile(
                  leading: const Icon(Icons.task_alt),
                  title: const Text("Alpha"),
                  subtitle: const Text("first"),
                  onTap: () => taps++,
                ),
                const PregoListTile(title: Text("Beta"), isLast: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(GlassListTile), findsNothing);
      expect(find.widgetWithText(InkWell, "Alpha"), findsOneWidget);
      expect(find.text("first"), findsOneWidget);

      await tester.tap(find.text("Alpha"));
      await tester.pumpAndSettle();
      expect(taps, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("PregoDivider renders a flat Divider, not a GlassDivider", (tester) async {
      await tester.pumpWidget(_harness(const PregoDivider()));

      expect(find.byType(GlassDivider), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("PregoListTile draws a flat Divider below itself unless it is the last row", (tester) async {
      await tester.pumpWidget(
        _harness(
          const PregoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PregoListTile(title: Text("Alpha")),
                PregoListTile(title: Text("Beta"), isLast: true),
              ],
            ),
          ),
        ),
      );

      // Only the first (non-last) row composes a divider; the last row suppresses it.
      expect(find.byType(Divider), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group("Apple (glass) path", () {
    testWidgets("the glass surfaces are used on Apple platforms", (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          PregoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PregoListTile(title: const Text("Alpha"), onTap: () => taps++, isLast: true),
                const PregoDivider(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(GlassContainer), findsOneWidget);
      expect(find.byType(GlassListTile), findsOneWidget);
      expect(find.byType(GlassDivider), findsOneWidget);

      await tester.tap(find.text("Alpha"));
      await tester.pumpAndSettle();
      expect(taps, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("PregoListTile draws its own GlassDivider unless it is the last row", (tester) async {
      await tester.pumpWidget(
        _harness(
          const PregoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PregoListTile(title: Text("Alpha")),
                PregoListTile(title: Text("Beta"), isLast: true),
              ],
            ),
          ),
        ),
      );

      // GlassListTile no longer owns divider rendering; PregoListTile composes a
      // GlassDivider below the first (non-last) row and none below the last.
      expect(find.byType(GlassListTile), findsNWidgets(2));
      expect(find.byType(GlassDivider), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
