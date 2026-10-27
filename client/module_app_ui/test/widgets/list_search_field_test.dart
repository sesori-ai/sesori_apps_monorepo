import "dart:ui" as ui;

import "package:flutter/gestures.dart" show PointerDeviceKind;
import "package:flutter/rendering.dart" show RenderRepaintBoundary;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/widgets/list_search_field.dart";
import "package:theme_prego/module_prego.dart";

const _boundary = ValueKey("list-search-field-boundary");
const _width = 300.0;

/// The surfaces the field sits on: the sidebar's floating panel and the pages.
enum _Surface() {
  panel,
  page,
}

Future<void> _pump(WidgetTester tester, {required Brightness brightness, required _Surface surface}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox(
              width: _width,
              child: Builder(
                builder: (context) => Material(
                  color: switch (surface) {
                    _Surface.panel => context.prego.colors.bgSecondary,
                    _Surface.page => context.prego.colors.bgSurface1,
                  },
                  child: ListSearchField(
                    query: "",
                    hintText: "Search",
                    autofocus: false,
                    padding: const EdgeInsets.all(16),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// The rendered colours of the field's fill, past its hint, and of the
/// surface in its padding.
Future<({Color fill, Color surface})> _colors(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
  late ({Color fill, Color surface}) colors;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final width = image.width;
    final height = image.height;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    Color at({required int x, required int y}) {
      final offset = (y * width + x) * 4;
      return Color.fromARGB(
        255,
        bytes?.getUint8(offset) ?? 0,
        bytes?.getUint8(offset + 1) ?? 0,
        bytes?.getUint8(offset + 2) ?? 0,
      );
    }

    final middle = height ~/ 2;
    colors = (fill: at(x: width - 60, y: middle), surface: at(x: 4, y: middle));
  });
  return colors;
}

int _step(Color a, Color b) => [
  ((a.r - b.r) * 255).abs(),
  ((a.g - b.g) * 255).abs(),
  ((a.b - b.b) * 255).abs(),
].reduce((x, y) => x > y ? x : y).round();

void main() {
  for (final brightness in Brightness.values) {
    for (final surface in _Surface.values) {
      testWidgets("on the ${surface.name} in ${brightness.name} mode, the resting field stands out", (tester) async {
        await _pump(tester, brightness: brightness, surface: surface);
        final colors = await _colors(tester);
        // The panel's #FCFCFC under the old #FAFAFA fill was 2 apart, too
        // faint to see.
        expect(_step(colors.fill, colors.surface), greaterThanOrEqualTo(6));
      });
    }
  }

  testWidgets("a hovering mouse leaves the fill as it rests", (tester) async {
    await _pump(tester, brightness: Brightness.light, surface: _Surface.panel);
    final resting = await _colors(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(TextField)));
    await tester.pumpAndSettle();
    final hovered = await _colors(tester);
    expect(hovered.fill, resting.fill);
  });
}
