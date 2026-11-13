import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_laid_out_list_view.dart";

void main() {
  group("TranscriptLaidOutListView bottom edge", () {
    late ScrollController controller;
    late int carriedToNewestEnd;

    setUp(() {
      controller = ScrollController();
      carriedToNewestEnd = 0;
    });
    tearDown(() => controller.dispose());

    // The scaffold resizes its body above the keyboard, as the session screen's does.
    Future<void> pumpList(
      WidgetTester tester, {
      required double inset,
      required bool detached,
      required double keyboard,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: Scaffold(
              body: TranscriptBottomInset(
                inset: inset,
                child: TranscriptLaidOutListView(
                  reverse: true,
                  controller: controller,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: 100,
                  onLaidOut: () {},
                  detached: () => detached,
                  onCarriedToNewestEnd: () => carriedToNewestEnd++,
                  itemBuilder: (context, index) =>
                      SizedBox(key: ValueKey(index), height: 50, child: Text("row $index")),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    double rowTop(WidgetTester tester, {required int index}) => tester.getTopLeft(find.byKey(ValueKey(index))).dy;

    testWidgets("detached, the rows stay put as the inset grows and shrinks", (tester) async {
      await pumpList(tester, inset: 0, detached: true, keyboard: 0);
      controller.jumpTo(500);
      await tester.pump();
      final top = rowTop(tester, index: 15);

      await pumpList(tester, inset: 120, detached: true, keyboard: 0);
      expect(rowTop(tester, index: 15), top);
      expect(controller.offset, 620);

      await pumpList(tester, inset: 40, detached: true, keyboard: 0);
      expect(rowTop(tester, index: 15), top);
      expect(controller.offset, 540);
      expect(carriedToNewestEnd, 0);
    });

    testWidgets("detached, the rows stay put as the keyboard opens and closes", (tester) async {
      await pumpList(tester, inset: 60, detached: true, keyboard: 0);
      controller.jumpTo(500);
      await tester.pump();
      final top = rowTop(tester, index: 15);

      await pumpList(tester, inset: 60, detached: true, keyboard: 300);
      expect(rowTop(tester, index: 15), top);
      expect(controller.offset, 800);

      await pumpList(tester, inset: 60, detached: true, keyboard: 0);
      expect(rowTop(tester, index: 15), top);
      expect(controller.offset, 500);
    });

    testWidgets("following the newest end, the rows rise with the inset and the keyboard", (tester) async {
      await pumpList(tester, inset: 0, detached: false, keyboard: 0);
      final top = rowTop(tester, index: 0);

      await pumpList(tester, inset: 120, detached: false, keyboard: 0);
      expect(rowTop(tester, index: 0), top - 120);

      await pumpList(tester, inset: 120, detached: false, keyboard: 300);
      expect(rowTop(tester, index: 0), top - 420);
      expect(controller.offset, 0);
    });

    testWidgets("a glide back to the newest end is left to drive the offset", (tester) async {
      await pumpList(tester, inset: 120, detached: false, keyboard: 0);
      controller.jumpTo(300);
      await tester.pump();

      await pumpList(tester, inset: 40, detached: false, keyboard: 0);
      expect(controller.offset, 300);
    });

    testWidgets("detached, a shrink larger than the scroll offset settles at the newest end and says so", (
      tester,
    ) async {
      await pumpList(tester, inset: 120, detached: true, keyboard: 0);
      controller.jumpTo(30);
      await tester.pump();

      await pumpList(tester, inset: 0, detached: true, keyboard: 0);
      expect(controller.offset, 0);
      expect(carriedToNewestEnd, 1);
      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getBottomLeft(find.byKey(const ValueKey(0))).dy, screenHeight - 8);
    });
  });
}
