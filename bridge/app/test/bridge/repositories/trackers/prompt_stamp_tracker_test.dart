import "package:sesori_bridge/src/repositories/trackers/prompt_stamp.dart";
import "package:sesori_bridge/src/repositories/trackers/prompt_stamp_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  PromptStamp command({required String name}) => PromptStampCommand(
    invocation: CommandInvocation(name: name, source: CommandSource.command, arguments: null),
  );

  String? nameOf(PromptStamp? stamp) => switch (stamp) {
    PromptStampCommand(:final invocation) => invocation.name,
    PromptStampHandoff() || null => null,
  };

  test("stamps a recorded prompt only in its own session", () {
    final tracker = PromptStampTracker()
      ..record(
        sessionId: "s1",
        promptId: "p1",
        stamp: command(name: "review"),
      );

    expect(nameOf(tracker.stampFor(sessionId: "s1", promptId: "p1")), "review");
    expect(tracker.stampFor(sessionId: "s2", promptId: "p1"), isNull);
    expect(tracker.stampFor(sessionId: "s1", promptId: "p2"), isNull);
  });

  test("evicts the oldest entry past capacity, counting a re-record as new", () {
    final tracker = PromptStampTracker();
    for (var index = 0; index < PromptStampTracker.capacity; index++) {
      tracker.record(
        sessionId: "s",
        promptId: "p$index",
        stamp: command(name: "c$index"),
      );
    }
    tracker
      ..record(
        sessionId: "s",
        promptId: "p0",
        stamp: command(name: "again"),
      )
      ..record(
        sessionId: "s",
        promptId: "overflow",
        stamp: command(name: "new"),
      );

    expect(nameOf(tracker.stampFor(sessionId: "s", promptId: "p0")), "again");
    expect(tracker.stampFor(sessionId: "s", promptId: "p1"), isNull);
    expect(nameOf(tracker.stampFor(sessionId: "s", promptId: "overflow")), "new");
  });
}
