import "dart:typed_data";

import "package:clock/clock.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/queued_message_bubble.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/sent_bubble_landing.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_launch_submission_view.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required NewSessionSubmissionSnapshot submission,
  required double? transcriptWidth,
  DateTime? sendingSince,
  List<QueuedSessionSubmission> awaitingBridgeSubmissions = const [],
  List<LaunchFollowUp> launchFollowUps = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => SentBubbleLanding(child: child ?? const SizedBox.shrink()),
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
              awaitingBridgeSubmissions: awaitingBridgeSubmissions,
              launchFollowUps: launchFollowUps,
              queuedMessages: const [],
              onRetryLaunchFollowUp: null,
              onRemoveLaunchFollowUp: null,
              onCancelQueuedMessage: null,
              bottomInset: null,
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
    expect(find.text(loc.sessionDetailSendingMessage), findsNothing);

    // A slow creation names the harness, as an existing session's send does.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(loc.sessionDetailSendingToHarness("Claude")), findsOneWidget);
  });

  testWidgets("its bubble is the one a sent dictation lands on", (tester) async {
    late SentBubbleLandingController landing;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SentBubbleLanding(
          child: Builder(
            builder: (context) {
              landing = SentBubbleLanding.of(context: context)..expect();
              return Scaffold(
                body: PregoTopBarInsetScope(
                  baseInset: 0,
                  bannerHeight: const AlwaysStoppedAnimation<double>(0),
                  child: SessionLaunchSubmissionView(
                    submission: NewSessionSubmissionSnapshot.text(
                      draft: ComposerDraft.typed(text: "Dictated"),
                      attachments: const [],
                    ),
                    harnessName: "Claude",
                    transcriptWidth: null,
                    sendingSince: null,
                    awaitingBridgeSubmissions: const [],
                    launchFollowUps: const [],
                    queuedMessages: const [],
                    onRetryLaunchFollowUp: null,
                    onRemoveLaunchFollowUp: null,
                    onCancelQueuedMessage: null,
                    bottomInset: null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(landing.heldText, "Dictated");
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
    expect(find.text(loc.sessionDetailSendingToHarness("Claude")), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(loc.sessionDetailSendingToHarness("Claude")), findsOneWidget);
  });

  testWidgets("a message accepted but not yet listed reads as still sending, not as queued", (tester) async {
    QueuedSessionSubmission submission({required String promptId}) => QueuedSessionSubmission.text(
      promptId: promptId,
      text: promptId,
      inputMode: ComposerInputMode.typed,
      attachments: const [],
      agent: null,
      agentModel: null,
      fastMode: false,
    );
    final loc = await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Hi"),
        attachments: const [],
      ),
      transcriptWidth: null,
      awaitingBridgeSubmissions: [submission(promptId: "parked")],
      launchFollowUps: [LaunchFollowUp.accepted(submission: submission(promptId: "accepted"))],
    );
    expect(find.byType(QueuedMessageBubble), findsNWidgets(3));
    expect(find.text(loc.sessionDetailQueuedMessage), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(loc.sessionDetailSendingToHarness("Claude")), findsNWidgets(3));
  });

  testWidgets("a follow-up waiting its turn shows Queued only two seconds after it was sent", (tester) async {
    final loc = await _pump(
      tester,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Hi"),
        attachments: const [],
      ),
      transcriptWidth: null,
      launchFollowUps: [
        LaunchFollowUp.queued(
          submission: const QueuedSessionSubmission.text(
            promptId: "prm_follow_up",
            text: "and then",
            inputMode: ComposerInputMode.typed,
            attachments: [],
            agent: null,
            agentModel: null,
            fastMode: false,
          ),
          since: clock.now().subtract(const Duration(milliseconds: 1500)),
        ),
      ],
    );
    expect(find.text(loc.sessionDetailQueuedMessage), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(loc.sessionDetailQueuedMessage), findsOneWidget);
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
