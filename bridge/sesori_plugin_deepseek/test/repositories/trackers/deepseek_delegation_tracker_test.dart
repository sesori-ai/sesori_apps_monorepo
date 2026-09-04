import "package:deepseek_plugin/deepseek_testing.dart";
import "package:test/test.dart";

void main() {
  test("correlation remains until child and standard tool lifecycles are terminal", () {
    for (final childEndsFirst in [true, false]) {
      final tracker = DeepSeekDelegationTracker()
        ..start(parentSessionId: "root", toolCallId: "call", childSessionId: "child");

      if (childEndsFirst) {
        tracker.markChildEnded(childSessionId: "child");
      } else {
        tracker.markToolTerminal(parentSessionId: "root", toolCallId: "call");
      }
      expect(tracker.isStarted(parentSessionId: "root", toolCallId: "call"), isTrue);
      expect(tracker.sessionIdForToolCallId(toolCallId: "call"), "root");

      if (childEndsFirst) {
        tracker.markToolTerminal(parentSessionId: "root", toolCallId: "call");
      } else {
        tracker.markChildEnded(childSessionId: "child");
      }
      expect(tracker.isStarted(parentSessionId: "root", toolCallId: "call"), isFalse);
      expect(tracker.sessionIdForToolCallId(toolCallId: "call"), isNull);
    }
  });

  test("forget and clear remove both correlation indexes", () {
    final tracker = DeepSeekDelegationTracker()
      ..start(parentSessionId: "root", toolCallId: "call-1", childSessionId: "child-1")
      ..start(parentSessionId: "child-1", toolCallId: "call-2", childSessionId: "child-2");

    tracker.forgetSession(sessionId: "child-2");
    expect(tracker.sessionIdForToolCallId(toolCallId: "call-2"), isNull);
    expect(tracker.sessionIdForToolCallId(toolCallId: "call-1"), "root");

    tracker.forgetSession(sessionId: "root");
    expect(tracker.sessionIdForToolCallId(toolCallId: "call-1"), isNull);

    tracker.start(parentSessionId: "root", toolCallId: "call-3", childSessionId: "child-3");
    tracker.clear();
    expect(tracker.sessionIdForToolCallId(toolCallId: "call-3"), isNull);
  });
}
