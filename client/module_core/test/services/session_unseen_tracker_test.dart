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
