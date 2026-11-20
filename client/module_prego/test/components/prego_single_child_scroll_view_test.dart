import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

Widget _frame({required Widget view}) => MaterialApp(
  home: Center(child: SizedBox(width: 200, child: view)),
);

void main() {
  testWidgets(
    "content that fits sizes as in a SingleChildScrollView and stays still under a drag",
    variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.android}),
    (tester) async {
      const padding = EdgeInsets.all(8);
      const content = SizedBox(height: 100, child: Text("Fits"));
      await tester.pumpWidget(
        _frame(
          view: const SingleChildScrollView(padding: padding, child: content),
        ),
      );
      final expected = tester.getSize(find.byType(SingleChildScrollView));

      await tester.pumpWidget(
        _frame(
          view: const PregoSingleChildScrollView(controller: null, padding: padding, child: content),
        ),
      );
      expect(tester.getSize(find.byType(PregoSingleChildScrollView)), expected);
      expect(
        tester.getTopLeft(find.text("Fits")) - tester.getTopLeft(find.byType(PregoSingleChildScrollView)),
        const Offset(8, 8),
      );

      final position = Scrollable.of(tester.element(find.text("Fits"))).position;
      final drag = await tester.startGesture(tester.getCenter(find.text("Fits")));
      await drag.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(position.pixels, 0, reason: "content that fits must not bounce");
      await drag.up();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    "a text field scrolling inside reaches the view as a nested scroll, so only its own scrollbar shows",
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      final fieldScroll = ScrollController();
      addTearDown(fieldScroll.dispose);
      final text = TextEditingController(text: List.filled(20, "line").join("\n"));
      addTearDown(text.dispose);
      final depths = <int>[];
      await tester.pumpWidget(
        _frame(
          view: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              depths.add(notification.depth);
              return false;
            },
            child: Material(
              child: PregoSingleChildScrollView(
                controller: null,
                child: TextField(controller: text, scrollController: fieldScroll, maxLines: 3),
              ),
            ),
          ),
        ),
      );

      fieldScroll.jumpTo(40);
      await tester.pump();

      expect(depths, isNotEmpty);
      // A view's scrollbar and overscroll stretch answer only depth 0.
      expect(depths, everyElement(1));
    },
  );
}
