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

  test("binds the returned turn to its exact pending invocation", () {
    final tracker = CodexCommandInvocationTracker()
      ..register(
        threadId: "thread-1",
        invocationId: "first",
        command: "plan",
        arguments: "first",
      )
      ..register(
        threadId: "thread-1",
        invocationId: "second",
        command: "plan",
        arguments: "second",
      );

    final bound = tracker.bindReturnedTurn(
      threadId: "thread-1",
      invocationId: "second",
      turnId: "second-turn",
    );

    expect(bound?.invocationId, "second");
    expect(bound?.turnId, "second-turn");
    expect(tracker.pendingForThread(threadId: "thread-1")?.invocationId, "first");
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
