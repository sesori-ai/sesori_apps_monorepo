import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/review_tools/models/prego_annotation.dart";
import "package:sesori_design_catalog/src/review_tools/presentation/prego_annotation_layer.dart";
import "package:sesori_design_catalog/src/review_tools/repositories/prego_annotation_repository.dart";
import "package:sesori_design_catalog/src/review_tools/storage/prego_annotation_storage.dart";

void main() {
  const phoneScope = PregoAnnotationScope(
    useCasePath: "prego/solid-button/playground",
    viewportName: "iPhone 16 Pro",
  );
  const androidScope = PregoAnnotationScope(
    useCasePath: "prego/solid-button/playground",
    viewportName: "Google Pixel 10 Pro",
  );

  test("annotation pins offset from the anchor and stay inside the canvas", () {
    const canvasSize = Size(393, 852);
    const anchors = [
      Offset.zero,
      Offset(393, 0),
      Offset(0, 852),
      Offset(393, 852),
      Offset(196.5, 426),
    ];

    for (final anchor in anchors) {
      final pinRect = layoutPregoAnnotationPin(anchor: anchor, canvasSize: canvasSize);

      expect((Offset.zero & canvasSize).contains(pinRect.topLeft), isTrue);
      expect((Offset.zero & canvasSize).contains(pinRect.bottomRight - const Offset(0.001, 0.001)), isTrue);
      expect(pinRect.contains(anchor), isFalse);
    }
  });

  testWidgets("creates and reloads a browser-local annotation in its exact scope", (tester) async {
    final values = <String, String>{};
    final repository = _repository(values);

    await _pumpLayer(tester, repository: repository, scope: phoneScope, layerKey: "initial");
    expect(find.text("Annotations · 0 open · 0 total"), findsOneWidget);

    final annotationAnchor = tester.getCenter(find.byKey(const Key("annotation-target")));
    await tester.tapAt(annotationAnchor);
    await tester.pump();
    expect(find.text("New annotation"), findsOneWidget);
    expect(
      find.textContaining("Annotations ·"),
      findsNothing,
      reason: "phone-sized canvases should show only one working panel at a time",
    );
    expect(tester.getRect(find.text("New annotation")).right, lessThanOrEqualTo(393));

    await tester.enterText(find.byType(material.TextFormField), "Check this button spacing");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();
    expect(find.text("Annotations · 1 open · 1 total"), findsOneWidget);
    expect(_annotationPins(), findsOneWidget);
    final pinRect = tester.getRect(_annotationPins());
    expect(pinRect.contains(annotationAnchor), isFalse);
    final leader = tester.widget<CustomPaint>(_annotationLeaders());
    final leaderPainter = leader.painter! as PregoAnnotationPinLeaderPainter;
    expect(leaderPainter.anchor, annotationAnchor);
    expect(leaderPainter.pinCenter, pinRect.center);
    expect(values, hasLength(1));

    await _pumpLayer(tester, repository: repository, scope: phoneScope, layerKey: "reload");
    expect(find.text("Annotations · 1 open · 1 total"), findsOneWidget);
    expect(_annotationPins(), findsOneWidget);

    await _pumpLayer(tester, repository: repository, scope: androidScope, layerKey: "other-scope");
    expect(find.text("Annotations · 0 open · 0 total"), findsOneWidget);
    expect(_annotationPins(), findsNothing);

    await _pumpLayer(tester, repository: repository, scope: phoneScope, layerKey: "return");
    expect(find.text("Annotations · 1 open · 1 total"), findsOneWidget);
    expect(_annotationPins(), findsOneWidget);
  });

  testWidgets("resolves and deletes an annotation from its pin", (tester) async {
    final repository = _repository(<String, String>{});
    await _pumpLayer(tester, repository: repository, scope: phoneScope, layerKey: "edit");
    await tester.tapAt(tester.getCenter(find.byKey(const Key("annotation-target"))));
    await tester.pump();
    await tester.enterText(find.byType(material.TextFormField), "Review me");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    await tester.tap(_annotationPins());
    await tester.pump();
    expect(find.text("Edit annotation"), findsOneWidget);
    await tester.tap(find.text("Resolve"));
    await tester.pumpAndSettle();
    expect(find.text("Annotations · 0 open · 1 total"), findsOneWidget);

    await tester.tap(_annotationPins());
    await tester.pump();
    expect(find.text("Reopen"), findsOneWidget);
    await tester.tap(find.text("Delete"));
    await tester.pumpAndSettle();
    expect(find.text("Annotations · 0 open · 0 total"), findsOneWidget);
    expect(_annotationPins(), findsNothing);
  });
}

Future<void> _pumpLayer(
  WidgetTester tester, {
  required PregoAnnotationRepository repository,
  required PregoAnnotationScope scope,
  required String layerKey,
}) async {
  await tester.pumpWidget(
    material.MaterialApp(
      theme: pregoCatalogDarkTheme,
      home: material.Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 393,
            height: 852,
            child: PregoAnnotationLayer(
              key: ValueKey(layerKey),
              scope: scope,
              repository: repository,
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  key: Key("annotation-target"),
                  decoration: BoxDecoration(color: Color(0xFF3366FF)),
                  child: SizedBox(width: 180, height: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _annotationPins() => find.byWidgetPredicate(
  (widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith("prego-annotation-pin-");
  },
);

Finder _annotationLeaders() => find.byWidgetPredicate(
  (widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith("prego-annotation-leader-");
  },
);

PregoAnnotationRepository _repository(Map<String, String> values) => PregoAnnotationRepository(
  storage: PregoAnnotationStorage.test(
    read: (key) async => values[key],
    write: (key, value) async => values[key] = value,
  ),
);
