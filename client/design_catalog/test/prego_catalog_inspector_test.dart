import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/inspector/prego_inspection_tokens.dart";
import "package:sesori_design_catalog/src/prego_catalog_inspector.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("token resolver reports candidates instead of claiming source usage", (tester) async {
    late PregoInspectionTokenResolver resolver;

    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Builder(
          builder: (context) {
            resolver = PregoInspectionTokenResolver(context: context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final colors = PregoDesignSystem.dark.colors;
    final colorMatch = resolver.matchColor(colors.textSecondary);
    expect(colorMatch.candidates, isNotEmpty);
    expect(
      colorMatch.candidates,
      contains(
        isA<PregoInspectionToken<Color>>()
            .having((token) => token.kind, "kind", PregoInspectionTokenKind.semanticColor)
            .having((token) => token.name, "name", "text-secondary"),
      ),
    );

    final style = PregoDesignSystem.dark.textTheme.textSm.medium.copyWith(color: colors.textSecondary);
    final typographyMatch = resolver.matchTypography(style);
    expect(typographyMatch.candidates, hasLength(1));
    expect(typographyMatch.candidates.single.name, "text-sm / medium");

    final spacingMatch = resolver.matchDimension(
      8,
      kinds: const {PregoInspectionTokenKind.spacing, PregoInspectionTokenKind.spacingPrimitive},
    );
    expect(spacingMatch.candidates.map((token) => token.name), containsAll(["md", "spacing2"]));

    final unmapped = resolver.matchDimension(7.25, kinds: const {PregoInspectionTokenKind.radius});
    expect(unmapped.candidates, isEmpty);
  });

  testWidgets("hover aligns to a scaled text target and click pins nested details", (tester) async {
    var pressCount = 0;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Scaffold(
          body: SizedBox(
            width: 700,
            height: 600,
            child: PregoCatalogInspector(
              child: Center(
                child: Transform.scale(
                  scale: 0.5,
                  child: GestureDetector(
                    onTap: () => pressCount += 1,
                    child: Builder(
                      builder: (context) => Container(
                        key: const Key("inspection-surface"),
                        width: 240,
                        height: 120,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.prego.colors.bgSurface1,
                          borderRadius: BorderRadius.circular(PregoRadius.lg),
                        ),
                        child: Text(
                          "Inspect me",
                          style: context.prego.textTheme.textSm.medium.copyWith(
                            color: context.prego.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final textRect = tester.getRect(find.text("Inspect me"));
    final position = textRect.center;
    await tester.sendEventToBinding(pointer.addPointer(location: position));
    await tester.sendEventToBinding(pointer.hover(position));
    await tester.pump();

    expect(find.byKey(const Key("prego-inspector-card")), findsOneWidget);
    expect(find.text("Text"), findsOneWidget);
    final highlightRect = tester.getRect(find.byKey(const Key("prego-inspector-highlight")));
    expect(highlightRect.left, closeTo(textRect.left, 0.01));
    expect(highlightRect.top, closeTo(textRect.top, 0.01));
    expect(highlightRect.width, closeTo(textRect.width, 0.01));
    expect(highlightRect.height, closeTo(textRect.height, 0.01));

    await tester.tapAt(position);
    await tester.pump();

    expect(pressCount, 0, reason: "inspection must not activate the previewed component");
    expect(find.text("Overview"), findsOneWidget);
    expect(find.text("Typography"), findsOneWidget);
    expect(find.textContaining("text-sm / medium"), findsOneWidget);
    expect(find.textContaining("Semantic color"), findsWidgets);

    final firstPosition = tester.widget<Text>(find.byKey(const Key("prego-inspector-position"))).data;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.bracketRight);
    await tester.pump();
    final secondPosition = tester.widget<Text>(find.byKey(const Key("prego-inspector-position"))).data;
    expect(secondPosition, isNot(firstPosition));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key("prego-inspector-card")), findsNothing);

    await tester.sendEventToBinding(pointer.removePointer());
  });

  testWidgets("disabled addon leaves component interaction untouched", (tester) async {
    final addon = PregoCatalogInspectorAddon();
    const child = SizedBox(key: Key("child"));

    expect(addon.groupName, "inspector");
    expect(addon.valueFromQueryGroup(const {}), isFalse);
    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogLightTheme,
        home: material.Builder(
          builder: (context) => addon.buildUseCase(context, child, false),
        ),
      ),
    );
    expect(find.byKey(const Key("child")), findsOneWidget);
    expect(find.byType(PregoCatalogInspector), findsNothing);
  });
}
