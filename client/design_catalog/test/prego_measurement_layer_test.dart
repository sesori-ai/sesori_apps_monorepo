import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/review_tools/presentation/prego_measurement_layer.dart";

void main() {
  test("snaps to nearby canvas and target axes", () {
    final point = snapPregoMeasurementPoint(
      point: const Offset(98, 153),
      canvasSize: const Size(400, 800),
      targetRects: const [Rect.fromLTWH(100, 150, 120, 60)],
    );

    expect(point, const Offset(100, 150));
    expect(
      snapPregoMeasurementPoint(
        point: const Offset(4, 797),
        canvasSize: const Size(400, 800),
        targetRects: const [],
      ),
      const Offset(0, 800),
    );
  });

  test("locks a drag to its dominant axis", () {
    expect(
      lockPregoMeasurementAxis(start: const Offset(10, 10), point: const Offset(90, 35)),
      const Offset(90, 10),
    );
    expect(
      lockPregoMeasurementAxis(start: const Offset(10, 10), point: const Offset(25, 100)),
      const Offset(10, 100),
    );
  });

  testWidgets("pins logical-pixel measurements, locks with Shift, and clears with Escape", (tester) async {
    var componentTaps = 0;
    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Scaffold(
          body: SizedBox(
            width: 500,
            height: 600,
            child: PregoMeasurementLayer(
              child: Center(
                child: GestureDetector(
                  onTap: () => componentTaps += 1,
                  child: const SizedBox(key: Key("measured-component"), width: 160, height: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(80, 220), const Offset(210, 95));
    await tester.pump();
    expect(find.text("1 pinned"), findsOneWidget);
    expect(componentTaps, 0, reason: "measure mode must not activate the previewed component");

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final gesture = await tester.startGesture(const Offset(90, 420), kind: PointerDeviceKind.mouse);
    await gesture.moveTo(const Offset(310, 455));
    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(find.text("2 pinned"), findsOneWidget);
    final painter = _measurementPainter(tester);
    expect(painter.measurements.last.vertical, 0);
    expect(painter.measurements.last.horizontal, greaterThan(200));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.textContaining("pinned"), findsNothing);
    expect(_measurementPainter(tester).measurements, isEmpty);
  });
}

PregoMeasurementPainter _measurementPainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(find.byKey(const Key("prego-measurement-overlay")));
  final painter = customPaint.painter;
  if (painter is PregoMeasurementPainter) return painter;
  throw StateError("Measurement overlay has an unexpected painter");
}
