import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _MockConnectionService extends Mock implements ConnectionService {
  final StreamController<SseEvent> _events = StreamController<SseEvent>.broadcast();

  @override
  Stream<SseEvent> get events => _events.stream;

  void emitUnseenChanged({
    required String projectId,
    required String sessionId,
    required bool unseen,
    required bool projectHasUnseenChanges,
    required int? sessionLastUserInteractionAt,
    required int? projectLastUserInteractionAt,
  }) {
    _events.add(
      SseEvent(
        data: SesoriSseEvent.sessionUnseenChanged(
          projectID: projectId,
          sessionId: sessionId,
          unseen: unseen,
          projectHasUnseenChanges: projectHasUnseenChanges,
          sessionLastUserInteractionAt: sessionLastUserInteractionAt,
          projectLastUserInteractionAt: projectLastUserInteractionAt,
        ),
      ),
    );
  }
}

void main() {
  group("SessionAttentionTracker", () {
    late _MockConnectionService connectionService;
    late SessionAttentionTracker tracker;

    setUp(() {
      connectionService = _MockConnectionService();
      tracker = SessionAttentionTracker(
        connectionService: connectionService,
        failureReporter: MockFailureReporter(),
      );
    });

    tearDown(() async {
      await tracker.onDispose();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test("SSE events overwrite both the session flag and the project aggregate", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 100,
        projectLastUserInteractionAt: 100,
      );
      await pump();

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": true}));
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      expect(tracker.currentSessionLastUserInteractionAt["p1"], equals({"s1": 100}));
      expect(tracker.currentProjectLastUserInteractionAt["p1"], 100);

      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: false,
        projectHasUnseenChanges: false,
        sessionLastUserInteractionAt: null,
        projectLastUserInteractionAt: null,
      );
      await pump();

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": false}));
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      expect(tracker.currentSessionLastUserInteractionAt["p1"], equals({"s1": null}));
      expect(tracker.currentProjectLastUserInteractionAt.containsKey("p1"), isTrue);
      expect(tracker.currentProjectLastUserInteractionAt["p1"], isNull);
    });

    test("seedSessions replaces the project's map, dropping deleted sessions", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "stale",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 900,
        projectLastUserInteractionAt: 900,
      );
      await pump();

      tracker.seedSessions(
        projectId: "p1",
        unseenBySessionId: const {"s1": true, "s2": false},
        lastUserInteractionAtBySessionId: const {"s1": 100, "s2": null},
        sinceTick: tracker.tick,
      );

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": true, "s2": false}));
      expect(tracker.currentSessionLastUserInteractionAt["p1"], equals({"s1": 100, "s2": null}));
    });

    test("a seed captured before a live update does not clobber it", () async {
      // Simulate a fetch that started BEFORE the live event landed.
      final preFetchTick = tracker.tick;

      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 500,
        projectLastUserInteractionAt: 500,
      );
      await pump();

      // The (stale) snapshot from that fetch reports everything seen.
      tracker.seedSessions(
        projectId: "p1",
        unseenBySessionId: const {"s1": false},
        lastUserInteractionAtBySessionId: const {"s1": 100},
        sinceTick: preFetchTick,
      );
      tracker.seedProjects(
        const {"p1": false},
        lastUserInteractionAtByProjectId: const {"p1": 100},
        sinceTick: preFetchTick,
      );

      // The live update is newer than the snapshot, so it wins.
      expect(tracker.currentSessionUnseen["p1"], equals({"s1": true}));
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      expect(tracker.currentSessionLastUserInteractionAt["p1"], equals({"s1": 500}));
      expect(tracker.currentProjectLastUserInteractionAt["p1"], 500);
    });

    test("a stale seed still refreshes sessions without newer updates", () async {
      tracker.seedSessions(
        projectId: "p1",
        unseenBySessionId: const {"s1": false, "s2": false},
        lastUserInteractionAtBySessionId: const {"s1": 100, "s2": 200},
        sinceTick: tracker.tick,
      );
      final preFetchTick = tracker.tick;

      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 500,
        projectLastUserInteractionAt: 500,
      );
      await pump();

      tracker.seedSessions(
        projectId: "p1",
        unseenBySessionId: const {"s1": false, "s2": true},
        lastUserInteractionAtBySessionId: const {"s1": 100, "s2": 300},
        sinceTick: preFetchTick,
      );

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": true, "s2": true}));
      expect(tracker.currentSessionLastUserInteractionAt["p1"], equals({"s1": 500, "s2": 300}));
    });

    test("a stale seed only skips the projects that were updated live", () async {
      final preFetchTick = tracker.tick;

      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 500,
        projectLastUserInteractionAt: 500,
      );
      await pump();

      tracker.seedProjects(
        const {"p1": false, "p2": true},
        lastUserInteractionAtByProjectId: const {"p1": 100, "p2": 200},
        sinceTick: preFetchTick,
      );

      // p1 keeps the newer live value; p2 (no live update) takes the seed.
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      expect(tracker.currentProjectUnseen["p2"], isTrue);
      expect(tracker.currentProjectLastUserInteractionAt["p1"], 500);
      expect(tracker.currentProjectLastUserInteractionAt["p2"], 200);
    });

    test("a fresh seed overwrites older live state (missed-clear recovery)", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 100,
        projectLastUserInteractionAt: 100,
      );
      await pump();

      // A fetch that started AFTER the live update is authoritative: e.g. the
      // session was read on another phone while this client was disconnected.
      tracker.seedSessions(
        projectId: "p1",
        unseenBySessionId: const {"s1": false},
        lastUserInteractionAtBySessionId: const {"s1": 600},
        sinceTick: tracker.tick,
      );
      tracker.seedProjects(
        const {"p1": false},
        lastUserInteractionAtByProjectId: const {"p1": 600},
        sinceTick: tracker.tick,
      );

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": false}));
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      expect(tracker.currentSessionLastUserInteractionAt["p1"], equals({"s1": 600}));
      expect(tracker.currentProjectLastUserInteractionAt["p1"], 600);
    });

    test("applyLocalSessionUnseen touches only the session flag, never the aggregate", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 100,
        projectLastUserInteractionAt: 100,
      );
      await pump();

      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false);

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": false}));
      // The aggregate is bridge-owned; the echo settles it.
      expect(tracker.currentProjectUnseen["p1"], isTrue);
    });

    test("a local apply is protected from an in-flight stale snapshot", () async {
      final preFetchTick = tracker.tick;

      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);

      // The stale snapshot (fetched before the user's action) says seen.
      tracker.seedSessions(
        projectId: "p1",
        unseenBySessionId: const {"s1": false},
        lastUserInteractionAtBySessionId: const {"s1": 50},
        sinceTick: preFetchTick,
      );

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": true}));
    });

    test("a local unseen apply does not block interaction metadata seeding", () {
      final preFetchTick = tracker.tick;

      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      tracker.seedSessions(
        projectId: "p1",
        unseenBySessionId: const {"s1": false},
        lastUserInteractionAtBySessionId: const {"s1": 500},
        sinceTick: preFetchTick,
      );

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": true}));
      expect(tracker.currentSessionLastUserInteractionAt["p1"], equals({"s1": 500}));
    });

    test("streams replay the latest value to late subscribers", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        sessionLastUserInteractionAt: 100,
        projectLastUserInteractionAt: 100,
      );
      await pump();

      expect(await tracker.projectUnseen.first, equals({"p1": true}));
      expect(
        await tracker.sessionUnseen.first,
        equals({
          "p1": {"s1": true},
        }),
      );
      expect(await tracker.projectLastUserInteractionAt.first, equals({"p1": 100}));
      expect(
        await tracker.sessionLastUserInteractionAt.first,
        equals({
          "p1": {"s1": 100},
        }),
      );
    });
  });
}
