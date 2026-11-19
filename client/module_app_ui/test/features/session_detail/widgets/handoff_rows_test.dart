import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/handoff_card.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/handoff_marker_row.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

/// [child] on a session page, whose session links read [cubit] and land in
/// [opened].
Widget _app({
  required Widget child,
  required SessionDetailCubit cubit,
  required List<String> opened,
}) => MaterialApp.router(
  theme: buildPregoThemeData(brightness: Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (_, _) => BlocProvider<SessionDetailCubit>.value(
          value: cubit,
          child: SessionDetailPresentationScope(
            messageImageRepository: () => throw UnimplementedError(),
            imageSaver: () => throw UnimplementedError(),
            imageClipboard: () => throw UnimplementedError(),
            imageSharer: () => throw UnimplementedError(),
            sessionRepository: () => throw UnimplementedError("Prompt search is not under test"),
            createPendingPageCubit: ({required requestId, required sessionId}) =>
                throw StateError("Unused fixture page"),
            createPendingFormCubit: ({required requestId, required sessionId}) =>
                throw StateError("Unused fixture form"),
            createFilePreviewCubit: ({required reference}) =>
                throw UnimplementedError("File previews are not under test"),
            createExternalActionCubit: ({required requestId, required sessionId}) =>
                throw UnimplementedError("External actions are not under test"),
            canShareImages: false,
            openExternalLink: ({required url, required mode}) async => false,
            openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) =>
                opened.add(sessionId),
            openSideChat: null,
            returnToSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
            openHarnessSettings: () {},
            openBridgeSettings: () {},
            child: Scaffold(body: child),
          ),
        ),
      ),
    ],
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
  late _MockSessionDetailCubit cubit;
  late List<String> opened;

  setUp(() {
    cubit = _MockSessionDetailCubit();
    opened = [];
  });

  Widget app({required Widget child}) => _app(child: child, cubit: cubit, opened: opened);

  testWidgets("the marker keeps one height as the summary is written, then sent", (tester) async {
    final rowSizes = <Size>[];
    for (final status in TranscriptHandoffMarkerStatus.values) {
      await tester.pumpWidget(
        app(
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
      app(
        child: HandoffMarkerRow(marker: _marker(status: TranscriptHandoffMarkerStatus.writing, summary: null)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Writing a summary for Codex review…"), findsWidgets);
    expect(find.byKey(const ValueKey("handoff-marker.open")), findsNothing);

    await tester.pumpWidget(
      app(
        child: HandoffMarkerRow(
          marker: _marker(status: TranscriptHandoffMarkerStatus.sent, summary: "Done."),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Summary sent to Codex review"), findsOneWidget);
    expect(find.byKey(const ValueKey("handoff-marker.open")), findsOneWidget);

    await tester.pumpWidget(
      app(
        child: HandoffMarkerRow(marker: _marker(status: TranscriptHandoffMarkerStatus.notSent, summary: null)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Couldn't send to Codex review"), findsOneWidget);
    expect(find.byKey(const ValueKey("handoff-marker.open")), findsNothing);
  });
  final card = find.byType(HandoffCard);
  final showAll = find.byKey(const ValueKey("handoff-card.show-all"));
  const lastLine = "Decision 29 and the reason it holds.";

  /// The card among older and newer rows of a reversed transcript, as a
  /// session page lays it out.
  Widget transcript() => ListView(
    reverse: true,
    children: [
      for (var index = 0; index < 3; index++) SizedBox(height: 120, child: Text("newer $index")),
      HandoffCard(card: _card),
      for (var index = 0; index < 3; index++) SizedBox(height: 120, child: Text("older $index")),
    ],
  );

  testWidgets("Show all opens the whole summary in a sheet and leaves the card as it was", (tester) async {
    await tester.pumpWidget(app(child: transcript()));
    final before = tester.getRect(card);
    expect(find.text(lastLine, findRichText: true).hitTestable(), findsNothing);
    expect(tester.getSemantics(showAll), isSemantics(label: "Show all", isButton: true, hasTapAction: true));

    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(find.text("Handoff summary"), findsOneWidget);
    // The sheet scrolls to the end of the summary, just above the path.
    await tester.ensureVisible(find.text("/tmp/handoff/transcript.md").last);
    await tester.pumpAndSettle();
    expect(find.text(lastLine, findRichText: true).hitTestable(), findsOneWidget);
    expect(find.text("From Relay retries"), findsNWidgets(2));
    // The path stays selectable in the sheet, as on the card.
    expect(find.widgetWithText(SelectableText, "/tmp/handoff/transcript.md"), findsNWidgets(2));
    expect(tester.getRect(card), before);

    // A drag down closes the sheet, onto the card as it was.
    await tester.fling(find.text("Handoff summary"), const Offset(0, 600), 2000);
    await tester.pumpAndSettle();
    expect(find.text("Handoff summary"), findsNothing);
    expect(tester.getRect(card), before);
    expect(find.text("Show all").hitTestable(), findsOneWidget);
  });

  testWidgets("under a pointer the summary opens in a dialog that Esc closes", (tester) async {
    await tester.pumpWidget(
      PregoInteractionScope(
        mode: PregoInteractionMode.pointer,
        child: app(child: transcript()),
      ),
    );
    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text("Handoff summary"), findsOneWidget);
    // The card's clipped copy and the dialog's whole one.
    expect(find.text(lastLine, findRichText: true), findsNWidgets(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text("Handoff summary"), findsNothing);
  });

  testWidgets("the sheet's From link closes it and opens the source", (tester) async {
    when(() => cubit.linkedSession(sessionId: "source")).thenAnswer((_) async => testSession(id: "source"));
    await tester.pumpWidget(app(child: transcript()));
    await tester.tap(showAll);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("handoff-sheet.source")));
    await tester.pumpAndSettle();
    expect(find.text("Handoff summary"), findsNothing);
    expect(opened, ["source"]);
  });

  testWidgets("a summary that fits shows whole, without Show all", (tester) async {
    await tester.pumpWidget(
      app(
        child: const HandoffCard(
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
    // Show all is built but neither laid out in the card nor reachable.
    expect(find.text("Show all").hitTestable(), findsNothing);
    expect(find.text("/tmp/handoff/transcript.md"), findsOneWidget);
  });

  testWidgets(
    "a summary heading takes the app's type, not the platform's fallback",
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      await tester.pumpWidget(
        app(
          child: const HandoffCard(
            card: TranscriptHandoffCard(
              sourceSessionId: "source",
              sourceTitle: "Relay retries",
              summary: "## Next steps\n\nRetry the relay once.",
              transcriptPath: "/tmp/handoff/transcript.md",
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heading = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((text) => text.text)
          .firstWhere((span) => span.toPlainText() == "Next steps");
      final style = switch (heading) {
        TextSpan(:final children, :final style) => children?.whereType<TextSpan>().first.style ?? style,
        _ => null,
      };
      expect(style?.fontFamily, PregoTextTheme.fontFamily);
      expect(style?.fontSize, PregoTextTheme.light.textLg.bold.fontSize);
    },
  );
}
