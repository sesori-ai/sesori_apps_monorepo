import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockConnectionService extends Mock implements ConnectionService {}

class MockFailureReporter extends Mock implements FailureReporter {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));

  group("SessionUnseenTracker", () {
    late MockConnectionService connectionService;
    late MockFailureReporter failureReporter;
    late StreamController<SseEvent> events;

    setUp(() {
      connectionService = MockConnectionService();
      failureReporter = MockFailureReporter();
      events = StreamController<SseEvent>.broadcast();
      when(() => connectionService.events).thenAnswer((_) => events.stream);
    });

    tearDown(() => events.close());

    SseEvent unseenEvent({
      required String projectID,
      required String sessionId,
      required bool unseen,
      required bool projectHasUnseenChanges,
    }) => SseEvent(
      data: SesoriSseEvent.sessionUnseenChanged(
        projectID: projectID,
        sessionId: sessionId,
        unseen: unseen,
        projectHasUnseenChanges: projectHasUnseenChanges,
      ),
      directory: null,
    );

    test("defaults to empty maps", () {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);
      expect(tracker.currentProjectUnseen, isEmpty);
      expect(tracker.currentSessionUnseen, isEmpty);
      tracker.onDispose();
    });

    test("records per-session and per-project unseen from the event", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.currentProjectUnseen, {"p1": true});
      expect(tracker.currentSessionUnseen, {
        "p1": {"s1": true},
      });
      tracker.onDispose();
    });

    test("reconcile keeps the live value for a session updated during the fetch", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // A REST fetch starts here.
      final gen = tracker.generation;

      // A live event for s1 arrives while the fetch is in flight.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // The (older) REST snapshot now tries to clear s1 — it must be ignored.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: gen,
      );
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isTrue);

      // A fresh fetch (generation captured after the live event) reconciles.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: tracker.generation,
      );
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("reconcile still clears a sibling session when an unrelated session got a live update", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // The tracker carries a stale unseen=true for s1 (e.g. a clear missed
      // while reconnecting).
      final gen0 = tracker.generation;
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true, "s2": false},
        sinceGeneration: gen0,
      );

      // A REST /sessions fetch begins (would clear s1).
      final gen = tracker.generation;

      // While in flight, an UNRELATED live update arrives for s2.
      events.add(unseenEvent(projectID: "p1", sessionId: "s2", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // The REST snapshot lands: s1 cleared, s2 cleared. s1 must clear (it had
      // no live update); s2 keeps its newer live value.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false, "s2": false},
        sinceGeneration: gen,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      expect(tracker.currentSessionUnseen["p1"]?["s2"], isTrue);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("reconcile preserves a live session that is absent from the REST snapshot", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // A /sessions fetch begins (the snapshot will contain only s1).
      final gen = tracker.generation;

      // While in flight, a brand-new session s2 becomes unseen via a live event
      // (e.g. session.created landed after the request started).
      events.add(unseenEvent(projectID: "p1", sessionId: "s2", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // The older REST snapshot lands without s2. s2 must be preserved (its live
      // generation is newer than the fetch), not dropped.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: gen,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      expect(tracker.currentSessionUnseen["p1"]?["s2"], isTrue);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("reconcile does NOT preserve an archived session omitted from the REST snapshot", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // Two unseen sessions exist; the project is bold.
      final gen0 = tracker.generation;
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true, "s2": true},
        sinceGeneration: gen0,
      );
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // A /sessions refresh begins (snapshot will omit the archived s1).
      final gen = tracker.generation;

      // s1 is archived: the archive event carries unseen:true (from timestamps)
      // but projectHasUnseenChanges:false (it left the aggregate). s2 is also
      // seen now, so the project should end up not bold.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);

      // REST snapshot lands without the archived s1, and s2 cleared.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s2": false},
        sinceGeneration: gen,
      );

      // s1 must NOT be carried forward (its project aggregate is false), so the
      // project is not re-bolded.
      expect(tracker.currentSessionUnseen["p1"]?.containsKey("s1"), isFalse);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("a stale /sessions response cannot overwrite a newer live archive aggregate", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // Two unseen sessions; project bold.
      final gen0 = tracker.generation;
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true, "s2": true},
        sinceGeneration: gen0,
      );
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // A slow /sessions fetch begins (its snapshot still lists s1 as present+unseen).
      final gen = tracker.generation;

      // Meanwhile s2 is seen and s1 is archived: the archive event carries
      // unseen:true (timestamps) but projectHasUnseenChanges:false.
      events.add(unseenEvent(projectID: "p1", sessionId: "s2", unseen: false, projectHasUnseenChanges: true));
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.currentProjectUnseen["p1"], isFalse);

      // The stale REST response lands, still listing s1 present+unseen. It must
      // NOT re-bold the project: the live aggregate (false) is newer.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true, "s2": true},
        sinceGeneration: gen,
      );
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("local mark of another session ignores an archived unseen entry in the aggregate", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // s1 archived (excluded), s2 seen. Project not bold.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: false));
      events.add(unseenEvent(projectID: "p1", sessionId: "s2", unseen: false, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.currentProjectUnseen["p1"], isFalse);

      // Optimistically mark s2 read again — the archived s1 entry (still
      // unseen:true in the map) must not re-bold the project.
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s2", unseen: false);
      expect(tracker.currentProjectUnseen["p1"], isFalse);

      // Even marking the archived s1 as unread must not re-bold the project.
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("revertLocalSessionUnseen is a no-op when a newer update landed since the action", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // Optimistically mark s1 unread (e.g. an in-flight mark-unread request).
      final gen = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);

      // Genuine live activity for s1 arrives (newer generation) before the
      // request fails.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // The failed request tries to revert to the pre-click value (false) — it
      // must be ignored because a newer update exists.
      tracker.revertLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false, ifGeneration: gen);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isTrue);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("revertLocalSessionUnseen rolls back when no newer update landed", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);
      final gen = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isTrue);

      tracker.revertLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false, ifGeneration: gen);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      tracker.onDispose();
    });

    test("reconcile excludes an absent carried-forward session from the aggregate", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // s1 and s2 both unseen.
      final gen0 = tracker.generation;
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true, "s2": true},
        sinceGeneration: gen0,
      );

      // A /sessions fetch begins.
      final gen = tracker.generation;
      // s1 is archived while s2 stays unseen: the archive SSE carries
      // unseen:true AND projectHasUnseenChanges:true (s2), so exclusion can't be
      // detected from the event.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // The authoritative /sessions list (archived s1 omitted) lands. s1 is
      // carried forward (live + project still unseen) but EXCLUDED from the
      // aggregate.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s2": true},
        sinceGeneration: gen,
      );

      // Now mark s2 read locally. Only the excluded archived s1 remains unseen,
      // so the project must NOT stay bold.
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s2", unseen: false);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("a later seen event clears the session and updates the project aggregate", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: false, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.currentProjectUnseen, {"p1": false});
      expect(tracker.currentSessionUnseen, {
        "p1": {"s1": false},
      });
      tracker.onDispose();
    });
  });
}
