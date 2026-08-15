import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/review_tools/models/prego_annotation.dart";
import "package:sesori_design_catalog/src/review_tools/prego_review_tools.dart";
import "package:sesori_design_catalog/src/review_tools/presentation/prego_annotation_layer.dart";
import "package:sesori_design_catalog/src/review_tools/presentation/prego_measurement_layer.dart";
import "package:sesori_design_catalog/src/review_tools/repositories/prego_annotation_repository.dart";
import "package:sesori_design_catalog/src/review_tools/storage/prego_annotation_storage.dart";

void main() {
  testWidgets("routes modes and resets transient measurements when mode or scope changes", (tester) async {
    const firstScope = PregoAnnotationScope(useCasePath: "prego/button", viewportName: "iPhone");
    const secondScope = PregoAnnotationScope(useCasePath: "prego/button", viewportName: "Android");
    final repository = PregoAnnotationRepository(
      storage: PregoAnnotationStorage.test(read: (_) async => null, write: (_, _) async {}),
    );
    var mode = PregoReviewMode.interact;
    var scope = firstScope;
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
                width: 500,
                height: 600,
                child: PregoReviewToolsScope(
                  mode: mode,
                  annotationScope: scope,
                  repository: repository,
                  child: Builder(
                    builder: (context) => buildPregoReviewSurface(
                      context,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps += 1,
                        child: const SizedBox.expand(key: Key("review-child")),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byKey(const Key("review-child"))));
    expect(taps, 1);
    expect(find.byType(PregoMeasurementLayer), findsNothing);

    setHostState(() => mode = PregoReviewMode.measure);
    await tester.pump();
    expect(find.byType(PregoMeasurementLayer), findsOneWidget);
    await tester.dragFrom(const Offset(80, 220), const Offset(170, 80));
    await tester.pump();
    expect(find.text("1 pinned"), findsOneWidget);

    setHostState(() => scope = secondScope);
    await tester.pump();
    expect(find.textContaining("pinned"), findsNothing);

    setHostState(() => mode = PregoReviewMode.annotate);
    await tester.pumpAndSettle();
    expect(find.byType(PregoAnnotationLayer), findsOneWidget);

    setHostState(() => mode = PregoReviewMode.interact);
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byKey(const Key("review-child"))));
    expect(taps, 2);
  });
}
