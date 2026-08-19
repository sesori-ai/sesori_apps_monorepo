import "dart:async";

import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/inspector/prego_inspection_tokens.dart";
import "package:sesori_design_catalog/src/prego_catalog_inspector.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/review_tools/models/prego_annotation.dart";
import "package:sesori_design_catalog/src/review_tools/prego_review_tools.dart";
import "package:sesori_design_catalog/src/review_tools/presentation/prego_review_target.dart";
import "package:sesori_design_catalog/src/review_tools/repositories/prego_annotation_repository.dart";
import "package:sesori_design_catalog/src/review_tools/storage/prego_annotation_storage.dart";
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

  testWidgets("review target discovery skips hidden subtrees", (tester) async {
    final rootKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: rootKey,
          child: const Offstage(offstage: true, child: Text("Hidden target")),
        ),
      ),
    );

    final root = rootKey.currentContext!.findRenderObject()!;
    final targets = const PregoReviewTargetResolver().collect(contentRoot: root);
    expect(targets.where((target) => target.label == "Text"), isEmpty);
  });

  testWidgets("hover aligns to a scaled text target and click pins nested details", (tester) async {
    var pressCount = 0;
    String? copiedReference;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Scaffold(
          body: SizedBox(
            width: 700,
            height: 600,
            child: PregoCatalogInspector(
              copyText: ({required text}) async => copiedReference = text,
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

    final copyButton = find.text("Copy medium");
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();
    expect(copiedReference, "context.prego.textTheme.textSm.medium");
    expect(find.text("Copied"), findsOneWidget);
    expect(find.text("Text"), findsOneWidget);

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

  testWidgets("clears a pinned target when a knob rebuild removes its render object", (tester) async {
    var showLabel = true;
    late StateSetter setHostState;
    final pointer = TestPointer(2, PointerDeviceKind.mouse);

    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return SizedBox(
                width: 700,
                height: 600,
                child: PregoCatalogInspector(
                  child: Center(
                    child: showLabel
                        ? const Text("Replace me", key: Key("replaceable-label"))
                        : const SizedBox(key: Key("replacement-icon"), width: 40, height: 40),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    final labelPosition = tester.getCenter(find.byKey(const Key("replaceable-label")));
    await tester.sendEventToBinding(pointer.addPointer(location: labelPosition));
    await tester.sendEventToBinding(pointer.hover(labelPosition));
    await tester.pump();
    await tester.tapAt(labelPosition);
    await tester.pump();
    expect(find.byKey(const Key("prego-inspector-card")), findsOneWidget);

    setHostState(() => showLabel = false);
    await tester.pump();
    setHostState(() {});
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("replacement-icon")), findsOneWidget);
    expect(find.byKey(const Key("prego-inspector-card")), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.sendEventToBinding(pointer.removePointer());
  });

  testWidgets("reports clipboard failures without unpinning the target", (tester) async {
    final pointer = TestPointer(3, PointerDeviceKind.mouse);
    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: SizedBox(
          width: 700,
          height: 600,
          child: PregoCatalogInspector(
            copyText: ({required text}) async => throw StateError("blocked"),
            child: Builder(
              builder: (context) => Text("Copy me", style: context.prego.textTheme.textSm.medium),
            ),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.text("Copy me"));
    await tester.sendEventToBinding(pointer.addPointer(location: position));
    await tester.sendEventToBinding(pointer.hover(position));
    await tester.pump();
    await tester.tapAt(position);
    await tester.pump();

    final copyButton = find.text("Copy medium");
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();

    expect(find.text("Copy failed"), findsOneWidget);
    expect(find.byKey(const Key("prego-inspector-card")), findsOneWidget);
    await tester.sendEventToBinding(pointer.removePointer());
  });

  testWidgets("ignores an older clipboard failure after a newer copy succeeds", (tester) async {
    final firstCopy = Completer<void>();
    var copyCount = 0;
    final pointer = TestPointer(4, PointerDeviceKind.mouse);
    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: SizedBox(
          width: 700,
          height: 600,
          child: PregoCatalogInspector(
            copyText: ({required text}) {
              copyCount += 1;
              return copyCount == 1 ? firstCopy.future : Future.value();
            },
            child: Builder(
              builder: (context) => Text("Copy me", style: context.prego.textTheme.textSm.medium),
            ),
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.text("Copy me"));
    await tester.sendEventToBinding(pointer.addPointer(location: position));
    await tester.sendEventToBinding(pointer.hover(position));
    await tester.pump();
    await tester.tapAt(position);
    await tester.pump();

    final copyButton = find.text("Copy medium");
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();
    await tester.tap(copyButton);
    await tester.pump();

    expect(copyCount, 2);
    expect(find.text("Copied"), findsOneWidget);

    firstCopy.completeError(StateError("blocked"));
    await tester.pump();

    expect(find.text("Copied"), findsOneWidget);
    expect(find.text("Copy failed"), findsNothing);
    await tester.sendEventToBinding(pointer.removePointer());
  });

  testWidgets("interact review mode leaves component interaction untouched", (tester) async {
    final repository = PregoAnnotationRepository(
      storage: PregoAnnotationStorage.test(
        read: ({required key}) async => null,
        write: ({required key, required value}) async {},
      ),
    );
    const child = SizedBox(key: Key("child"));
    const scope = PregoAnnotationScope(useCasePath: "prego/button", viewportName: "iPhone");

    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogLightTheme,
        home: PregoReviewToolsScope(
          mode: PregoReviewMode.interact,
          annotationScope: scope,
          repository: repository,
          child: material.Builder(builder: (context) => buildPregoReviewSurface(context, child: child)),
        ),
      ),
    );
    expect(find.byKey(const Key("child")), findsOneWidget);
    expect(find.byType(PregoCatalogInspector), findsNothing);
  });
}
