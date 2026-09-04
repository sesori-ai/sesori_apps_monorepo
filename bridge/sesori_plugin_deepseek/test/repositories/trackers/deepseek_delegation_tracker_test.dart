import "package:deepseek_plugin/deepseek_testing.dart";
import "package:test/test.dart";

Matcher _found({required String sessionId}) =>
    isA<DeepSeekDelegationFound>().having((lookup) => lookup.sessionId, "sessionId", sessionId);

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
      expect(tracker.lookupToolCallId(toolCallId: "call"), _found(sessionId: "root"));

      if (childEndsFirst) {
        tracker.markToolTerminal(parentSessionId: "root", toolCallId: "call");
      } else {
        tracker.markChildEnded(childSessionId: "child");
      }
      expect(tracker.isStarted(parentSessionId: "root", toolCallId: "call"), isFalse);
      expect(tracker.lookupToolCallId(toolCallId: "call"), isA<DeepSeekDelegationNotFound>());
    }
  });

  test("forget and clear remove both correlation indexes", () {
    final tracker = DeepSeekDelegationTracker()
      ..start(parentSessionId: "root", toolCallId: "call-1", childSessionId: "child-1")
      ..start(parentSessionId: "child-1", toolCallId: "call-2", childSessionId: "child-2");

    tracker.forgetSession(sessionId: "child-2");
    expect(tracker.lookupToolCallId(toolCallId: "call-2"), isA<DeepSeekDelegationNotFound>());
    expect(tracker.lookupToolCallId(toolCallId: "call-1"), _found(sessionId: "root"));

    tracker.forgetSession(sessionId: "root");
    expect(tracker.lookupToolCallId(toolCallId: "call-1"), isA<DeepSeekDelegationNotFound>());

    tracker.start(parentSessionId: "root", toolCallId: "call-3", childSessionId: "child-3");
    tracker.clear();
    expect(tracker.lookupToolCallId(toolCallId: "call-3"), isA<DeepSeekDelegationNotFound>());
  });

  test("a tool call id active in two sessions is ambiguous", () {
    final tracker = DeepSeekDelegationTracker()
      ..start(parentSessionId: "root-1", toolCallId: "shared", childSessionId: "child-1")
      ..start(parentSessionId: "root-2", toolCallId: "shared", childSessionId: "child-2");

    expect(tracker.lookupToolCallId(toolCallId: "shared"), isA<DeepSeekDelegationAmbiguous>());
  });
}
