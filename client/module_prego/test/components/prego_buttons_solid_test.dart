import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
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
                    semanticLabel: "Icon",
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
                  semanticLabel: "Icon",
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

  testWidgets("xs buttons are 30px high with a text-xs label and a 16px icon", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PregoButtonsSolid(
                label: "Retry",
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xs,
                leadingIcon: TablerRegular.check,
                onPressed: () {},
              ),
              PregoButtonsSolid.iconOnly(
                semanticLabel: "Icon",
                leadingIcon: TablerRegular.check,
                hierarchy: PregoButtonsSolidHierarchy.tertiary,
                size: PregoButtonsSolidSize.xs,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final buttons = find.byType(PregoButtonsSolid);
    expect(tester.getSize(buttons.first).height, 30);
    expect(tester.getSize(buttons.last), const Size(30, 30));
    expect(
      tester.widget<Text>(find.text("Retry")).style?.fontSize,
      PregoDesignSystem.light.textTheme.textXs.medium.fontSize,
    );
    expect(tester.widgetList<Icon>(find.byType(Icon)).map((icon) => icon.size), everyElement(16));
  });

  testWidgets("a focused button activates on Enter and Space", (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: PregoButtonsSolid(
            label: "Go",
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            onPressed: () => presses++,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 2);
  });

  group("a screen reader", () {
    const platforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS});
    SemanticsNode nodeNamed(String label) => find.semantics.byLabel(label).evaluate().single;
    final unnamedTaps = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return !node.isMergedIntoParent && data.hasAction(SemanticsAction.tap) && data.label.isEmpty;
    });

    // Nothing between the button and its neighbour draws a line, so words and
    // taps that aren't held on their own node land together on the shared parent.
    Future<void> pump(WidgetTester tester, {required Widget button}) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: Center(
            child: Semantics(
              container: true,
              child: Row(children: [const Text("Beside"), button]),
            ),
          ),
        ),
      ),
    );

    testWidgets("hears an icon-only button as one named node with its tap and focus", (tester) async {
      final semantics = tester.ensureSemantics();
      var presses = 0;
      await pump(
        tester,
        button: PregoButtonsSolid.iconOnly(
          leadingIcon: TablerRegular.x,
          semanticLabel: "Close",
          showsTooltip: true,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.lg,
          onPressed: () => presses++,
        ),
      );

      expect(
        nodeNamed("Close"),
        isSemantics(
          label: "Close",
          tooltip: "",
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(nodeNamed("Beside"), isSemantics(label: "Beside", isButton: false, hasTapAction: false));
      expect(unnamedTaps, findsNothing);
      tester.semantics.tap(find.semantics.byLabel("Close"));
      expect(presses, 1);
      semantics.dispose();
    }, variant: platforms);

    for (final isLoading in [false, true]) {
      testWidgets("hears a ${isLoading ? "loading" : "disabled"} icon-only button as disabled, with no tap", (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          button: PregoButtonsSolid.iconOnly(
            leadingIcon: TablerRegular.x,
            semanticLabel: "Close",
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            isLoading: isLoading,
            // Loading wins over a live callback.
            onPressed: isLoading ? () => fail("A loading button took a tap") : null,
          ),
        );

        expect(
          nodeNamed("Close"),
          isSemantics(label: "Close", isButton: true, hasEnabledState: true, isEnabled: false, hasTapAction: false),
        );
        semantics.dispose();
      }, variant: platforms);
    }

    testWidgets("hears a text button as one node, named by its text", (tester) async {
      final semantics = tester.ensureSemantics();
      var presses = 0;
      await pump(
        tester,
        button: PregoButtonsSolid(
          label: "Retry",
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.lg,
          onPressed: () => presses++,
        ),
      );

      expect(
        nodeNamed("Retry"),
        isSemantics(label: "Retry", isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
      );
      expect(unnamedTaps, findsNothing);
      tester.semantics.tap(find.semantics.byLabel("Retry"));
      expect(presses, 1);
      semantics.dispose();
    }, variant: platforms);

    testWidgets("leaves the name to a wrapper around an icon-only button with none", (tester) async {
      final semantics = tester.ensureSemantics();
      var holds = 0;
      await pump(
        tester,
        button: Semantics(
          container: true,
          button: true,
          label: "Record",
          excludeSemantics: true,
          onTap: () => holds++,
          child: const PregoButtonsSolid.iconOnly(
            leadingIcon: TablerRegular.microphone,
            semanticLabel: null,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            onPressed: _noop,
          ),
        ),
      );

      expect(nodeNamed("Record"), isSemantics(label: "Record", isButton: true, hasTapAction: true));
      expect(find.byType(Tooltip), findsNothing);
      tester.semantics.tap(find.semantics.byLabel("Record"));
      expect(holds, 1);
      semantics.dispose();
    });

    testWidgets("the tooltip shows on request, without adding words to the node", (tester) async {
      Widget button({required bool showsTooltip}) => PregoButtonsSolid.iconOnly(
        leadingIcon: TablerRegular.x,
        semanticLabel: "Close",
        showsTooltip: showsTooltip,
        hierarchy: PregoButtonsSolidHierarchy.secondary,
        size: PregoButtonsSolidSize.lg,
        onPressed: _noop,
      );
      await pump(tester, button: button(showsTooltip: false));
      expect(find.byType(Tooltip), findsNothing);

      await pump(tester, button: button(showsTooltip: true));
      await tester.longPress(find.byIcon(TablerRegular.x));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text("Close"), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });
}

void _noop() {}
