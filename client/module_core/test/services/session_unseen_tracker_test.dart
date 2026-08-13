import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _MockConnectionService() extends Mock implements ConnectionService {
  final StreamController<SseEvent> _events = StreamController<SseEvent>.broadcast();

  @override
  Stream<SseEvent> get events => _events.stream;

  void emitUnseenChanged({
    required String projectId,
    required String sessionId,
    required bool unseen,
    required bool projectHasUnseenChanges,
    required int? lastUserActivityAt,
  }) {
    _events.add(
      SseEvent(
        data: SesoriSseEvent.sessionUnseenChanged(
          projectID: projectId,
          sessionId: sessionId,
          unseen: unseen,
          projectHasUnseenChanges: projectHasUnseenChanges,
          lastUserActivityAt: lastUserActivityAt,
        ),
      ),
    );
  }
}

void main() {
  group("SessionUnseenTracker", () {
    late _MockConnectionService connectionService;
    late SessionUnseenTracker tracker;

    setUp(() {
      connectionService = _MockConnectionService();
      tracker = SessionUnseenTracker(
        connectionService,
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
        lastUserActivityAt: null,
      );
      await pump();

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": (unseen: true, lastUserActivityAt: null)}));
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: false,
        projectHasUnseenChanges: false,
        lastUserActivityAt: null,
      );
      await pump();

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": (unseen: false, lastUserActivityAt: null)}));
      expect(tracker.currentProjectUnseen["p1"], isFalse);
    });

    test("live patches replace unseen and max-merge non-null activity markers", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: 20,
      );
      await pump();
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: false,
        projectHasUnseenChanges: false,
        lastUserActivityAt: 10,
      );
      await pump();
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: null,
      );
      await pump();

      expect(
        tracker.currentSessionUnseen["p1"]?["s1"],
        equals((unseen: true, lastUserActivityAt: 20)),
      );
    });

    test("seedSessions replaces the project's map, dropping deleted sessions", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "stale",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: null,
      );
      await pump();

      tracker.seedSessions(
        projectId: "p1",
        stateBySessionId: const {
          "s1": (unseen: true, lastUserActivityAt: 10),
          "s2": (unseen: false, lastUserActivityAt: null),
        },
        sinceTick: tracker.tick,
      );

      expect(
        tracker.currentSessionUnseen["p1"],
        equals({
          "s1": (unseen: true, lastUserActivityAt: 10),
          "s2": (unseen: false, lastUserActivityAt: null),
        }),
      );
    });

    test("a seed captured before a live update does not clobber it", () async {
      // Simulate a fetch that started BEFORE the live event landed.
      final preFetchTick = tracker.tick;

      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: null,
      );
      await pump();

      // The (stale) snapshot from that fetch reports everything seen.
      tracker.seedSessions(
        projectId: "p1",
        stateBySessionId: const {"s1": (unseen: false, lastUserActivityAt: null)},
        sinceTick: preFetchTick,
      );
      tracker.seedProjects(const {"p1": false}, sinceTick: preFetchTick);

      // The live update is newer than the snapshot, so it wins.
      expect(tracker.currentSessionUnseen["p1"], equals({"s1": (unseen: true, lastUserActivityAt: null)}));
      expect(tracker.currentProjectUnseen["p1"], isTrue);
    });

    test("a stale seed only skips the projects that were updated live", () async {
      final preFetchTick = tracker.tick;

      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: null,
      );
      await pump();

      tracker.seedProjects(const {"p1": false, "p2": true}, sinceTick: preFetchTick);

      // p1 keeps the newer live value; p2 (no live update) takes the seed.
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      expect(tracker.currentProjectUnseen["p2"], isTrue);
    });

    test("a fresh seed overwrites older live state (missed-clear recovery)", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: null,
      );
      await pump();

      // A fetch that started AFTER the live update is authoritative: e.g. the
      // session was read on another phone while this client was disconnected.
      tracker.seedSessions(
        projectId: "p1",
        stateBySessionId: const {"s1": (unseen: false, lastUserActivityAt: null)},
        sinceTick: tracker.tick,
      );
      tracker.seedProjects(const {"p1": false}, sinceTick: tracker.tick);

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": (unseen: false, lastUserActivityAt: null)}));
      expect(tracker.currentProjectUnseen["p1"], isFalse);
    });

    test("an unchanged session update marker does not invalidate an in-flight seed", () {
      tracker.seedSessions(
        projectId: "p1",
        stateBySessionId: const {"s1": (unseen: true, lastUserActivityAt: 20)},
        sinceTick: tracker.tick,
      );
      final preFetchTick = tracker.tick;

      tracker.applySessionActivity(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        lastUserActivityAt: 20,
      );
      tracker.seedSessions(
        projectId: "p1",
        stateBySessionId: const {"s1": (unseen: false, lastUserActivityAt: 20)},
        sinceTick: preFetchTick,
      );

      expect(tracker.currentSessionUnseen["p1"]?["s1"], (unseen: false, lastUserActivityAt: 20));
    });

    test("applyLocalSessionUnseen preserves the marker and never touches the aggregate", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: 20,
      );
      await pump();

      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false);

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": (unseen: false, lastUserActivityAt: 20)}));
      // The aggregate is bridge-owned; the echo settles it.
      expect(tracker.currentProjectUnseen["p1"], isTrue);
    });

    test("a local apply is protected from an in-flight stale snapshot", () async {
      final preFetchTick = tracker.tick;

      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);

      // The stale snapshot (fetched before the user's action) says seen.
      tracker.seedSessions(
        projectId: "p1",
        stateBySessionId: const {"s1": (unseen: false, lastUserActivityAt: null)},
        sinceTick: preFetchTick,
      );

      expect(tracker.currentSessionUnseen["p1"], equals({"s1": (unseen: true, lastUserActivityAt: null)}));
    });

    test("streams replay the latest value to late subscribers", () async {
      connectionService.emitUnseenChanged(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectHasUnseenChanges: true,
        lastUserActivityAt: null,
      );
      await pump();

      expect(await tracker.projectUnseen.first, equals({"p1": true}));
      expect(
        await tracker.sessionUnseen.first,
        equals({
          "p1": {"s1": (unseen: true, lastUserActivityAt: null)},
        }),
      );
    });
  });
}
