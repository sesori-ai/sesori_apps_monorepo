import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final image = ComposerAttachment(mime: "image/png", bytes: Uint8List.fromList([1]), filename: "a.png");
  QueuedSessionSubmission text({required List<ComposerAttachment> attachments}) => QueuedSessionSubmission.text(
    promptId: "prm_a",
    text: "then this",
    inputMode: ComposerInputMode.typed,
    attachments: attachments,
    agent: null,
    agentModel: null,
    fastMode: false,
  );
  final command = NewSessionSubmissionSnapshot.command(
    draft: ComposerDraft.typed(text: "src"),
    command: "review",
  );

  test("a command keeps its intent when its follow-ups carry no images", () {
    expect(
      command.withFollowUps(followUps: [text(attachments: const [])], unsent: null),
      NewSessionSubmissionSnapshot.command(
        draft: ComposerDraft.typed(text: "src\n\nthen this"),
        command: "review",
      ),
    );
  });

  test("a command followed by images is restored as text so the images are not dropped", () {
    final restored = command.withFollowUps(
      followUps: [
        text(attachments: [image]),
      ],
      unsent: null,
    );

    expect(restored, isA<NewSessionTextSubmissionSnapshot>());
    expect(restored.draft.text, "/review src\n\nthen this");
    expect((restored as NewSessionTextSubmissionSnapshot).attachments, [same(image)]);
  });

  test("what the composer still held is appended after the follow-ups", () {
    final restored =
        NewSessionSubmissionSnapshot.text(
          draft: ComposerDraft.typed(text: "first"),
          attachments: const [],
        ).withFollowUps(
          followUps: [text(attachments: const [])],
          unsent: UnsentComposer(
            draft: ComposerDraft.typed(text: " half typed "),
            selection: null,
            command: const CommandInfo(
              name: "fix",
              template: null,
              hints: null,
              description: null,
              agent: null,
              model: null,
              provider: null,
              source: null,
              subtask: null,
            ),
            attachments: [image],
          ),
        );

    expect(restored.draft.text, "first\n\nthen this\n\n/fix half typed");
    expect((restored as NewSessionTextSubmissionSnapshot).attachments, [same(image)]);
  });

  test("no follow-ups restores the submission itself", () {
    expect(command.withFollowUps(followUps: const [], unsent: null), same(command));
  });

  group("dictation marker", () {
    final dictated = ComposerDraft(
      text: "fix the parser",
      voiceSpans: [VoiceOriginSpan(start: 0, end: 3)],
    );

    test("dictated text is marked for the agent and the bubble, and stays plain for the box", () {
      final submission = NewSessionSubmissionSnapshot.text(draft: dictated, attachments: const []);

      expect(submission.outgoingText, wrapDictatedText(text: "fix the parser"));
      expect(submission.displayText, wrapDictatedText(text: "fix the parser"));
      expect(submission.plainText, "fix the parser");
    });

    test("typed text is never marked", () {
      final submission = NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "fix the parser"),
        attachments: const [],
      );

      expect(submission.outgoingText, "fix the parser");
      expect(submission.displayText, "fix the parser");
      expect(submission.plainText, "fix the parser");
    });

    test("a dictated argument to a command is never marked", () {
      final submission = NewSessionSubmissionSnapshot.command(draft: dictated, command: "review");

      expect(submission.outgoingText, "fix the parser");
      expect(submission.displayText, "/review fix the parser");
      expect(submission.plainText, "/review fix the parser");
    });

    test("an attachment-only prompt has no text to show", () {
      final submission = NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: ""),
        attachments: [image],
      );

      expect(submission.displayText, isNull);
      expect(submission.plainText, isNull);
    });

    test("a restored draft holds plain words for dictated submissions and follow-ups", () {
      final restored = NewSessionSubmissionSnapshot.text(draft: dictated, attachments: const []).withFollowUps(
        followUps: [
          const QueuedSessionSubmission.text(
            promptId: "prm_a",
            text: "and the tests",
            inputMode: ComposerInputMode.voiceAssisted,
            attachments: [],
            agent: null,
            agentModel: null,
            fastMode: false,
          ),
          const QueuedSessionSubmission.command(
            promptId: "prm_b",
            text: "src",
            command: "review",
            agent: null,
            agentModel: null,
            fastMode: false,
          ),
        ],
        unsent: null,
      );

      expect(restored.draft.text, "fix the parser\n\nand the tests\n\n/review src");
    });

    test("a dictated follow-up keeps a typed first message marked when it is sent again", () {
      final restored =
          NewSessionSubmissionSnapshot.text(
            draft: ComposerDraft.typed(text: "fix the parser"),
            attachments: const [],
          ).withFollowUps(
            followUps: [
              const QueuedSessionSubmission.text(
                promptId: "prm_a",
                text: "and the tests",
                inputMode: ComposerInputMode.voiceAssisted,
                attachments: [],
                agent: null,
                agentModel: null,
                fastMode: false,
              ),
            ],
            unsent: null,
          );

      expect(restored.draft.voiceSpans, [VoiceOriginSpan(start: 16, end: 29)]);
      expect(restored.outgoingText, wrapDictatedText(text: "fix the parser\n\nand the tests"));
    });

    test("an empty dictated prompt carries no marker", () {
      const submission = QueuedSessionSubmission.text(
        promptId: "prm_a",
        text: "",
        inputMode: ComposerInputMode.voiceAssisted,
        attachments: [],
        agent: null,
        agentModel: null,
        fastMode: false,
      );

      expect(submission.outgoingText, "");
      expect(submission.displayText, isNull);
    });
  });
}
