import "package:acp_plugin/acp_plugin.dart";
import "package:omp_plugin/src/omp_event_mapper.dart";
import "package:omp_plugin/src/omp_identity.dart";
import "package:omp_plugin/src/trackers/omp_compaction_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late _FakeClock clock;
  late OmpEventMapper mapper;

  setUp(() {
    clock = _FakeClock(DateTime.fromMillisecondsSinceEpoch(5000));
    mapper = OmpEventMapper(
      launchDirectory: "/repo",
      pluginId: OmpPluginIdentity.id,
      configurationTracker: AcpSessionConfigurationTracker(),
      childSessions: AcpChildSessionTracker(),
      compactionTracker: OmpCompactionTracker(clock: clock),
    );
  });

  List<BridgeSseEvent> start() => mapper.map(
    const AcpNotification(
      method: OmpEventMapper.compactionStartMethod,
      params: {"sessionId": "session-1", "reason": "threshold", "action": "context-full"},
    ),
  );

  List<BridgeSseEvent> end(Map<String, dynamic> fields) => mapper.map(
    AcpNotification(
      method: OmpEventMapper.compactionEndMethod,
      params: {"sessionId": "session-1", "action": "context-full", "aborted": false, "willRetry": false, ...fields},
    ),
  );

  Matcher row({required String id, required int created, required PluginCompactionState state}) => containsAllInOrder([
    isA<BridgeSseMessageUpdated>().having(
      (event) => event.info,
      "info",
      isA<PluginMessageAssistant>()
          .having((info) => info.id, "id", id)
          .having((info) => info.sender, "sender", PluginMessageSender.agent)
          .having((info) => info.time, "time", PluginMessageTime(created: created, completed: null)),
    ),
    isA<BridgeSseMessagePartUpdated>().having(
      (event) => event.part,
      "part",
      isA<PluginMessagePartCompaction>()
          .having((part) => part.id, "id", "$id-part")
          .having((part) => part.compactionState, "compactionState", state),
    ),
  ]);

  test("a start shows the running row and a successful end settles it as an automatic compaction", () {
    final started = start();
    clock.current = DateTime.fromMillisecondsSinceEpoch(9000);
    // willRetry on success means OMP re-sends the overflowed turn; the
    // compaction itself is done.
    final ended = end({"willRetry": true, "tokensBefore": 120000});

    expect(started, hasLength(2));
    expect(started, row(id: "session-1-compaction-5000", created: 5000, state: const .running(summary: null)));
    expect(ended, hasLength(3));
    expect(
      ended,
      row(
        id: "session-1-compaction-5000",
        created: 5000,
        state: const .completed(summary: null, freedTokens: null, trigger: .auto),
      ),
    );
    expect(ended.last, isA<BridgeSseSessionCompacted>());
  });

  test("an aborted end settles the row as cancelled", () {
    start();
    expect(
      end({"aborted": true}),
      allOf(
        hasLength(2),
        row(
          id: "session-1-compaction-5000",
          created: 5000,
          state: const .failed(reason: .cancelled),
        ),
      ),
    );
  });

  test("a benign skip settles the row as nothing to compact", () {
    start();
    expect(
      end({"skipped": true, "errorMessage": "Auto-shake found nothing eligible to drop."}),
      allOf(
        hasLength(2),
        row(
          id: "session-1-compaction-5000",
          created: 5000,
          state: const .failed(reason: .nothingToCompact),
        ),
      ),
    );
  });

  test("an end with an error settles the row as failed", () {
    start();

    expect(
      end({"errorMessage": "Auto-compaction failed: provider unavailable"}),
      allOf(
        hasLength(2),
        row(id: "session-1-compaction-5000", created: 5000, state: const .failed(reason: null)),
      ),
    );
  });

  test("a fallback attempt after a failed one gets its own row", () {
    start();
    end({"errorMessage": "Auto-handoff returned no document; trying the next preferred compaction method."});
    clock.current = DateTime.fromMillisecondsSinceEpoch(6000);

    expect(start(), row(id: "session-1-compaction-6000", created: 6000, state: const .running(summary: null)));
  });

  test("an end without a recorded start reports only a successful compaction", () {
    expect(end({}), [isA<BridgeSseSessionCompacted>()]);
    expect(end({"aborted": true}), isEmpty);
  });

  test("compaction notifications wait behind an accepted prompt write", () {
    for (final method in [OmpEventMapper.compactionStartMethod, OmpEventMapper.compactionEndMethod]) {
      expect(
        mapper.shouldBufferDuringPromptWrite(
          notification: AcpNotification(method: method, params: const {"sessionId": "session-1"}),
        ),
        isTrue,
      );
    }
  });
}

final class _FakeClock(var DateTime current) implements ServerClock {
  @override
  DateTime now() => current;

  @override
  Future<void> delay({required Duration duration}) async {}
}
