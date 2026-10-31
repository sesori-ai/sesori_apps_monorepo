import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/prego_floating_bottom_controls_layout.dart";

void main() {
  const paneSize = Size(400, 600);

  /// A pane reporting each height its content builds with, under controls
  /// of [height]; no controls at all when that is null.
  Widget pane({required double? height, required List<double> heights}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: paneSize,
          child: PregoFloatingBottomControlsLayout(
            contentBuilder: (context, controlsHeight) {
              heights.add(controlsHeight);
              return const SizedBox.expand(key: Key("content"));
            },
            controls: height == null ? null : SizedBox(key: const Key("controls"), height: height),
          ),
        ),
      ),
    );
  }

  testWidgets("the content fills the pane, and the controls sit at its bottom over the full width", (tester) async {
    await tester.pumpWidget(pane(height: 100, heights: []));

    final origin = tester.getTopLeft(find.byType(PregoFloatingBottomControlsLayout));
    expect(tester.getSize(find.byKey(const Key("content"))), paneSize);
    expect(tester.getRect(find.byKey(const Key("controls"))), (origin + const Offset(0, 500)) & const Size(400, 100));
  });

  testWidgets("the content builds with the controls' height in their first frame and each one they change", (
    tester,
  ) async {
    final heights = <double>[];

    await tester.pumpWidget(pane(height: 100, heights: heights));
    expect(heights, [100]);

    await tester.pumpWidget(pane(height: 80, heights: heights));
    expect(heights, [100, 80]);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: "Nothing waits for another frame.");
  });

  testWidgets("no controls leave the content with no height to clear", (tester) async {
    final heights = <double>[];

    await tester.pumpWidget(pane(height: null, heights: heights));
    expect(heights, [0]);

    await tester.pumpWidget(pane(height: 80, heights: heights));
    await tester.pumpWidget(pane(height: null, heights: heights));
    expect(heights, [0, 80, 0]);
  });

  testWidgets("a change inside the controls that keeps their height leaves the content alone", (tester) async {
    final heights = <double>[];
    late StateSetter rebuildControls;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PregoFloatingBottomControlsLayout(
          contentBuilder: (context, controlsHeight) {
            heights.add(controlsHeight);
            return const SizedBox.expand();
          },
          controls: StatefulBuilder(
            builder: (context, setState) {
              rebuildControls = setState;
              return const SizedBox(height: 100);
            },
          ),
        ),
      ),
    );

    rebuildControls(() {});
    await tester.pump();

    expect(heights, [100]);
  });

  testWidgets("touches reach the controls first and the content everywhere else", (tester) async {
    var contentTaps = 0;
    var controlsTaps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.fromSize(
            size: paneSize,
            child: PregoFloatingBottomControlsLayout(
              contentBuilder: (context, controlsHeight) => GestureDetector(
                key: const Key("content"),
                behavior: HitTestBehavior.opaque,
                onTap: () => contentTaps++,
              ),
              controls: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: GestureDetector(
                  key: const Key("controls"),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controlsTaps++,
                  child: const SizedBox(height: 100),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key("controls")));
    expect((controlsTaps, contentTaps), (1, 0));

    final pane = tester.getRect(find.byType(PregoFloatingBottomControlsLayout));
    await tester.tapAt(pane.bottomLeft + const Offset(10, -10));
    expect((controlsTaps, contentTaps), (1, 1));

    await tester.tapAt(pane.topCenter + const Offset(0, 10));
    expect((controlsTaps, contentTaps), (1, 2));
  });
}
