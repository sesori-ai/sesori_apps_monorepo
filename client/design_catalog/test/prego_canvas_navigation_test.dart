import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_canvas_navigation.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/review_tools/models/prego_annotation.dart";
import "package:sesori_design_catalog/src/review_tools/prego_review_tools.dart";
import "package:sesori_design_catalog/src/review_tools/repositories/prego_annotation_repository.dart";
import "package:sesori_design_catalog/src/review_tools/storage/prego_annotation_storage.dart";
import "package:widgetbook/widgetbook.dart";

void main() {
  test("exposes URL-shareable zoom and move settings", () {
    final addon = PregoCanvasNavigationAddon();

    expect(addon.fields.map((field) => field.name), ["zoom", "moveCanvas"]);
    expect(
      addon.valueFromQueryGroup({}),
      const PregoCanvasNavigationSettings(zoom: 1, moveCanvas: false),
    );
    expect(
      addon.valueFromQueryGroup({"zoom": "2.5", "moveCanvas": "true"}),
      const PregoCanvasNavigationSettings(zoom: 2.5, moveCanvas: true),
    );
    expect(
      addon.valueFromQueryGroup({"zoom": "0"}),
      const PregoCanvasNavigationSettings(zoom: 0.5, moveCanvas: false),
    );
    expect(
      addon.valueFromQueryGroup({"zoom": "4"}),
      const PregoCanvasNavigationSettings(zoom: 3, moveCanvas: false),
    );
    expect(
      addon.valueFromQueryGroup({"zoom": "NaN"}),
      const PregoCanvasNavigationSettings(zoom: 1, moveCanvas: false),
    );

    final zoomField = addon.fields.first as DoubleSliderField;
    expect(zoomField.min, 0.5);
    expect(zoomField.max, 3);
    expect(zoomField.divisions, 25);
  });

  testWidgets("zooms, gates panning to Interact, and resets pan for a new scope", (tester) async {
    const firstScope = PregoAnnotationScope(useCasePath: "prego/button", viewportName: "iPhone");
    const secondScope = PregoAnnotationScope(useCasePath: "prego/button", viewportName: "Android");
    final addon = PregoCanvasNavigationAddon();
    final repository = PregoAnnotationRepository(
      storage: PregoAnnotationStorage.test(
        read: ({required key}) async => null,
        write: ({required key, required value}) async {},
      ),
    );
    var mode = PregoReviewMode.interact;
    var scope = firstScope;
    var setting = const PregoCanvasNavigationSettings(zoom: 2, moveCanvas: false);
    var taps = 0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return SizedBox(
                width: 400,
                height: 400,
                child: PregoReviewToolsScope(
                  mode: mode,
                  annotationScope: scope,
                  repository: repository,
                  child: Builder(
                    builder: (context) => addon.buildUseCase(
                      context,
                      GestureDetector(
                        key: const Key("canvas-child"),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps += 1,
                        child: const SizedBox.expand(),
                      ),
                      setting,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(_canvasTransform(tester).transform.getMaxScaleOnAxis(), 2);
    await tester.tap(find.byKey(const Key("canvas-child")));
    expect(taps, 1);

    setHostState(
      () => setting = const PregoCanvasNavigationSettings(zoom: 2, moveCanvas: true),
    );
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.panEnabled, isTrue);
    expect(viewer.scaleEnabled, isFalse);
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);
    await tester.tap(find.byKey(const Key("canvas-child")), warnIfMissed: false);
    expect(taps, 1);

    final initialTranslation = viewer.transformationController!.value.getTranslation();
    await tester.drag(find.byType(InteractiveViewer), const Offset(60, 40));
    await tester.pumpAndSettle();
    final pannedTranslation = viewer.transformationController!.value.getTranslation();
    expect(pannedTranslation.x, isNot(initialTranslation.x));
    expect(pannedTranslation.y, isNot(initialTranslation.y));

    setHostState(() => mode = PregoReviewMode.measure);
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(_canvasTransform(tester).transform.getTranslation().x, pannedTranslation.x);
    expect(_canvasTransform(tester).transform.getTranslation().y, pannedTranslation.y);

    setHostState(() => scope = secondScope);
    await tester.pump();
    expect(_canvasTransform(tester).transform.getTranslation().x, 0);
    expect(_canvasTransform(tester).transform.getTranslation().y, 0);

    setHostState(() {
      mode = PregoReviewMode.interact;
      setting = const PregoCanvasNavigationSettings(zoom: 2, moveCanvas: false);
    });
    await tester.pump();
    await tester.tap(find.byKey(const Key("canvas-child")));
    expect(taps, 2);
  });
}

Transform _canvasTransform(WidgetTester tester) => tester.widget<Transform>(
  find.byKey(const Key("prego-canvas-navigation-transform")),
);
