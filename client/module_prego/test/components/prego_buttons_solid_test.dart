import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("regular action buttons match Figma tokens and 44px sizing in $brightness", (tester) async {
      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [prego]),
          home: Scaffold(
            body: Column(
              children: [
                for (final hierarchy in [
                  PregoButtonsSolidHierarchy.primaryAlt,
                  PregoButtonsSolidHierarchy.secondary,
                  PregoButtonsSolidHierarchy.tertiary,
                ])
                  PregoButtonsSolid(
                    label: hierarchy.name,
                    hierarchy: hierarchy,
                    size: PregoButtonsSolidSize.lg,
                    leadingIcon: TablerRegular.check,
                    onPressed: () {},
                  ),
              ],
            ),
          ),
        ),
      );
      final expectedTokens = [
        (background: prego.colors.fgPrimary, foreground: prego.colors.textPrimaryOnWhite),
        (background: prego.colors.bgSurface4, foreground: prego.colors.textPrimary),
        (background: Colors.transparent, foreground: prego.colors.textSecondary),
      ];
      for (var index = 0; index < expectedTokens.length; index++) {
        final button = find.byType(PregoButtonsSolid).at(index);
        final decoration = tester.widget<DecoratedBox>(
          find.descendant(of: button, matching: find.byType(DecoratedBox)),
        );
        final text = tester.widget<Text>(find.descendant(of: button, matching: find.byType(Text)));
        final icon = tester.widget<Icon>(find.descendant(of: button, matching: find.byType(Icon)));
        expect((decoration.decoration as BoxDecoration).color, expectedTokens[index].background);
        expect(text.style!.color, expectedTokens[index].foreground);
        expect(icon.color, expectedTokens[index].foreground);
        expect(tester.getSize(button).height, 44);
      }
    });
  }
}
