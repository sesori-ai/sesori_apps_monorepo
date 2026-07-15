import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/components/menus/anchored_spotlight_backdrop.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(
  List<PregoMenuEntry> entries, {
  bool flat = false,
  PregoMenuSpotlight? spotlight,
  double? maxHeight,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(
      body: Center(
        child: PregoAnchorMenu(
          menuWidth: 240,
          menuMaxHeight: maxHeight,
          flat: flat,
          spotlight: spotlight,
          entriesBuilder: () => entries,
          triggerBuilder: (context, toggle) => ElevatedButton(
            onPressed: toggle,
            child: const Text("Open"),
          ),
        ),
      ),
    ),
  );
}

/// The rows of an agent picker — the shape that broke: a heading, then several
/// rows carrying both a title and a subtitle.
List<PregoMenuEntry> _agentEntries(List<String> names, {void Function(String name)? onTap}) => [
  const PregoMenuLabel(text: "Agent"),
  for (final name in names)
    PregoMenuItem(
      title: name,
      subtitle: "The $name agent, described at some length",
      isSelected: name == names.last,
      onTap: () => onTap?.call(name),
    ),
];

/// The scroll position of the open glass popup.
ScrollPosition _popupScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

void main() {
  group("Android (flat) path", () {
    testWidgets("opens a flat menu, runs the tap callback, and dismisses", (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness([
          const PregoMenuLabel(text: "Section"),
          PregoMenuItem(
            title: "Alpha",
            subtitle: "first",
            isSelected: false,
            leadingIcon: Icons.mail_outline,
            onTap: () => taps++,
          ),
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
      // The optional leading icon renders on the flat row.
      expect(find.widgetWithIcon(InkWell, Icons.mail_outline), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, "Alpha"));
      await tester.pumpAndSettle();

      expect(taps, 1);
      // Selecting an item closes the menu.
      expect(find.text("Alpha"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("first and last item highlights reach the panel edges", (tester) async {
      await tester.pumpWidget(
        _harness([
          PregoMenuItem(title: "Alpha", subtitle: null, isSelected: false, onTap: () {}),
          PregoMenuItem(title: "Beta", subtitle: null, isSelected: false, onTap: () {}),
        ], flat: true),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final panelRect = tester.getRect(find.byType(SingleChildScrollView));
      final firstItem = find.widgetWithText(InkWell, "Alpha");
      final lastItem = find.widgetWithText(InkWell, "Beta");
      final firstItemRect = tester.getRect(firstItem);
      final lastItemRect = tester.getRect(lastItem);

      expect(firstItemRect.top, panelRect.top);
      expect(lastItemRect.bottom, panelRect.bottom);
      expect(tester.widget<InkWell>(firstItem).borderRadius, BorderRadius.zero);
      expect(tester.widget<InkWell>(lastItem).borderRadius, BorderRadius.zero);
    });

    testWidgets("custom entries keep the original inset at panel edges", (tester) async {
      await tester.pumpWidget(
        _harness([
          PregoMenuCustom(
            height: 12,
            builder: (context, close) => const SizedBox(key: ValueKey("first-custom"), height: 12),
          ),
          PregoMenuItem(title: "Alpha", subtitle: null, isSelected: false, onTap: () {}),
          PregoMenuCustom(
            height: 12,
            builder: (context, close) => const SizedBox(key: ValueKey("last-custom"), height: 12),
          ),
        ], flat: true),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final panelRect = tester.getRect(find.byType(SingleChildScrollView));
      final firstCustomRect = tester.getRect(find.byKey(const ValueKey("first-custom")));
      final lastCustomRect = tester.getRect(find.byKey(const ValueKey("last-custom")));

      expect(firstCustomRect.top - panelRect.top, 6);
      expect(panelRect.bottom - lastCustomRect.bottom, 6);
    });

    testWidgets("a custom entry can close the menu via its close callback", (tester) async {
      await tester.pumpWidget(
        _harness([
          PregoMenuCustom(
            height: 48,
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
                entriesBuilder: () => [
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
          PregoMenuItem(
            title: "Alpha",
            subtitle: "first",
            isSelected: false,
            leadingIcon: Icons.mail_outline,
            onTap: () => taps++,
          ),
        ]),
      );

      // The glass popup is used on Apple platforms (no flat InkWell rows).
      expect(find.byType(GlassMenu), findsOneWidget);

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(GlassMenuItem, "Alpha"), findsOneWidget);
      // The optional leading icon renders on the glass item.
      expect(find.widgetWithIcon(GlassMenuItem, Icons.mail_outline), findsOneWidget);

      await tester.tap(find.widgetWithText(GlassMenuItem, "Alpha"));
      await tester.pumpAndSettle();

      expect(taps, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("flat: true forces the flat path even on Apple", (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          flat: true,
          [
            PregoMenuItem(
              title: "Alpha",
              subtitle: null,
              isSelected: false,
              leadingIcon: Icons.mail_outline,
              onTap: () => taps++,
            ),
          ],
        ),
      );

      // With the flat override the glass popup is never built, even on iOS.
      expect(find.byType(GlassMenu), findsNothing);

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Flat (InkWell) row with its leading icon, and taps still route.
      expect(find.widgetWithText(InkWell, "Alpha"), findsOneWidget);
      expect(find.widgetWithIcon(InkWell, Icons.mail_outline), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, "Alpha"));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.text("Alpha"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  // GlassMenu never measures its rows — it lays the popup out from the heights
  // they declare, and for a popup short enough not to scroll it even resolves
  // taps by doing index arithmetic over those same heights. Every row we hand it
  // therefore declares its true height. These guard that: under-declare, and the
  // last row is clipped with no way to scroll to it while taps land on the wrong
  // agent.
  group("Glass row heights", () {
    testWidgets("declare the height each row actually renders at", (tester) async {
      const custom = 64.0;
      final entries = <PregoMenuEntry>[
        const PregoMenuLabel(text: "Agent"),
        PregoMenuItem(title: "Titled", subtitle: null, isSelected: false, onTap: () {}),
        PregoMenuItem(title: "Subtitled", subtitle: "and described", isSelected: false, onTap: () {}),
        const PregoMenuDivider(),
        PregoMenuCustom(
          height: custom,
          builder: (context, close) => const SizedBox(height: custom, child: Text("Custom")),
        ),
      ];
      await tester.pumpWidget(_harness(entries));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Each declaration matches the rendered row to the pixel. A package
      // upgrade that changes a row's chrome fails here, loudly, rather than
      // silently clipping the menu in the field.
      final context = tester.element(find.byType(GlassMenu));
      final rows = <PregoMenuEntry, Finder>{
        entries[1]: find.widgetWithText(GlassMenuItem, "Titled"),
        entries[2]: find.widgetWithText(GlassMenuItem, "Subtitled"),
        entries[3]: find.byType(GlassMenuDivider),
        entries[4]: find.widgetWithText(GlassMenuLabel, "Custom"),
      };
      rows.forEach((entry, row) {
        expect(
          tester.getSize(row).height,
          equals(debugGlassEntryHeight(context, entry: entry)),
          reason: "$entry renders taller or shorter than the popup was told",
        );
      });
      // The heading is the one row whose rendered box is the declared height
      // itself; assert it clears its line box rather than round-tripping it.
      expect(tester.getSize(find.widgetWithText(GlassMenuLabel, "AGENT")).height, equals(30.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("leave nothing hidden below the fold", (tester) async {
      await tester.pumpWidget(_harness(_agentEntries(["Alpha", "Beta", "Gamma", "Delta"])));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Uncapped and short enough to fit: the popup wraps its rows exactly, so
      // there is nothing to scroll to and the last agent is on screen.
      expect(_popupScroll(tester).maxScrollExtent, equals(0.0));
      expect(find.widgetWithText(GlassMenuItem, "Delta"), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("hold up when the reader scales their text", (tester) async {
      // Set on the view, not via a local MediaQuery: the popup is painted in the
      // app's Overlay, above any override we could wrap the trigger in.
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_harness(_agentEntries(["Alpha", "Beta", "Gamma", "Delta"])));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Rows grow with the text scale, and the popup's budget grows with them.
      expect(_popupScroll(tester).maxScrollExtent, equals(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("route a tap to the row under the finger, edges included", (tester) async {
      final tapped = <String>[];
      const names = ["Alpha", "Beta", "Gamma", "Delta"];
      await tester.pumpWidget(_harness(_agentEntries(names, onTap: tapped.add)));

      for (final name in names) {
        await tester.tap(find.text("Open"));
        await tester.pumpAndSettle();

        // The lower edge of the row, where a height under-declared by a few
        // pixels per row has drifted far enough to hand the tap to the row below.
        final row = find.widgetWithText(GlassMenuItem, name);
        await tester.tapAt(tester.getRect(row).bottomCenter - const Offset(0, 4));
        await tester.pumpAndSettle();
      }

      expect(tapped, equals(names));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("scroll, rather than clip, once the rows outgrow the cap", (tester) async {
      final tapped = <String>[];
      const names = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta"];
      await tester.pumpWidget(_harness(_agentEntries(names, onTap: tapped.add), maxHeight: 200));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // The cap holds, and what it hides is scrollable rather than lost.
      expect(tester.getSize(find.byType(SingleChildScrollView)).height, equals(200.0));
      expect(_popupScroll(tester).maxScrollExtent, greaterThan(0.0));

      // Taps still land on the row they were aimed at once it has scrolled — the
      // last agent, which was past the cap, is now reachable.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(GlassMenuItem, "Theta"));
      await tester.pumpAndSettle();

      expect(tapped, equals(["Theta"]));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("size the popup to its rows when they stay under the cap", (tester) async {
      await tester.pumpWidget(_harness(_agentEntries(["Alpha", "Beta"]), maxHeight: 380));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // A cap is a ceiling, not a fixed height: a two-agent menu is a two-agent
      // menu, not 380px of glass with the bottom half empty.
      final label = tester.getRect(find.widgetWithText(GlassMenuLabel, "AGENT"));
      final lastRow = tester.getRect(find.widgetWithText(GlassMenuItem, "Beta"));
      final popup = tester.getSize(find.byType(SingleChildScrollView)).height;
      // The rows plus GlassMenu's 12px of padding at either end.
      expect(popup, closeTo(lastRow.bottom - label.top + 24, 0.1));
      expect(_popupScroll(tester).maxScrollExtent, equals(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group("Destructive entries", () {
    const entries = [
      PregoMenuItem(title: "Archive", subtitle: null, isSelected: false, onTap: _noop),
      PregoMenuItem(
        title: "Delete",
        subtitle: null,
        isSelected: false,
        isDestructive: true,
        onTap: _noop,
        leadingIcon: Icons.delete_outline,
      ),
    ];

    testWidgets("tint only the destructive row's title and glyph", (tester) async {
      await tester.pumpWidget(_harness(entries, flat: true));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final error = PregoDesignSystem.light.colors.fgErrorPrimary;
      expect(tester.widget<Text>(find.text("Delete")).style?.color, equals(error));
      expect(tester.widget<Icon>(find.byIcon(Icons.delete_outline)).color, equals(error));
      // A menu where every row shouts warns about nothing.
      expect(tester.widget<Text>(find.text("Archive")).style?.color, isNot(equals(error)));
    });

    testWidgets("reach the glass path as destructive too", (tester) async {
      await tester.pumpWidget(_harness(entries));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final item = tester.widget<GlassMenuItem>(find.widgetWithText(GlassMenuItem, "Delete"));
      expect(item.isDestructive, isTrue);
      // Tinted from the design system's error token, not Cupertino's system red.
      expect(item.titleStyle?.color, equals(PregoDesignSystem.light.colors.fgErrorPrimary));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group("Spotlight", () {
    const entries = [
      PregoMenuItem(title: "Alpha", subtitle: null, isSelected: false, onTap: _noop),
    ];

    const spotlight = PregoMenuSpotlight.listRow;

    testWidgets("cuts the hole around the trigger and releases it on dismiss", (tester) async {
      await tester.pumpWidget(_harness(entries, flat: true, spotlight: spotlight));

      // The page is untouched until the menu is open.
      expect(find.byType(AnchoredSpotlightBackdrop), findsNothing);

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // The sharp region tracks the trigger's on-screen bounds, inset as asked —
      // otherwise the backdrop would cover the very row the menu is acting on.
      final backdrop = tester.widget<AnchoredSpotlightBackdrop>(find.byType(AnchoredSpotlightBackdrop));
      final triggerRect = tester.getRect(find.byType(ElevatedButton));
      expect(backdrop.spotlightRect, equals(spotlight.inset.deflateRect(triggerRect)));
      expect(backdrop.borderRadius, equals(spotlight.borderRadius));

      // It must not eat the tap-outside: the dismiss barrier lives beneath it.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.text("Alpha"), findsNothing);
      expect(find.byType(AnchoredSpotlightBackdrop), findsNothing);
    });

    testWidgets("blurs the page on Apple platforms", (tester) async {
      await tester.pumpWidget(_harness(entries, flat: true, spotlight: spotlight));

      expect(find.byType(BackdropFilter), findsNothing);

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("spotlights without blurring on Android, where a full-screen BackdropFilter janks", (
      tester,
    ) async {
      await tester.pumpWidget(_harness(entries, flat: true, spotlight: spotlight));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // The scrim and the cut-out still run — the page recedes and the trigger
      // still reads as lifted — but the Gaussian pass is skipped.
      expect(find.byType(AnchoredSpotlightBackdrop), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("is off by default, leaving the page behind the menu untouched", (tester) async {
      await tester.pumpWidget(_harness(entries, flat: true));

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.text("Alpha"), findsOneWidget);
      expect(find.byType(AnchoredSpotlightBackdrop), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    test("falls back to the trigger's raw bounds when the inset outsizes the trigger", () {
      const tight = PregoMenuSpotlight(
        borderRadius: 16,
        inset: EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      );
      const smallTrigger = Rect.fromLTWH(0, 0, 60, 44);

      // Deflating would flip the rect inside out; the raw bounds keep the
      // backdrop's cut-out and outline geometrically valid.
      expect(tight.resolveRect(triggerRect: smallTrigger), equals(smallTrigger));

      // A trigger with room for the inset still gets the deflated rect.
      const wideTrigger = Rect.fromLTWH(0, 0, 400, 80);
      expect(
        tight.resolveRect(triggerRect: wideTrigger),
        equals(tight.inset.deflateRect(wideTrigger)),
      );
    });

    test("cannot be paired with the glass path, which hides its own trigger", () {
      expect(
        () => PregoAnchorMenu(
          entriesBuilder: () => entries,
          spotlight: const PregoMenuSpotlight(borderRadius: 16),
          triggerBuilder: (context, toggle) => const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
    });
  });
}

void _noop() {}
