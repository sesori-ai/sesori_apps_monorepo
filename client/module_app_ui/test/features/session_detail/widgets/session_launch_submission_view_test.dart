import "dart:typed_data";

import "package:clock/clock.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/queued_message_bubble.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_launch_submission_view.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required NewSessionSubmissionSnapshot submission,
  required double? transcriptWidth,
  DateTime? sendingSince,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Every host fills a pane with it, as the session transcript does.
      home: Scaffold(
        body: SizedBox.expand(
          child: PregoTopBarInsetScope(
            baseInset: 0,
            bannerHeight: const AlwaysStoppedAnimation<double>(0),
            child: SessionLaunchSubmissionView(
              submission: submission,
              harnessName: "Claude",
              transcriptWidth: transcriptWidth,
              sendingSince: sendingSince,
            ),
          ),
        ),
      ),
    ),
  );
  return AppLocalizations.of(tester.element(find.byType(SessionLaunchSubmissionView)))!;
}

ComposerAttachment _attachment(String filename) =>
    ComposerAttachment(mime: "image/png", bytes: Uint8List.fromList(const [1, 2, 3]), filename: filename);

void main() {
  testWidgets("shows a prompt and its images as a sending bubble from the first frame", (tester) async {
    final loc = await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Fix the login bug"),
        attachments: [_attachment("a.png"), _attachment("b.png")],
      ),
      transcriptWidth: null,
    );

    final bubble = find.byType(QueuedMessageBubble);
    expect(bubble, findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.text("Fix the login bug")), findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.byType(Image)), findsNWidgets(2));
    expect(find.text(loc.sessionDetailSendingMessage), findsOneWidget);

    // A slow creation names the harness, as an existing session's send does.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(loc.sessionDetailSendingToHarness("Claude")), findsOneWidget);
  });

  testWidgets("a send already past two seconds names the harness on its first frame", (tester) async {
    final loc = await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Hi"),
        attachments: const [],
      ),
      transcriptWidth: null,
      sendingSince: clock.now().subtract(const Duration(seconds: 3)),
    );

    expect(find.text(loc.sessionDetailSendingToHarness("Claude")), findsOneWidget);
  });

  testWidgets("a send under two seconds old names the harness when it reaches two seconds", (tester) async {
    final loc = await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Hi"),
        attachments: const [],
      ),
      transcriptWidth: null,
      sendingSince: clock.now().subtract(const Duration(milliseconds: 1500)),
    );
    expect(find.text(loc.sessionDetailSendingMessage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(loc.sessionDetailSendingToHarness("Claude")), findsOneWidget);
  });

  testWidgets("shows a command with its arguments", (tester) async {
    await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.command(
        draft: ComposerDraft.typed(text: "the diff"),
        command: "review",
      ),
      transcriptWidth: null,
    );

    final bubble = tester.widget<QueuedMessageBubble>(find.byType(QueuedMessageBubble));
    expect(bubble.displayText, "/review the diff");
    expect(bubble.isCommand, isTrue);
  });

  testWidgets("shows only the images of an attachment-only prompt", (tester) async {
    await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: ""),
        attachments: [_attachment("a.png")],
      ),
      transcriptWidth: null,
    );

    final bubble = tester.widget<QueuedMessageBubble>(find.byType(QueuedMessageBubble));
    expect(bubble.displayText, isNull);
    expect(bubble.attachmentCount, 1);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets("rests on the transcript's newest-row position inside its reading column", (tester) async {
    await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Hi"),
        attachments: const [],
      ),
      transcriptWidth: 400,
    );

    // The transcript centres a 400 px column in the 800 px pane and pads its
    // newest row 8 px above the bottom edge.
    final rect = tester.getRect(find.byType(QueuedMessageBubble));
    expect(rect.left, 200);
    expect(rect.right, 600);
    expect(rect.bottom, 600 - 8);
  });
}
