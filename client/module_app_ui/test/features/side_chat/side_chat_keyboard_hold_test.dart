import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/side_chat/show_side_chat_sheet.dart";

void main() {
  group("SideChatKeyboardHold", () {
    late BuildContext page;
    double pageKeyboard() => MediaQuery.viewInsetsOf(page).bottom;

    Future<Completer<void>> holdWithKeyboard(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery.fromView(
          view: tester.view,
          child: SideChatKeyboardHold(
            child: Builder(
              builder: (context) {
                page = context;
                MediaQuery.viewInsetsOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final closed = Completer<void>();
      SideChatKeyboardHold.holdUntil(context: page, closed: closed.future);
      // The sheet takes the composer's focus and the keyboard goes down.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      expect(pageKeyboard(), 300);
      return closed;
    }

    testWidgets("holds the page while the sheet is open, then eases it down", (tester) async {
      final closed = await holdWithKeyboard(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(pageKeyboard(), 300);

      closed.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(pageKeyboard(), inExclusiveRange(0, 300));
      await tester.pumpAndSettle();
      expect(pageKeyboard(), 0);
    });

    testWidgets("follows a keyboard that comes back as the sheet closes", (tester) async {
      final closed = await holdWithKeyboard(tester);
      closed.complete();
      await tester.pump();
      for (final keyboard in [100.0, 250.0, 300.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pump(const Duration(milliseconds: 50));
        expect(pageKeyboard(), greaterThanOrEqualTo(keyboard));
      }
      await tester.pumpAndSettle();
      expect(pageKeyboard(), 300);
    });
  });
}
