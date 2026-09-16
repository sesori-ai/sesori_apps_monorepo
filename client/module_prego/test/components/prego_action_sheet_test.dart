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

  for (final viewport in [
    (size: const Size(320, 568), textScale: 2.0, keyboard: 0.0),
    (size: const Size(874, 402), textScale: 3.0, keyboard: 0.0),
    (size: const Size(874, 402), textScale: 1.0, keyboard: 216.0),
    (size: const Size(402, 874), textScale: 2.0, keyboard: 336.0),
  ]) {
    testWidgets("all actions remain reachable in constrained viewport $viewport", (tester) async {
      final pressed = <String>[];
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport.size,
              textScaler: TextScaler.linear(viewport.textScale),
              viewInsets: EdgeInsets.only(bottom: viewport.keyboard),
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
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
                          onPressed: () => pressed.add(label),
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
      expect(find.text("Allow this action?").hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ["Allow", "Always approve", "Don’t allow"]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(pressed, ["Allow", "Always approve", "Don’t allow"]);
    });
  }

  testWidgets("a nonzero keyboard inset takes precedence over safe-area padding", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(800, 600),
            padding: EdgeInsets.only(bottom: 26),
            viewInsets: EdgeInsets.only(bottom: 8),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PregoActionSheet(
                title: "Allow this action?",
                topInset: 24,
                actions: SizedBox(height: 164),
                child: SizedBox(height: 44),
              ),
            ),
          ),
        ),
      ),
    );
    final surface = find.descendant(of: find.byType(PregoActionSheet), matching: find.byType(DecoratedBox));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(screen.bottom - tester.getRect(surface).bottom, PregoSpacing.xl);
    expect(tester.takeException(), isNull);
  });
}
