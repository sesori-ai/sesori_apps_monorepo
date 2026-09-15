import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  const hierarchies = [
    PregoButtonsSolidHierarchy.primaryAlt,
    PregoButtonsSolidHierarchy.secondary,
    PregoButtonsSolidHierarchy.tertiary,
  ];
  for (final brightness in Brightness.values) {
    testWidgets("regular action buttons match canonical Prego tokens and 44px sizing in $brightness", (tester) async {
      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [prego]),
          home: Scaffold(
            body: Column(
              children: [
                for (final hierarchy in hierarchies)
                  PregoButtonsSolid(
                    label: hierarchy.name,
                    hierarchy: hierarchy,
                    size: PregoButtonsSolidSize.lg,
                    leadingIcon: TablerRegular.check,
                    trailingIcon: TablerRegular.chevron_right,
                    onPressed: () {},
                  ),
                for (final hierarchy in hierarchies)
                  PregoButtonsSolid.iconOnly(
                    leadingIcon: TablerRegular.check,
                    hierarchy: hierarchy,
                    size: PregoButtonsSolidSize.lg,
                    onPressed: () {},
                  ),
              ],
            ),
          ),
        ),
      );
      final expectedTokens = [
        (
          background: prego.colors.fgPrimary,
          foreground: prego.colors.textPrimaryOnWhite,
          leadingIcon: prego.colors.textPrimaryOnWhite,
        ),
        (
          background: prego.colors.bgSurface4,
          foreground: prego.colors.textSecondary,
          leadingIcon: prego.colors.textPrimary,
        ),
        (
          background: Colors.transparent,
          foreground: prego.colors.textTertiary,
          leadingIcon: prego.colors.textTertiary,
        ),
      ];
      for (var index = 0; index < expectedTokens.length; index++) {
        final button = find.byType(PregoButtonsSolid).at(index);
        final decoration = tester.widget<DecoratedBox>(
          find.descendant(of: button, matching: find.byType(DecoratedBox)),
        );
        final text = tester.widget<Text>(find.descendant(of: button, matching: find.byType(Text)));
        final icons = tester.widgetList<Icon>(find.descendant(of: button, matching: find.byType(Icon))).toList();
        expect((decoration.decoration as BoxDecoration).color, expectedTokens[index].background);
        expect(text.style!.color, expectedTokens[index].foreground);
        expect(icons[0].color, expectedTokens[index].leadingIcon);
        expect(icons[1].color, expectedTokens[index].foreground);
        expect(tester.getSize(button).height, 44);

        final iconOnlyButton = find.byType(PregoButtonsSolid).at(index + hierarchies.length);
        final icon = tester.widget<Icon>(find.descendant(of: iconOnlyButton, matching: find.byType(Icon)));
        expect(icon.color, expectedTokens[index].leadingIcon);
        expect(tester.getSize(iconOnlyButton), const Size(44, 44));
      }
    });

    testWidgets("secondary foregrounds keep their disabled token in $brightness", (tester) async {
      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [prego]),
          home: const Scaffold(
            body: Column(
              children: [
                PregoButtonsSolid(
                  label: "Disabled",
                  hierarchy: PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.lg,
                  leadingIcon: TablerRegular.check,
                  trailingIcon: TablerRegular.chevron_right,
                  onPressed: null,
                ),
                PregoButtonsSolid.iconOnly(
                  leadingIcon: TablerRegular.check,
                  hierarchy: PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.lg,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text("Disabled")).style!.color, prego.colors.textDisabled);
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((icon) => icon.color),
        everyElement(prego.colors.textDisabled),
      );
    });
  }
}
