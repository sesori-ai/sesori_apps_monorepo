import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/components/menus/anchored_spotlight_backdrop.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(List<PregoMenuEntry> entries, {bool flat = false, PregoMenuSpotlight? spotlight}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(
      body: Center(
        child: PregoAnchorMenu(
          menuWidth: 240,
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
