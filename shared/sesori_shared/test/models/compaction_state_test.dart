import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const common = {"type": "compaction", "id": "part-1", "sessionID": "session-1", "messageID": "message-1"};
  const noDetails = CompactionState.completed(summary: null, freedTokens: null, trigger: null);

  test("a released bridge's state-less compaction part reads as completed with no details", () {
    final part = MessagePart.fromJson(common) as MessagePartCompaction;

    expect(part.state, noDetails);
  });

  final states = <String, CompactionState>{
    "running without text": const CompactionState.running(summary: null),
    "running with text": const CompactionState.running(summary: "## Goal"),
    "completed without details": noDetails,
    "completed with details": const CompactionState.completed(
      summary: "## Goal",
      freedTokens: 142000,
      trigger: CompactionTrigger.auto,
    ),
    "failed without a reason": const CompactionState.failed(reason: null),
    "failed with a reason": const CompactionState.failed(reason: CompactionFailureReason.alreadyCompacted),
  };
  for (final MapEntry(key: name, value: state) in states.entries) {
    test("round-trips $name through the part", () {
      final part = MessagePart.compaction(id: "part-1", sessionID: "session-1", messageID: "message-1", state: state);

      expect(MessagePart.fromJson(part.toJson()), part);
    });
  }

  test("encodes the state under its status key", () {
    const part = MessagePart.compaction(
      id: "part-1",
      sessionID: "session-1",
      messageID: "message-1",
      state: CompactionState.completed(summary: null, freedTokens: 940, trigger: CompactionTrigger.manual),
    );

    expect(part.toJson()["state"], {"status": "completed", "freedTokens": 940, "trigger": "manual"});
  });

  test("an unknown status from a newer bridge reads as completed with no details", () {
    final part = MessagePart.fromJson({
      ...common,
      "state": {"status": "paused", "progress": 0.4},
    });

    expect((part as MessagePartCompaction).state, noDetails);
  });

  test("an unknown trigger reads as null and keeps the other details", () {
    final state = CompactionState.fromJson(const {
      "status": "completed",
      "summary": "## Goal",
      "freedTokens": 142000,
      "trigger": "scheduled",
    });

    expect(state, const CompactionState.completed(summary: "## Goal", freedTokens: 142000, trigger: null));
  });

  test("an unknown failure reason from a newer bridge reads as null", () {
    final state = CompactionState.fromJson(const {"status": "failed", "reason": "quotaExceeded"});

    expect(state, const CompactionState.failed(reason: null));
  });
}
