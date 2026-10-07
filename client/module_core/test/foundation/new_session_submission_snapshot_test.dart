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
}
