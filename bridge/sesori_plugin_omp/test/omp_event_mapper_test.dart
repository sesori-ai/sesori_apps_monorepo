import "package:acp_plugin/acp_plugin.dart";
import "package:omp_plugin/src/omp_event_mapper.dart";
import "package:omp_plugin/src/omp_identity.dart";
import "package:omp_plugin/src/trackers/omp_compaction_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late _FakeClock clock;
  late OmpEventMapper mapper;
  late Set<String> pendingTurns;

  setUp(() {
    pendingTurns = {};
    clock = _FakeClock(DateTime.fromMillisecondsSinceEpoch(5000));
    mapper = OmpEventMapper(
      launchDirectory: "/repo",
      pluginId: OmpPluginIdentity.id,
      configurationTracker: AcpSessionConfigurationTracker(),
      childSessions: AcpChildSessionTracker(),
      compactionTracker: OmpCompactionTracker(clock: clock),
      hasPendingTurn: ({required sessionId}) => pendingTurns.contains(sessionId),
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

    // No live busy status: with the idle at the end, the bridge would push a
    // completion notification for a turn the user never ran.
    expect(started, hasLength(2));
    expect(started, isNot(contains(isA<BridgeSseSessionStatus>())));
    expect(started, row(id: "session-1-compaction-5000-0", created: 5000, state: const .running(summary: null)));
    expect(ended, hasLength(4));
    expect(
      ended,
      row(
        id: "session-1-compaction-5000-0",
        created: 5000,
        state: const .completed(summary: null, freedTokens: null, trigger: .auto),
      ),
    );
    expect(ended[2], isA<BridgeSseSessionCompacted>());
    // Idle comes after the settled row, so the idle cleanup finds nothing running.
    expect(ended.last, isA<BridgeSseSessionIdle>());
  });

  test("inside a prompt turn a compaction leaves the session status to the turn", () {
    pendingTurns.add("session-1");

    expect(
      start(),
      allOf(hasLength(2), row(id: "session-1-compaction-5000-0", created: 5000, state: const .running(summary: null))),
    );
    expect(end({}), allOf(hasLength(3), isNot(contains(isA<BridgeSseSessionIdle>()))));
  });

  test("an idle compaction that ends while an accepted prompt waits to begin leaves the session busy", () {
    start();
    // The plugin published busy on accepting the prompt; its turn begins
    // only after the model and mode selection is applied.
    pendingTurns.add("session-1");

    expect(end({}), isNot(contains(isA<BridgeSseSessionIdle>())));
  });

  test("a finished turn forgets a compaction whose end never came", () {
    pendingTurns.add("session-1");
    start();
    mapper.finalizeTurn(sessionId: "session-1");

    expect(mapper.compactingSessionIds, isEmpty);
    expect(end({"aborted": true}), isEmpty);
  });

  test("an OMP exit ends a compaction running outside a turn", () {
    start();

    expect(mapper.endCompactionsAfterExit(), [isA<BridgeSseSessionIdle>()]);
    expect(mapper.compactingSessionIds, isEmpty);
  });

  test("a malformed compaction notification maps to nothing", () {
    expect(
      mapper.map(const AcpNotification(method: OmpEventMapper.compactionStartMethod, params: {"reason": "threshold"})),
      isEmpty,
    );
    expect(mapper.compactingSessionIds, isEmpty);
  });

  test("an aborted end settles the row as cancelled", () {
    start();
    expect(
      end({"aborted": true}),
      allOf(
        hasLength(3),
        row(
          id: "session-1-compaction-5000-0",
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
        hasLength(3),
        row(
          id: "session-1-compaction-5000-0",
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
        hasLength(3),
        row(id: "session-1-compaction-5000-0", created: 5000, state: const .failed(reason: null)),
      ),
    );
  });

  test("a fallback attempt after a failed one gets its own row", () {
    start();
    end({"errorMessage": "Auto-handoff returned no document; trying the next preferred compaction method."});
    clock.current = DateTime.fromMillisecondsSinceEpoch(6000);

    expect(start(), row(id: "session-1-compaction-6000-1", created: 6000, state: const .running(summary: null)));
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
