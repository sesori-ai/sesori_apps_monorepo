import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("keeps one running compaction per session until it finishes or is forgotten", () {
    final tracker = DeepSeekCompactionTracker(clock: const ServerClock());

    final first = tracker.start(sessionId: "one");
    final other = tracker.start(sessionId: "two");

    expect(tracker.start(sessionId: "one"), first);
    expect(first.messageId, "one-compaction-${first.startedAtMs}");
    expect(other.messageId, startsWith("two-compaction-"));
    expect(tracker.finish(sessionId: "one"), first);
    expect(tracker.finish(sessionId: "one"), isNull);

    tracker.forgetSession(sessionId: "two");
    expect(tracker.finish(sessionId: "two"), isNull);

    tracker
      ..start(sessionId: "one")
      ..clear();
    expect(tracker.finish(sessionId: "one"), isNull);
  });
}
