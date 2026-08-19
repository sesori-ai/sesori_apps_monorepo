// Widgetbook's settings shell is built with Flutter Material, while PREGO's
// use-case canvas uses the separately packaged material_ui implementation.
// ignore: no_slop_linter/avoid_legacy_flutter_design_imports
import "package:flutter/material.dart" as flutter_material;
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_layout_guides.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";

void main() {
  test("layout guide addon exposes URL-shareable controls with quiet defaults", () {
    final addon = PregoLayoutGuidesAddon();

    expect(addon.groupName, "prego-layout-guides");
    expect(addon.fields.map((field) => field.name), ["enabled", "safeAreas", "contentBounds", "spacingGrid"]);
    expect(addon.fields.map((field) => field.initialValue), [false, true, true, false]);
    expect(
      addon.valueFromQueryGroup(const {}),
      const PregoLayoutGuideSettings(
        enabled: false,
        safeAreas: true,
        contentBounds: true,
        spacingGrid: false,
      ),
    );
    expect(
      addon.valueFromQueryGroup(const {
        "enabled": "true",
        "safeAreas": "false",
        "contentBounds": "false",
        "spacingGrid": "true",
      }),
      const PregoLayoutGuideSettings(
        enabled: true,
        safeAreas: false,
        contentBounds: false,
        spacingGrid: true,
      ),
    );
  });

  testWidgets("layout guide controls render without a PREGO Material ancestor", (tester) async {
    final fields = PregoLayoutGuidesAddon().fields;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: flutter_material.Material(
          child: Builder(
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: fields
                  .map(
                    (field) => field.toWidget(context, "layout-guides", field.initialValue),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );

    expect(find.text("Enabled"), findsOneWidget);
    expect(find.text("Safe areas"), findsOneWidget);
    expect(find.text("Content bounds"), findsOneWidget);
    expect(find.text("Spacing grid"), findsOneWidget);
    expect(find.byType(flutter_material.Switch), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  test("layout geometry keeps PREGO content inside device safe areas", () {
    final ltr = calculatePregoLayoutGuideGeometry(
      size: const Size(100, 200),
      viewPadding: const EdgeInsets.fromLTRB(10, 20, 12, 30),
      textDirection: TextDirection.ltr,
    );
    final rtl = calculatePregoLayoutGuideGeometry(
      size: const Size(100, 200),
      viewPadding: const EdgeInsets.fromLTRB(10, 20, 12, 30),
      textDirection: TextDirection.rtl,
    );

    expect(ltr.safeRect, const Rect.fromLTRB(10, 20, 88, 170));
    expect(ltr.contentRect, const Rect.fromLTRB(26, 20, 72, 170));
    expect(ltr.leadingContentX, 26);
    expect(ltr.trailingContentX, 72);
    expect(rtl.leadingContentX, 72);
    expect(rtl.trailingContentX, 26);
  });

  testWidgets("disabled layout guides leave the use case unchanged", (tester) async {
    const childKey = Key("use-case-child");

    await tester.pumpWidget(
      _probe(
        setting: const PregoLayoutGuideSettings(
          enabled: false,
          safeAreas: true,
          contentBounds: true,
          spacingGrid: false,
        ),
        child: const SizedBox.expand(key: childKey),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(find.byKey(const Key("prego-layout-guides-overlay")), findsNothing);
  });

  testWidgets("enabled layout guides read the simulated viewport safe areas", (tester) async {
    const childKey = Key("use-case-child");
    const setting = PregoLayoutGuideSettings(
      enabled: true,
      safeAreas: true,
      contentBounds: true,
      spacingGrid: true,
    );

    await tester.pumpWidget(
      _probe(
        setting: setting,
        viewPadding: const EdgeInsets.fromLTRB(8, 62, 10, 34),
        child: const ColoredBox(
          color: Color(0xFF141414),
          child: SizedBox.expand(key: childKey),
        ),
      ),
    );

    final overlay = tester.widget<CustomPaint>(find.byKey(const Key("prego-layout-guides-overlay")));
    final painter = overlay.painter! as PregoLayoutGuidesPainter;
    final stack = tester.widget<Stack>(find.byType(Stack).last);

    expect(painter.setting, setting);
    expect(painter.viewPadding, const EdgeInsets.fromLTRB(8, 62, 10, 34));
    expect(stack.children.first, isA<ColoredBox>());
    expect(stack.children.last, isA<Positioned>());
    final ignorePointers = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byKey(const Key("prego-layout-guides-overlay")),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(ignorePointers.any((widget) => widget.ignoring), isTrue);
  });
}

Widget _probe({
  required PregoLayoutGuideSettings setting,
  required Widget child,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) {
  final addon = PregoLayoutGuidesAddon();
  return material.MaterialApp(
    theme: pregoCatalogDarkTheme,
    home: MediaQuery(
      data: MediaQueryData(size: const Size(440, 956), viewPadding: viewPadding),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: material.Builder(builder: (context) => addon.buildUseCase(context, child, setting)),
      ),
    ),
  );
}
