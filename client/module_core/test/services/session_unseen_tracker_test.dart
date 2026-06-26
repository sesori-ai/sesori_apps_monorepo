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
