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
}
