import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness({required Widget child, required bool reducedMotion}) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

Widget _glass({required Widget? trailing}) =>
    PregoButtonsIconGlass(icon: TablerRegular.git_compare, onPressed: () {}, trailing: trailing);

Widget _solid({required Widget? trailing}) => PregoButtonsSolid(
  label: "Changes",
  hierarchy: PregoButtonsSolidHierarchy.secondary,
  size: PregoButtonsSolidSize.sm,
  onPressed: () {},
  labelTrailing: trailing,
);

const Widget _counts = SizedBox(width: 40, height: 10);

void main() {
  final buttons = <String, (Widget Function({required Widget? trailing}), Type)>{
    "PregoButtonsIconGlass": (_glass, PregoButtonsIconGlass),
    "PregoButtonsSolid": (_solid, PregoButtonsSolid),
  };

  for (final MapEntry(key: name, value: (build, type)) in buttons.entries) {
    group(name, () {
      double width(WidgetTester tester) => tester.getSize(find.byType(type)).width;

      testWidgets("grows and shrinks smoothly as trailing content arrives and leaves", (tester) async {
        await tester.pumpWidget(_harness(child: build(trailing: null), reducedMotion: false));
        final plain = width(tester);

        await tester.pumpWidget(_harness(child: build(trailing: _counts), reducedMotion: false));
        await tester.pumpAndSettle();
        final full = width(tester);
        expect(full, greaterThan(plain + 40));

        await tester.pumpWidget(_harness(child: build(trailing: null), reducedMotion: false));
        await tester.pump(const Duration(milliseconds: 100));
        expect(width(tester), allOf(greaterThan(plain), lessThan(full)));
        await tester.pumpAndSettle();
        expect(width(tester), plain);

        await tester.pumpWidget(_harness(child: build(trailing: _counts), reducedMotion: false));
        await tester.pump(const Duration(milliseconds: 100));
        expect(width(tester), allOf(greaterThan(plain), lessThan(full)));
        await tester.pumpAndSettle();
        expect(width(tester), full);
      });

      testWidgets("applies each change at once under reduced motion", (tester) async {
        await tester.pumpWidget(_harness(child: build(trailing: null), reducedMotion: true));
        final plain = width(tester);

        await tester.pumpWidget(_harness(child: build(trailing: _counts), reducedMotion: true));
        await tester.pump();
        expect(width(tester), greaterThan(plain + 40));
        expect(tester.hasRunningAnimations, isFalse);

        await tester.pumpWidget(_harness(child: build(trailing: null), reducedMotion: true));
        await tester.pump();
        expect(width(tester), plain);
        expect(tester.hasRunningAnimations, isFalse);
      });
    });
  }

  testWidgets("PregoButtonsIconGlass stays a circle without trailing content", (tester) async {
    await tester.pumpWidget(_harness(child: _glass(trailing: null), reducedMotion: false));

    expect(tester.getSize(find.byType(PregoButtonsIconGlass)), const Size.square(44));
  });
}
