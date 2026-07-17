import "package:codex_plugin/codex_plugin.dart";
import "package:test/test.dart";

void main() {
  test("tracks pending and active command identity in immutable snapshots", () {
    final tracker = CodexCommandInvocationTracker();
    final pending = tracker.register(
      threadId: "thread-1",
      invocationId: "opaque-invocation",
      command: "/plan",
      arguments: "auth",
    );

    expect(pending.phase, CodexCommandInvocationPhase.pending);
    expect(pending.invocationId, "opaque-invocation");
    expect(pending.expectedUserText, "/plan auth");

    tracker.bindReturnedTurn(
      threadId: "thread-1",
      invocationId: "opaque-invocation",
      turnId: "turn-1",
    );
    tracker.replaceResultText(
      turnId: "turn-1",
      messageId: "result-1",
      text: "first",
    );
    final active = tracker.recordResultPart(
      turnId: "turn-1",
      messageId: "result-1",
      partId: "result-1-tool",
    )!;

    expect(active.commandMessageId, "turn-1");
    expect(active.resultMessageId, "result-1");
    expect(active.resultText, "first");
    expect(active.resultPartIds["result-1"], {"result-1-tool"});
    expect(
      () => active.resultPartIds["result-1"]!.add("mutate"),
      throwsUnsupportedError,
    );
  });

  test("rejection removes a pending invocation", () {
    final tracker = CodexCommandInvocationTracker()
      ..register(
        threadId: "thread-1",
        invocationId: "rejected",
        command: "plan",
        arguments: "",
      );

    tracker.reject(threadId: "thread-1", invocationId: "rejected");

    expect(tracker.pendingForThread(threadId: "thread-1"), isNull);
    expect(
      tracker.bindReturnedTurn(
        threadId: "thread-1",
        invocationId: "rejected",
        turnId: "later-turn",
      ),
      isNull,
    );
  });

  test("rejects a second pending command and preserves the first", () {
    final tracker = CodexCommandInvocationTracker()
      ..register(
        threadId: "thread-1",
        invocationId: "first",
        command: "plan",
        arguments: "first",
      );

    expect(
      () => tracker.register(
        threadId: "thread-1",
        invocationId: "second",
        command: "review",
        arguments: "second",
      ),
      throwsA(isA<CodexCommandAlreadyOutstandingException>()),
    );

    expect(tracker.pendingForThread(threadId: "thread-1")?.invocationId, "first");
    final bound = tracker.bindReturnedTurn(
      threadId: "thread-1",
      invocationId: "first",
      turnId: "first-turn",
    );
    expect(bound?.invocationId, "first");
    expect(bound?.turnId, "first-turn");
  });

  test("rejects a second command while the first is active", () {
    final tracker = CodexCommandInvocationTracker()
      ..register(
        threadId: "thread-1",
        invocationId: "first",
        command: "plan",
        arguments: "first",
      )
      ..bindReturnedTurn(
        threadId: "thread-1",
        invocationId: "first",
        turnId: "first-turn",
      );

    expect(
      () => tracker.register(
        threadId: "thread-1",
        invocationId: "second",
        command: "review",
        arguments: "second",
      ),
      throwsA(isA<CodexCommandAlreadyOutstandingException>()),
    );

    expect(
      tracker.activeFor(threadId: "thread-1", turnId: "first-turn")?.invocationId,
      "first",
    );
  });

  test("reset clears pending and active invocation indexes", () {
    final tracker = CodexCommandInvocationTracker()
      ..register(
        threadId: "pending-thread",
        invocationId: "pending-invocation",
        command: "plan",
        arguments: "",
      )
      ..register(
        threadId: "active-thread",
        invocationId: "active-invocation",
        command: "review",
        arguments: "",
      )
      ..bindReturnedTurn(
        threadId: "active-thread",
        invocationId: "active-invocation",
        turnId: "active-turn",
      );

    tracker.reset();

    expect(tracker.pendingForThread(threadId: "pending-thread"), isNull);
    expect(
      tracker.activeFor(threadId: "active-thread", turnId: null),
      isNull,
    );
    expect(
      tracker.activeFor(threadId: "active-thread", turnId: "active-turn"),
      isNull,
    );
    expect(
      () => tracker.register(
        threadId: "active-thread",
        invocationId: "replacement-invocation",
        command: "review",
        arguments: "",
      ),
      returnsNormally,
    );
  });

  test("reset preserves the synthetic message sequence", () {
    final tracker = CodexCommandInvocationTracker();
    final beforeReset = tracker.register(
      threadId: "thread-1",
      invocationId: "first",
      command: "plan",
      arguments: "",
    );

    tracker.reset();
    final afterReset = tracker.register(
      threadId: "thread-1",
      invocationId: "second",
      command: "review",
      arguments: "",
    );

    expect(beforeReset.commandMessageId, "codex-command-0");
    expect(afterReset.commandMessageId, "codex-command-1");
  });

  test("removing one result part keeps later item cleanup idempotent", () {
    final tracker = CodexCommandInvocationTracker()
      ..register(
        threadId: "thread-1",
        invocationId: "invocation",
        command: "plan",
        arguments: "",
      )
      ..bindReturnedTurn(
        threadId: "thread-1",
        invocationId: "invocation",
        turnId: "turn-1",
      )
      ..recordResultPart(
        turnId: "turn-1",
        messageId: "result-1",
        partId: "result-1-tool",
      )
      ..recordResultPart(
        turnId: "turn-1",
        messageId: "result-1",
        partId: "result-1-reasoning",
      );

    tracker.removeResultPart(
      turnId: "turn-1",
      messageId: "result-1",
      partId: "result-1-tool",
    );
    final removed = tracker.removeResult(
      turnId: "turn-1",
      messageId: "result-1",
    );

    expect(removed?.partIds, {"result-1-reasoning"});
  });
}
