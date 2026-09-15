import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("floating sheet uses $brightness Prego tokens and safe-area spacing", (tester) async {
      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [prego]),
          home: const MediaQuery(
            data: MediaQueryData(size: Size(402, 874), padding: EdgeInsets.only(top: 62, bottom: 34)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: PregoActionSheet(
                  title: "Allow this action?",
                  topInset: 62,
                  actions: SizedBox(key: Key("actions"), height: 164),
                  child: SizedBox(height: 44),
                ),
              ),
            ),
          ),
        ),
      );
      final decorationFinder = find.descendant(of: find.byType(PregoActionSheet), matching: find.byType(DecoratedBox));
      final decoration = tester.widget<DecoratedBox>(decorationFinder).decoration as BoxDecoration;
      expect(decoration.color, prego.colors.bgSurface2);
      expect(decoration.borderRadius, BorderRadius.circular(PregoRadius.x8l));
      final sheet = tester.getRect(decorationFinder);
      final screen = tester.getRect(find.byType(Scaffold));
      expect(sheet.left, PregoSpacing.xl);
      expect(screen.right - sheet.right, PregoSpacing.xl);
      expect(screen.bottom - sheet.bottom, 34);
      expect(tester.getTopLeft(find.text("Allow this action?")).dy - sheet.top, 26);
      expect(sheet.bottom - tester.getBottomLeft(find.byKey(const Key("actions"))).dy, PregoSpacing.xl);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(874, 402)]) {
    testWidgets("long content and large text keep actions visible at $size", (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: PregoActionSheet(
                  title: "Allow this action?",
                  topInset: 24,
                  actions: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: PregoSpacing.xl,
                    children: [
                      for (final label in ["Allow", "Always approve", "Don’t allow"])
                        PregoButtonsSolid(
                          label: label,
                          hierarchy: PregoButtonsSolidHierarchy.secondary,
                          size: PregoButtonsSolidSize.lg,
                          fullWidth: true,
                          onPressed: () {},
                        ),
                    ],
                  ),
                  child: const SizedBox(height: 2000),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text("Don’t allow").hitTestable(), findsOneWidget);
      expect(find.text("Allow").hitTestable(), findsOneWidget);
      expect(find.text("Always approve").hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
