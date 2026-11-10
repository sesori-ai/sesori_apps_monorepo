import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final mode in PregoInteractionMode.values) {
    for (final brightness in Brightness.values) {
      testWidgets("two needs-you cards follow one set of rules under ${mode.name}, ${brightness.name}", (tester) async {
        await tester.pumpWidget(
          PregoInteractionScope(
            mode: mode,
            child: MaterialApp(
              theme: mode == PregoInteractionMode.pointer
                  ? buildPregoDesktopThemeData(brightness: brightness)
                  : buildPregoThemeData(brightness: brightness),
              home: Scaffold(
                body: PregoPageHaloLayer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (leads, request) in [(true, "Pick a channel"), (false, "rm -rf build")])
                        SessionDetailNeedsYouCard(
                          key: ValueKey(leads),
                          icon: TablerRegular.help,
                          label: "1 pending request",
                          request: request,
                          action: "Review",
                          leads: leads,
                          onPressed: () {},
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final context = tester.element(find.byType(Scaffold));
        final prego = context.prego;
        PregoButtonsSolidHierarchy action({required bool leads}) => tester
            .widget<PregoButtonsSolid>(
              find.descendant(of: find.byKey(ValueKey(leads)), matching: find.byType(PregoButtonsSolid)),
            )
            .hierarchy;
        // Only the leading card's action is the solid one.
        expect(action(leads: true), PregoButtonsSolidHierarchy.primaryAlt);
        expect(action(leads: false), PregoButtonsSolidHierarchy.secondary);
        // The darker amber that clears 4.5:1 on the card.
        expect(
          tester.widgetList<Text>(find.text("1 pending request")).map((text) => text.style?.color).toSet(),
          {prego.colors.smallWarningText},
        );
        // A command reads as ordinary text, as a question does.
        expect(
          tester.widget<Text>(find.text("rm -rf build")).style,
          prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
        );
        final card = tester.widget<DecoratedBox>(
          find.descendant(of: find.byKey(const ValueKey(true)), matching: find.byType(DecoratedBox)).first,
        );
        final decoration = card.decoration;
        if (decoration is! BoxDecoration) fail("The card has no box decoration.");
        expect(
          decoration.color,
          brightness == Brightness.dark
              ? prego.colors.fgWarningPrimary.withValues(alpha: 0.07)
              : prego.colors.bgWarningPrimary,
        );
        expect(decoration.border, Border.all(color: prego.colors.fgWarningPrimary.withValues(alpha: 0.24)));
        expect(tester.widget<Icon>(find.byIcon(TablerRegular.help).first).size, 16);
        // Stacked cards' actions share a left edge.
        final actionBox = find.ancestor(
          of: find.byType(PregoButtonsSolid).first,
          matching: find.byType(ConstrainedBox),
        );
        expect(tester.widget<ConstrainedBox>(actionBox.first).constraints.minWidth, 72);
      });
    }
  }
}
