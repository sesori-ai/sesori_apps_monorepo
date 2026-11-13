import "package:sesori_bridge/src/repositories/trackers/command_invocation_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  CommandInvocation invocation({required String name}) =>
      CommandInvocation(name: name, source: CommandSource.command, arguments: null);

  test("names a recorded prompt only in its own session", () {
    final tracker = CommandInvocationTracker()
      ..record(
        sessionId: "s1",
        promptId: "p1",
        invocation: invocation(name: "review"),
      );

    expect(tracker.invocationFor(sessionId: "s1", promptId: "p1"), invocation(name: "review"));
    expect(tracker.invocationFor(sessionId: "s2", promptId: "p1"), isNull);
    expect(tracker.invocationFor(sessionId: "s1", promptId: "p2"), isNull);
  });

  test("evicts the oldest entry past capacity, counting a re-record as new", () {
    final tracker = CommandInvocationTracker();
    for (var index = 0; index < CommandInvocationTracker.capacity; index++) {
      tracker.record(
        sessionId: "s",
        promptId: "p$index",
        invocation: invocation(name: "c$index"),
      );
    }
    tracker
      ..record(
        sessionId: "s",
        promptId: "p0",
        invocation: invocation(name: "again"),
      )
      ..record(
        sessionId: "s",
        promptId: "overflow",
        invocation: invocation(name: "new"),
      );

    expect(tracker.invocationFor(sessionId: "s", promptId: "p0"), invocation(name: "again"));
    expect(tracker.invocationFor(sessionId: "s", promptId: "p1"), isNull);
    expect(tracker.invocationFor(sessionId: "s", promptId: "overflow"), invocation(name: "new"));
  });
}
