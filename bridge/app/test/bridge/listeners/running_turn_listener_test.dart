import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/session_interruption_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/listeners/running_turn_listener.dart";
import "package:sesori_bridge/src/repositories/models/normalized_bridge_event.dart";
import "package:sesori_bridge/src/repositories/session_interruption_repository.dart";
import "package:sesori_bridge/src/services/session_event_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgeSseSessionIdle;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late SessionInterruptionRepository interruptions;
  late StreamController<NormalizedSourcedBridgeEvent> source;
  late RunningTurnListener listener;
  final now = DateTime.utc(2026, 11, 15, 11);

  setUp(() async {
    db = createTestDatabase();
    interruptions = SessionInterruptionRepository(dao: SessionInterruptionDao(database: db));
    for (final sessionId in ["s1", "s2"]) {
      await insertTestSessionInDirectory(
        db: db,
        sessionId: sessionId,
        pluginId: "codex",
        projectId: "p1",
        directory: "/repo",
      );
    }
    source = StreamController();
    listener = RunningTurnListener(source: source.stream, interruptions: interruptions, clock: Clock.fixed(now))
      ..start();
  });

  tearDown(() async {
    await listener.dispose();
    await source.close();
    await db.close();
  });

  void emit(NormalizedBridgeEvent event) => source.add((
    pluginId: "codex",
    generation: null,
    event: event,
    allowDuringStop: false,
    terminalHandoffConsumed: null,
  ));

  Future<Set<String>> running() async {
    await pumpEventQueue();
    final rows = await interruptions.readLeftovers(pluginId: "codex", startedBefore: now.add(const Duration(days: 1)));
    return {for (final row in rows) row.sessionId};
  }

  test("a busy status marks the session running and an idle clears it", () async {
    emit(const NormalizedStatusEvent(sessionId: "s1", status: SessionStatus.busy(since: 1)));
    emit(
      const NormalizedStatusEvent(
        sessionId: "s2",
        status: SessionStatus.retry(attempt: 1, message: "x", next: 2, since: 1),
      ),
    );
    expect(await running(), {"s1", "s2"});

    emit(const NormalizedStatusEvent(sessionId: "s1", status: SessionStatus.idle()));
    emit(
      const NormalizedTerminalHandoff(
        payload: NormalizedOtherEvent(event: BridgeSseSessionIdle(sessionID: "s2")),
      ),
    );
    expect(await running(), isEmpty);
  });

  test("idles after beginShutdown keep the rows", () async {
    emit(const NormalizedStatusEvent(sessionId: "s1", status: SessionStatus.busy(since: 1)));
    expect(await running(), {"s1"});

    listener.beginShutdown();
    emit(const NormalizedStatusEvent(sessionId: "s1", status: SessionStatus.idle()));
    emit(const NormalizedOtherEvent(event: BridgeSseSessionIdle(sessionID: "s1")));

    expect(await running(), {"s1"});
  });
}
