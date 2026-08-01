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
  group("shared solid card surfaces", () {
    testWidgets(
      "PregoCard matches the composer surface on Android and iOS",
      (tester) async {
        await tester.pumpWidget(_harness(const PregoCard(child: Text("Body"))));

        expect(find.byType(GlassContainer), findsNothing);
        final decorations = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: find.byType(PregoCard), matching: find.byType(DecoratedBox)),
            )
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>();
        final surface = decorations.singleWhere(
          (decoration) => decoration.color == PregoColorsLight.bgSurface2,
        );
        expect(surface.border, Border.all(color: PregoColorsLight.borderPrimary));
        expect(
          surface.boxShadow,
          [
            const BoxShadow(
              color: PregoColorsLight.shadowXs,
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        );
      },
      variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
    );

    testWidgets(
      "PregoListTile uses the same InkWell row and routes taps on Android and iOS",
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _harness(
            PregoCard(
              child: PregoListTile(
                leading: const Icon(Icons.task_alt),
                title: const Text("Alpha"),
                subtitle: const Text("first"),
                onTap: () => taps++,
                isLast: true,
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
      },
      variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
    );

    testWidgets(
      "PregoListTile composes a flat divider unless it is the last row",
      (tester) async {
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

        expect(find.byType(Divider), findsOneWidget);
        expect(find.byType(GlassDivider), findsNothing);
      },
      variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
    );
  });

  group("standalone divider", () {
    testWidgets("uses a flat divider on Android", (tester) async {
      await tester.pumpWidget(_harness(const PregoDivider()));

      expect(find.byType(GlassDivider), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("retains glass by default on iOS", (tester) async {
      await tester.pumpWidget(_harness(const PregoDivider()));

      expect(find.byType(GlassDivider), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("can force the flat card divider on iOS", (tester) async {
      await tester.pumpWidget(_harness(const PregoDivider(flat: true)));

      expect(find.byType(GlassDivider), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
