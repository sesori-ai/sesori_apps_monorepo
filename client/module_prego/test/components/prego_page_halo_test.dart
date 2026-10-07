import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

const _page = Color(0xFF112233);

Widget _control({required Color color}) => ColoredBox(color: color);

Widget _layer({required List<Widget> children}) {
  return Theme(
    data: ThemeData(scaffoldBackgroundColor: _page),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 100,
          child: PregoPageHaloLayer(child: Stack(children: children)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("every halo paints beneath every control, the bottom one down to the layer's edge", (tester) async {
    const pill = Color(0xFFFF0000);
    const neighbour = Color(0xFF00FF00);
    const composer = Color(0xFF0000FF);
    await tester.pumpWidget(
      _layer(
        children: [
          Positioned(
            left: 10,
            top: 10,
            width: 40,
            height: 20,
            child: PregoPageHalo(radius: 8, reachesLayerBottom: false, child: _control(color: pill)),
          ),
          Positioned(
            left: 56,
            top: 10,
            width: 40,
            height: 20,
            child: PregoPageHalo(radius: 8, reachesLayerBottom: false, child: _control(color: neighbour)),
          ),
          Positioned(
            left: 10,
            top: 40,
            width: 100,
            height: 30,
            child: PregoPageHalo(radius: 10, reachesLayerBottom: true, child: _control(color: composer)),
          ),
        ],
      ),
    );

    final pillShape = RRect.fromRectAndRadius(const Rect.fromLTWH(10, 10, 40, 20), const Radius.circular(8));
    final neighbourShape = RRect.fromRectAndRadius(const Rect.fromLTWH(56, 10, 40, 20), const Radius.circular(8));
    final composerShape = RRect.fromRectAndCorners(
      const Rect.fromLTRB(10, 40, 110, 100),
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
    );
    expect(
      tester.renderObject(find.byType(PregoPageHaloLayer)),
      paints
        ..rrect(rrect: pillShape.inflate(14), color: _page)
        ..rrect(rrect: pillShape, color: _page)
        ..rrect(rrect: neighbourShape.inflate(14), color: _page)
        ..rrect(rrect: neighbourShape, color: _page)
        ..rrect(rrect: composerShape.inflate(14), color: _page)
        ..rrect(rrect: composerShape, color: _page)
        ..rect(color: pill)
        ..rect(color: neighbour)
        ..rect(color: composer),
    );
  });

  testWidgets("a fading control takes its halo with it", (tester) async {
    await tester.pumpWidget(
      _layer(
        children: [
          Positioned(
            left: 10,
            top: 10,
            width: 40,
            height: 20,
            child: Opacity(
              opacity: 0.5,
              child: PregoPageHalo(
                radius: 8,
                reachesLayerBottom: false,
                child: _control(color: const Color(0xFFFF0000)),
              ),
            ),
          ),
        ],
      ),
    );

    expect(
      tester.renderObject(find.byType(PregoPageHaloLayer)),
      paints..rrect(color: _page.withValues(alpha: 0.5)),
    );
  });
}
