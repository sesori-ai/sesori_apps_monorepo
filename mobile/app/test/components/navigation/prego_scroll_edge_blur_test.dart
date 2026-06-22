import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Guards for the top scroll-edge blur.
///
/// 1. [PregoScrollEdgeBlur] must render as a graduated stack of clipped
///    [BackdropFilter] bands wrapped in an [IgnorePointer] — never a single
///    masked filter (a [ShaderMask] `saveLayer` empties the backdrop under
///    Impeller and renders glass black) and never pointer-absorbing (taps must
///    pass through to the content scrolling beneath it).
/// 2. [PregoGlassScaffold] must install the blur only when the body actually
///    scrolls behind the bar ([PregoGlassScaffold.extendBodyBehindBar]).
void main() {
  Future<void> pumpBlur(
    WidgetTester tester, {
    required double height,
    required double plateauHeight,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        // Constrain width only and leave height loose, so the blur adopts its
        // own [PregoScrollEdgeBlur.height] instead of being stretched to fill.
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            child: PregoScrollEdgeBlur(height: height, plateauHeight: plateauHeight),
          ),
        ),
      ),
    );
  }

  testWidgets("renders multiple BackdropFilter bands inside an IgnorePointer", (tester) async {
    await pumpBlur(tester, height: 120, plateauHeight: 90);

    // More than one band — a plateau plus the release ramp — so the blur can
    // step down rather than stop on a hard line. All bands sit inside the
    // IgnorePointer so taps reach the content scrolling beneath.
    expect(
      find.descendant(of: find.byType(IgnorePointer), matching: find.byType(BackdropFilter)),
      findsAtLeastNWidgets(2),
    );
  });

  testWidgets("sizes itself to the full blur zone height", (tester) async {
    await pumpBlur(tester, height: 120, plateauHeight: 90);
    expect(tester.getSize(find.byType(PregoScrollEdgeBlur)).height, 120);
  });

  testWidgets("tiles graduated bands from the top edge downward", (tester) async {
    await pumpBlur(tester, height: 140, plateauHeight: 80);

    final blurTop = tester.getTopLeft(find.byType(PregoScrollEdgeBlur)).dy;
    final blurBottom = tester.getBottomLeft(find.byType(PregoScrollEdgeBlur)).dy;

    final bandTops = tester
        .renderObjectList<RenderBox>(find.byType(BackdropFilter))
        .map((box) => box.localToGlobal(Offset.zero).dy)
        .toList()
      ..sort();

    // Several bands (the plateau + ramp slices), all within the zone.
    expect(bandTops.length, greaterThanOrEqualTo(3));
    expect(bandTops.first, moreOrLessEquals(blurTop, epsilon: 0.5), reason: "a band must start at the top edge");
    expect(bandTops.last, lessThan(blurBottom), reason: "bands must stay within the zone");
    // The bands step downward (distinct offsets), i.e. the blur is graduated
    // rather than a single uniform layer.
    expect(bandTops.last, greaterThan(bandTops.first), reason: "bands must tile downward, not stack in place");
  });

  group("PregoGlassScaffold wiring", () {
    Future<void> pumpScaffold(WidgetTester tester, {required bool extendBehind}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: PregoGlassScaffold(
            title: "Title",
            inlineTitle: true,
            automaticallyImplyLeading: false,
            extendBodyBehindBar: extendBehind,
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("installs the scroll-edge blur when the body scrolls behind the bar", (tester) async {
      await pumpScaffold(tester, extendBehind: true);
      expect(find.byType(PregoScrollEdgeBlur), findsOneWidget);
    });

    testWidgets("omits the blur when the body is inset below the bar", (tester) async {
      await pumpScaffold(tester, extendBehind: false);
      expect(find.byType(PregoScrollEdgeBlur), findsNothing);
    });
  });
}
