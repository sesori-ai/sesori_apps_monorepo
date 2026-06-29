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
      tracker.revertLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false, projectUnseen: false, ifGeneration: gen);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isTrue);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("revertLocalSessionUnseen rolls back when no newer update landed", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);
      final gen = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isTrue);

      tracker.revertLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false, projectUnseen: false, ifGeneration: gen);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      tracker.onDispose();
    });

    test("a local mark-read does not recompute the aggregate; the bridge echo settles it", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // s1 and s2 both unseen; project bold.
      final gen0 = tracker.generation;
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true, "s2": true},
        sinceGeneration: gen0,
      );
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // Marking s2 read locally must NOT recompute the project aggregate from the
      // per-session map (the client can't know which other rows are archived on
      // the bridge), so the project stays bold until the authoritative echo.
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s2", unseen: false);
      expect(tracker.currentSessionUnseen["p1"]?["s2"], isFalse);
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // The bridge echo for the mark-read carries the authoritative aggregate
      // (s1 still genuinely unseen here) and settles it.
      events.add(unseenEvent(projectID: "p1", sessionId: "s2", unseen: false, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("a new session absent from a stale snapshot is NOT excluded from the aggregate", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // s2 already unseen and reconciled.
      final gen0 = tracker.generation;
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s2": true},
        sinceGeneration: gen0,
      );

      // A /sessions fetch begins (its snapshot will omit the soon-to-be-created s1).
      final gen = tracker.generation;
      // A brand-new unseen session s1 is created after the snapshot began.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // The stale REST snapshot (omitting s1) lands. s1 is carried forward and
      // must NOT be excluded — it is a new session, not an archived one.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s2": true},
        sinceGeneration: gen,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isTrue);

      // Marking the OTHER session (s2) read must not clear the project bold:
      // s1 is genuinely unseen. Conservative mark-read leaves the aggregate to
      // the echo, so the project stays bold (correct — s1 is unseen).
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s2", unseen: false);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("reconcile does not block a revert for a session it left unchanged", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // Optimistically mark s1 unread (in-flight mark-unread).
      final gen0 = tracker.generation;
      final gen = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);

      // A /sessions reconcile runs while the request is in flight. Its snapshot
      // agrees with the optimistic value (s1 unseen), so it does NOT change s1
      // and must not bump s1's generation.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true},
        sinceGeneration: gen0,
      );

      // The request fails: the revert (to the pre-click value) must still apply
      // because the reconcile left s1 unchanged.
      tracker.revertLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false, projectUnseen: false, ifGeneration: gen);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      tracker.onDispose();
    });

    test("reconcile blocks a revert for a session whose value it changed", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // Optimistically mark s1 unread.
      final gen = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);

      // A reconcile started AFTER the optimistic apply (sinceGeneration == gen)
      // delivers the authoritative value (seen), changing s1 and bumping its
      // generation.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: gen,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);

      // A late failed-request revert (to the pre-click true) must be a no-op,
      // leaving the authoritative reconciled value.
      tracker.revertLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true, projectUnseen: false, ifGeneration: gen);
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      tracker.onDispose();
    });

    test("reconcile recomputes the project aggregate from the REST snapshot only", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // A live event leaves a stale unseen entry for s_old in the map.
      events.add(unseenEvent(projectID: "p1", sessionId: "s_old", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // An authoritative complete /sessions reconcile (captured after the live
      // event, so the recompute path runs) lists only s2, seen — s_old is gone
      // from the authoritative list. The aggregate must reflect the REST
      // snapshot (false), not the stale s_old entry.
      final gen = tracker.generation;
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s2": false},
        sinceGeneration: gen,
      );
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("a /projects reconcile guards against an older /sessions reconcile", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // An older /sessions fetch begins (its snapshot still shows p1 unseen).
      final sessionsGen = tracker.generation;

      // A newer /projects refresh authoritatively clears p1.
      tracker.reconcileProjectUnseen({"p1": false}, sinceGeneration: tracker.generation);
      expect(tracker.currentProjectUnseen["p1"], isFalse);

      // The stale /sessions response finally lands (with p1 still unseen). It is
      // older than the /projects apply, so it must not recompute p1 back to true.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true},
        sinceGeneration: sessionsGen,
      );
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("an archived session's exclusion survives a read echo", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // s1 archived while s2 keeps the project unseen → s1 excluded.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);

      // The bridge echo for marking the archived s1 read is unseen:false +
      // projectHasUnseenChanges:false — it must NOT drop s1's exclusion.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: false, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);

      // Marking the still-archived s1 unread must not re-bold the project.
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("reconcileSessionUnseen records archived ids as excluded", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // REST list: s1 active+unseen, s2 archived (omitted from unseenBySessionId
      // but reported as archived).
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true},
        archivedUnseenBySessionId: {"s2": false},
        sinceGeneration: tracker.generation,
      );

      // Marking the archived s2 unread must not locally re-bold beyond what's
      // already there: s2 is excluded, so it can't bold the project on its own.
      final projects0 = tracker.currentProjectUnseen["p1"];
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s2", unseen: true);
      expect(tracker.currentProjectUnseen["p1"], equals(projects0));
      tracker.onDispose();
    });

    test("a local mark-read does not advance the project generation", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // p1 is currently bold from a live event.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // An older /projects fetch begins.
      final projectsGen = tracker.generation;

      // The user optimistically marks s1 read locally (aggregate left to echo).
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false);

      // The /projects response (authoritative false) lands. Because mark-read did
      // not advance the project generation, this is NOT treated as older and
      // applies — clearing the project even if the SSE echo is missed.
      tracker.reconcileProjectUnseen({"p1": false}, sinceGeneration: projectsGen);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("a failed mark-unread rollback restores the project aggregate", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // p1 starts not bold (its only session is seen).
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: tracker.generation,
      );
      expect(tracker.currentProjectUnseen["p1"], isFalse);

      // Optimistically mark s1 unread → bolds the project.
      final priorAggregate = tracker.currentProjectUnseen["p1"] ?? false;
      final gen = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // The request fails: rollback must restore BOTH the per-session value and
      // the project aggregate (there is no bridge echo for a failed request).
      tracker.revertLocalSessionUnseen(
        projectId: "p1",
        sessionId: "s1",
        unseen: false,
        projectUnseen: priorAggregate,
        ifGeneration: gen,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("a newer /sessions clear is not blocked by an older overlapping reconcile", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // s1 currently seen.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: tracker.generation,
      );

      // Two overlapping /sessions refreshes both captured this generation.
      final sg = tracker.generation;

      // The OLDER response (stale snapshot) lands first and flips s1 to unseen.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true},
        sinceGeneration: sg,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isTrue);

      // The NEWER response (started after a remote mark-read) authoritatively
      // says s1 is seen. Because REST reconciles don't pollute the live-
      // generation map, this is not treated as older-than-a-live-update and the
      // clear applies.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: sg,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      tracker.onDispose();
    });

    test("a stale REST archived id does not exclude a session unarchived live since the fetch", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // A /sessions fetch begins; its snapshot will report s1 as archived.
      final gen = tracker.generation;

      // Meanwhile s1 is unarchived live and is genuinely unseen again.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // The stale snapshot lands reporting s1 archived — but the newer live
      // unarchive must win: s1 is NOT marked excluded.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: const {},
        archivedUnseenBySessionId: {"s1": true},
        sinceGeneration: gen,
      );

      // Marking s1 unread should bold the project (it is not excluded).
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("removeSession clears the project bold when the last unseen session is deleted", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // Project bold from a single unseen session.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true},
        sinceGeneration: tracker.generation,
      );
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // Deleting it locally settles the aggregate immediately (no echo needed).
      tracker.removeSession(projectId: "p1", sessionId: "s1");
      expect(tracker.currentSessionUnseen["p1"]?.containsKey("s1"), isFalse);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("removeSession keeps the project bold when another unseen session remains", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true, "s2": true},
        sinceGeneration: tracker.generation,
      );

      tracker.removeSession(projectId: "p1", sessionId: "s1");
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("reconcile preserves an archived row's live read echo over a stale REST value", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // An archived /sessions fetch begins (its snapshot still has s1 unseen).
      final gen = tracker.generation;

      // A live read echo for the archived s1 arrives meanwhile (unseen:false).
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: false, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);

      // The stale archived snapshot lands with s1 still unseen=true. Because the
      // tracker reconciles archived rows (not just their ids), the newer live
      // read value is preserved rather than dropped + re-bolded from stale REST.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: const {},
        archivedUnseenBySessionId: {"s1": true},
        sinceGeneration: gen,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      tracker.onDispose();
    });

    test("an archived row stays excluded after a live read echo (not treated as unarchive)", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // A /sessions fetch begins.
      final gen = tracker.generation;
      // A live READ echo for the archived s1 (unseen:false), newer than the fetch.
      events.add(unseenEvent(projectID: "p1", sessionId: "s1", unseen: false, projectHasUnseenChanges: false));
      await Future<void>.delayed(Duration.zero);

      // The /sessions snapshot reports s1 archived. Despite the newer live echo,
      // s1 stays excluded (a read echo is not an unarchive).
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: const {},
        archivedUnseenBySessionId: {"s1": false},
        sinceGeneration: gen,
      );

      // Marking the still-archived s1 unread must not re-bold the project.
      tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("a /sessions reconcile does not block a later /projects clear", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // Both an older /sessions and a newer /projects captured this generation.
      final g = tracker.generation;
      // The older /sessions lands first, recomputing p1 as bold.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true},
        sinceGeneration: g,
      );
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // The newer /projects response authoritatively clears p1. It must apply —
      // the /sessions reconcile must not have stamped the project generation.
      tracker.reconcileProjectUnseen({"p1": false}, sinceGeneration: g);
      expect(tracker.currentProjectUnseen["p1"], isFalse);
      tracker.onDispose();
    });

    test("revert does not clobber the aggregate when another session updated meanwhile", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // p1 starts not bold.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": false},
        sinceGeneration: tracker.generation,
      );
      final prior = tracker.currentProjectUnseen["p1"] ?? false;

      // Optimistically mark s1 unread → bolds the project.
      final g = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: true);
      expect(tracker.currentProjectUnseen["p1"], isTrue);

      // Another session s2 gets a live unseen update (advances the project gen).
      events.add(unseenEvent(projectID: "p1", sessionId: "s2", unseen: true, projectHasUnseenChanges: true));
      await Future<void>.delayed(Duration.zero);

      // s1's request fails → revert. The per-session value rolls back, but the
      // aggregate must NOT be clobbered back to the stale captured `prior`
      // (s2 legitimately keeps the project bold).
      tracker.revertLocalSessionUnseen(
        projectId: "p1",
        sessionId: "s1",
        unseen: false,
        projectUnseen: prior,
        ifGeneration: g,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], isFalse);
      expect(tracker.currentProjectUnseen["p1"], isTrue);
      tracker.onDispose();
    });

    test("a reconcile that omits a deleted session blocks a stale rollback for it", () async {
      final tracker = SessionUnseenTracker(connectionService, failureReporter: failureReporter);

      // s1 tracked as unseen.
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: {"s1": true},
        sinceGeneration: tracker.generation,
      );

      // Optimistically mark s1 read (in-flight request).
      final g = tracker.applyLocalSessionUnseen(projectId: "p1", sessionId: "s1", unseen: false);

      // An authoritative /sessions reconcile now omits s1 (it was deleted).
      tracker.reconcileSessionUnseen(
        projectId: "p1",
        unseenBySessionId: const {},
        sinceGeneration: g,
      );

      // The request then fails: the rollback to the pre-click unseen:true must be
      // a no-op — REST already proved s1 is gone, so it can't be resurrected.
      tracker.revertLocalSessionUnseen(
        projectId: "p1",
        sessionId: "s1",
        unseen: true,
        projectUnseen: true,
        ifGeneration: g,
      );
      expect(tracker.currentSessionUnseen["p1"]?["s1"], anyOf(isNull, isFalse));
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
