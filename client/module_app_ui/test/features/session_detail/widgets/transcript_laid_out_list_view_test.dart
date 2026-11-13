import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_laid_out_list_view.dart";

void main() {
  group("TranscriptLaidOutListView bottom inset", () {
    late ScrollController controller;

    setUp(() => controller = ScrollController());
    tearDown(() => controller.dispose());

    Future<void> pumpList(WidgetTester tester, {required double inset}) => tester.pumpWidget(
      MaterialApp(
        home: TranscriptBottomInset(
          inset: inset,
          child: TranscriptLaidOutListView(
            reverse: true,
            controller: controller,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: 100,
            onLaidOut: () {},
            itemBuilder: (context, index) => SizedBox(key: ValueKey(index), height: 50, child: Text("row $index")),
          ),
        ),
      ),
    );

    double rowTop(WidgetTester tester, {required int index}) => tester.getTopLeft(find.byKey(ValueKey(index))).dy;

    testWidgets("scrolled away from the newest end, the rows stay put as the inset grows and shrinks", (tester) async {
      await pumpList(tester, inset: 0);
      controller.jumpTo(500);
      await tester.pump();
      final top = rowTop(tester, index: 15);

      await pumpList(tester, inset: 120);
      expect(rowTop(tester, index: 15), top);
      expect(controller.offset, 620);

      await pumpList(tester, inset: 40);
      expect(rowTop(tester, index: 15), top);
      expect(controller.offset, 540);
    });

    testWidgets("at the newest end, the rows rise clear of a growing inset", (tester) async {
      await pumpList(tester, inset: 0);
      final top = rowTop(tester, index: 0);

      await pumpList(tester, inset: 120);
      expect(rowTop(tester, index: 0), top - 120);
      expect(controller.offset, 0);
    });

    testWidgets("a shrink larger than the scroll offset settles the list at the newest end", (tester) async {
      await pumpList(tester, inset: 120);
      controller.jumpTo(30);
      await tester.pump();

      await pumpList(tester, inset: 0);
      expect(controller.offset, 0);
      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getBottomLeft(find.byKey(const ValueKey(0))).dy, screenHeight - 8);
    });
  });
}
