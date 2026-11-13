import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/cubits/session_detail/prompt_turn_shape_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const calculator = PromptTurnShapeCalculator();

  MessageUser user({required CommandInvocation? invocation}) => MessageUser(
    id: "m1",
    sessionID: "s1",
    agent: null,
    time: null,
    promptId: null,
    invocation: invocation,
  );

  QueuedSessionSubmission command({required CommandSource? source, required String text}) =>
      QueuedSessionSubmission.command(
        promptId: "p1",
        text: text,
        command: "fixture-greeter",
        commandSource: source,
        agent: null,
        agentModel: null,
        fastMode: false,
      );

  group("ofMessage", () {
    test("is a card exactly when the bridge named the invocation", () {
      expect(
        calculator.ofMessage(
          message: user(
            invocation: const CommandInvocation(name: "review", source: CommandSource.skill, arguments: "two\nlines"),
          ),
        ),
        const PromptTurnShape.invocation(name: "review", source: CommandSource.skill, arguments: "two\nlines"),
      );
      expect(calculator.ofMessage(message: user(invocation: null)), const PromptTurnShape.bubble());
    });
  });

  group("ofSubmission", () {
    test("is a card for a sourced command when the plugin names invocations", () {
      expect(
        calculator.ofSubmission(
          submission: command(source: CommandSource.mcp, text: "  hi  "),
          namesCommandInvocations: true,
        ),
        const PromptTurnShape.invocation(name: "fixture-greeter", source: CommandSource.mcp, arguments: "hi"),
      );
    });

    test("has no arguments for blank text", () {
      expect(
        calculator.ofSubmission(
          submission: command(source: CommandSource.command, text: "   "),
          namesCommandInvocations: true,
        ),
        const PromptTurnShape.invocation(name: "fixture-greeter", source: CommandSource.command, arguments: null),
      );
    });

    test("is a bubble without the capability, a source, or a command", () {
      expect(
        calculator.ofSubmission(
          submission: command(source: CommandSource.skill, text: "x"),
          namesCommandInvocations: false,
        ),
        const PromptTurnShape.bubble(),
      );
      expect(
        calculator.ofSubmission(submission: command(source: null, text: "x"), namesCommandInvocations: true),
        const PromptTurnShape.bubble(),
      );
      expect(
        calculator.ofSubmission(
          submission: const QueuedSessionSubmission.text(
            promptId: "p2",
            text: "/fixture-greeter looks like a command",
            inputMode: ComposerInputMode.typed,
            attachments: [],
            agent: null,
            agentModel: null,
            fastMode: false,
          ),
          namesCommandInvocations: true,
        ),
        const PromptTurnShape.bubble(),
      );
    });
  });

  test("ofQueuedPrompt follows the same rule as a local submission", () {
    const prompt = QueuedSessionPrompt(
      id: "q1",
      text: "args",
      command: "fixture-greeter",
      commandSource: CommandSource.skill,
      createdAt: 0,
    );
    expect(
      calculator.ofQueuedPrompt(prompt: prompt, namesCommandInvocations: true),
      const PromptTurnShape.invocation(name: "fixture-greeter", source: CommandSource.skill, arguments: "args"),
    );
    expect(calculator.ofQueuedPrompt(prompt: prompt, namesCommandInvocations: false), const PromptTurnShape.bubble());
  });

  test("shapes lists only invocations, by message and prompt id", () {
    final shapes = calculator.shapes(
      namesCommandInvocations: true,
      launch: NewSessionSubmissionSnapshot.command(
        draft: ComposerDraft.typed(text: ""),
        command: "fixture-greeter",
        commandSource: CommandSource.command,
      ),
      messages: [
        MessageWithParts(
          info: user(
            invocation: const CommandInvocation(name: "review", source: CommandSource.skill, arguments: null),
          ),
          parts: const [],
        ),
      ],
      bridgeQueuedPrompts: const [],
      submissions: [command(source: CommandSource.mcp, text: "")],
    );
    expect(
      shapes.launch,
      const PromptTurnShape.invocation(name: "fixture-greeter", source: CommandSource.command, arguments: null),
    );
    expect(
      shapes.ofMessage(messageId: "m1"),
      const PromptTurnShape.invocation(name: "review", source: CommandSource.skill, arguments: null),
    );
    expect(
      shapes.ofPrompt(promptId: "p1"),
      const PromptTurnShape.invocation(name: "fixture-greeter", source: CommandSource.mcp, arguments: null),
    );
    expect(shapes.ofPrompt(promptId: "unknown"), const PromptTurnShape.bubble());
  });
}
