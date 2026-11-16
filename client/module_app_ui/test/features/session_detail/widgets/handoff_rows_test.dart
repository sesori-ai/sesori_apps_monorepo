import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/handoff_card.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/handoff_marker_row.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_row_hold.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

Widget _app({required Widget child}) => MaterialApp(
  theme: buildPregoThemeData(brightness: Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SessionDetailPresentationScope(
    messageImageRepository: () => throw UnimplementedError(),
    imageSaver: () => throw UnimplementedError(),
    imageClipboard: () => throw UnimplementedError(),
    imageSharer: () => throw UnimplementedError(),
    sessionRepository: () => throw UnimplementedError("Prompt search is not under test"),
    createPendingFormCubit: ({required requestId, required sessionId}) => throw StateError("Unused fixture form"),
    createFilePreviewCubit: ({required reference}) => throw UnimplementedError("File previews are not under test"),
    createExternalActionCubit: ({required requestId, required sessionId}) =>
        throw UnimplementedError("External actions are not under test"),
    canShareImages: false,
    openExternalLink: ({required url, required mode}) async => false,
    openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
    openHarnessSettings: () {},
    openBridgeSettings: () {},
    child: Scaffold(body: child),
  ),
);

TranscriptHandoffMarker _marker({required TranscriptHandoffMarkerStatus status, required String? summary}) =>
    TranscriptHandoffMarker(targetSessionId: "target", targetTitle: "Codex review", status: status, summary: summary);

final _card = TranscriptHandoffCard(
  sourceSessionId: "source",
  sourceTitle: "Relay retries",
  summary: List.generate(30, (index) => "Decision $index and the reason it holds.").join("\n\n"),
  transcriptPath: "/tmp/handoff/transcript.md",
);

void main() {
  testWidgets("the marker keeps one height as the summary is written, then sent", (tester) async {
    final rowSizes = <Size>[];
    for (final status in TranscriptHandoffMarkerStatus.values) {
      await tester.pumpWidget(
        _app(
          child: Center(
            child: HandoffMarkerRow(
              marker: _marker(status: status, summary: "Done."),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      rowSizes.add(tester.getSize(find.byType(HandoffMarkerRow)));
    }
    expect(rowSizes.map((size) => size.height).toSet(), {HandoffMarkerRow.height});
  });

  testWidgets("the marker offers Open only once the summary is sent", (tester) async {
    await tester.pumpWidget(
      _app(
        child: HandoffMarkerRow(marker: _marker(status: TranscriptHandoffMarkerStatus.writing, summary: null)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Writing a summary for Codex review…"), findsWidgets);
    expect(find.byKey(const ValueKey("handoff-marker.open")), findsNothing);

    await tester.pumpWidget(
      _app(
        child: HandoffMarkerRow(
          marker: _marker(status: TranscriptHandoffMarkerStatus.sent, summary: "Done."),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Summary sent to Codex review"), findsOneWidget);
    expect(find.byKey(const ValueKey("handoff-marker.open")), findsOneWidget);

    await tester.pumpWidget(
      _app(
        child: HandoffMarkerRow(marker: _marker(status: TranscriptHandoffMarkerStatus.notSent, summary: null)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Couldn't send to Codex review"), findsOneWidget);
    expect(find.byKey(const ValueKey("handoff-marker.open")), findsNothing);
  });

  Future<ScrollController> pumpCardInList({required WidgetTester tester}) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        child: ListView(
          controller: controller,
          reverse: true,
          children: [
            for (var index = 0; index < 12; index++) SizedBox(height: 120, child: Text("newer $index")),
            HandoffCard(messageId: "card", card: _card),
            for (var index = 0; index < 6; index++) SizedBox(height: 120, child: Text("older $index")),
          ],
        ),
      ),
    );
    // Brings the card's bottom 100 above the screen's, or as near as the list allows.
    const cardBottom = 12 * 120 - 100.0;
    controller.jumpTo(
      controller.position.maxScrollExtent < cardBottom ? controller.position.maxScrollExtent : cardBottom,
    );
    await tester.pumpAndSettle();
    return controller;
  }

  final card = find.byType(HandoffCard);
  final toggle = find.byKey(const ValueKey("handoff-card.toggle"));

  /// Taps the toggle and checks that [edge] stays still every frame of the motion.
  Future<void> toggleHolding({required WidgetTester tester, required Offset Function() edge}) async {
    final held = edge();
    await tester.tap(toggle);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(edge().dy, moreOrLessEquals(held.dy, epsilon: 0.5));
    }
  }

  testWidgets("Show all and Show less move the card's bottom, never its top", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await pumpCardInList(tester: tester);
    final collapsed = tester.getSize(card).height;
    expect(find.text("Show all").hitTestable(), findsOneWidget);

    await toggleHolding(tester: tester, edge: () => tester.getTopLeft(card));
    expect(tester.getTopLeft(find.text("older 0")).dy, lessThan(tester.getTopLeft(card).dy));
    expect(tester.getSize(card).height, greaterThan(collapsed + 200));

    // Scrolls Show less into view with the card's top still on screen.
    controller.jumpTo(controller.offset - (tester.getTopLeft(card).dy - 100));
    await tester.pump();
    expect(find.text("Show less").hitTestable(), findsOneWidget);

    await toggleHolding(tester: tester, edge: () => tester.getTopLeft(card));
    expect(tester.getSize(card).height, moreOrLessEquals(collapsed, epsilon: 0.5));
  });

  testWidgets("Show less below a top scrolled away keeps the toggle under the finger", (tester) async {
    final controller = await pumpCardInList(tester: tester);
    final collapsed = tester.getSize(card).height;
    await toggleHolding(tester: tester, edge: () => tester.getTopLeft(card));

    // Scrolls down to Show less, as a reader does, taking the card's top off screen.
    controller.jumpTo(controller.offset - (tester.getTopLeft(toggle).dy - 400));
    await tester.pump();
    expect(tester.getTopLeft(card).dy, lessThan(0));

    await toggleHolding(tester: tester, edge: () => tester.getBottomLeft(card));
    expect(tester.getSize(card).height, moreOrLessEquals(collapsed, epsilon: 0.5));
    expect(tester.getTopLeft(card).dy, greaterThan(0));
  });

  testWidgets("a transcript shorter than the screen still holds the card's top as it grows", (tester) async {
    final reserve = ValueNotifier<double>(0);
    addTearDown(reserve.dispose);
    await tester.pumpWidget(
      _app(
        child: TranscriptTopReserve(
          extent: reserve,
          child: ValueListenableBuilder(
            valueListenable: reserve,
            builder: (context, room, _) => ListView(
              reverse: true,
              // The phone's physics, which spring back from past the end.
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(top: room),
              children: [
                const SizedBox(height: 60, child: Text("reply")),
                HandoffCard(messageId: "card", card: _card),
                const SizedBox(height: 60, child: Text("prompt")),
              ],
            ),
          ),
        ),
      ),
    );
    final prompt = tester.getTopLeft(find.text("prompt")).dy;
    expect(prompt, greaterThan(0));

    final top = tester.getTopLeft(card).dy;
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    await tester.tap(toggle);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(card).dy, moreOrLessEquals(top, epsilon: 0.5));
      // A hold past the end would spring back, and the spring fight the hold.
      expect(position.isScrollingNotifier.value, isFalse);
    }
    expect(tester.getTopLeft(find.text("prompt")).dy, prompt);
    expect(tester.getSize(card).height, greaterThan(600));
    // Once grown, only the room on screen stays: none to scroll into above.
    expect(position.maxScrollExtent - position.pixels, lessThanOrEqualTo(1));
  });

  testWidgets("a summary that fits shows whole, without Show all", (tester) async {
    await tester.pumpWidget(
      _app(
        child: const HandoffCard(
          messageId: "card",
          card: TranscriptHandoffCard(
            sourceSessionId: "source",
            sourceTitle: null,
            summary: "One short decision.",
            transcriptPath: "/tmp/handoff/transcript.md",
          ),
        ),
      ),
    );
    expect(find.text("From another session"), findsOneWidget);
    expect(find.text("One short decision.", findRichText: true), findsOneWidget);
    // The toggle is built but neither laid out in the card nor reachable.
    expect(find.text("Show all").hitTestable(), findsNothing);
    expect(find.text("/tmp/handoff/transcript.md"), findsOneWidget);
  });
}
