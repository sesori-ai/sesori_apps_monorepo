import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  QueuedSessionSubmission text({required String text, required ComposerInputMode inputMode}) =>
      QueuedSessionSubmission.text(
        promptId: "prm_a",
        text: text,
        inputMode: inputMode,
        attachments: const [],
        agent: null,
        agentModel: null,
        fastMode: false,
      );

  test("dictated text is marked for the agent and the bubble, and stays plain for the box", () {
    final submission = text(text: "fix the parser", inputMode: ComposerInputMode.voiceAssisted);

    expect(submission.outgoingText, wrapDictatedText(text: "fix the parser"));
    expect(submission.displayText, wrapDictatedText(text: "fix the parser"));
    expect(submission.plainText, "fix the parser");
    expect(submission.text, "fix the parser");
  });

  test("a voice-assisted submission keeps its mark after a selection change", () {
    final submission = text(
      text: "fix the parser",
      inputMode: ComposerInputMode.voiceAssisted,
    ).withSelection(agent: "build", agentModel: null, fastMode: true);

    expect(submission.outgoingText, wrapDictatedText(text: "fix the parser"));
  });

  test("typed text is never marked", () {
    final submission = text(text: "fix the parser", inputMode: ComposerInputMode.typed);

    expect(submission.outgoingText, "fix the parser");
    expect(submission.displayText, "fix the parser");
    expect(submission.plainText, "fix the parser");
  });

  test("an attachment-only prompt has no text to show", () {
    final submission = text(text: "", inputMode: ComposerInputMode.typed);

    expect(submission.displayText, isNull);
    expect(submission.plainText, isNull);
  });

  group("commands are never marked", () {
    final variants = <String, QueuedSessionSubmission Function({required String text})>{
      "queued": ({required text}) => QueuedSessionSubmission.command(
        promptId: "prm_a",
        text: text,
        command: "review",
        agent: null,
        agentModel: null,
        fastMode: false,
      ),
      "unavailable": ({required text}) => QueuedSessionSubmission.unavailableCommand(
        promptId: "prm_a",
        text: text,
        command: "review",
        agent: null,
        agentModel: null,
        fastMode: false,
      ),
    };

    variants.forEach((name, command) {
      test("$name, with arguments", () {
        final submission = command(text: " src ");

        expect(submission.outgoingText, " src ");
        expect(submission.displayText, "/review src");
        expect(submission.plainText, "/review src");
      });

      test("$name, without arguments", () {
        final submission = command(text: "");

        expect(submission.outgoingText, "");
        expect(submission.displayText, "/review");
        expect(submission.plainText, "/review");
      });
    });
  });
}
