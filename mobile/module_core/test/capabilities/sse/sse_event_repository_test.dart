import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockConnectionService extends Mock implements ConnectionService {}

void main() {
  group("SseEventRepository", () {
    late MockConnectionService mockConnectionService;
    late StreamController<SseEvent> eventController;

    setUp(() {
      mockConnectionService = MockConnectionService();
      eventController = StreamController<SseEvent>.broadcast();
      when(() => mockConnectionService.events).thenAnswer((_) => eventController.stream);
    });

    tearDown(() async {
      await eventController.close();
    });

    // -------------------------------------------------------------------------
    // 1. sessionActivity defaults to empty map
    // -------------------------------------------------------------------------

    test("sessionActivity defaults to empty map", () {
      final repo = SseEventRepository(mockConnectionService);
      expect(repo.currentSessionActivity, isEmpty);
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 2. sessionActivity emits active session info from projectsSummary event
    // -------------------------------------------------------------------------

    test("sessionActivity emits active session info from projectsSummary event", () async {
      final repo = SseEventRepository(mockConnectionService);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = repo.sessionActivity.listen((activity) {
        if (activity.isNotEmpty) {
          completer.complete(activity);
        }
      });

      // Emit a projectsSummary event with active sessions for "/foo"
      final event = SseEvent(
        data: const SesoriProjectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "/foo",
              activeSessions: [
                ActiveSession(id: "s1", mainAgentRunning: true, childSessionIds: []),
                ActiveSession(id: "s2", mainAgentRunning: false, childSessionIds: []),
              ],
            ),
          ],
        ),
      );
      eventController.add(event);

      final activity = await completer.future;
      expect(activity.keys, equals({"/foo"}));
      expect(activity["/foo"]!.keys, unorderedEquals({"s1", "s2"}));
      expect(activity["/foo"]!["s1"]!.mainAgentRunning, isTrue);
      expect(activity["/foo"]!["s2"]!.mainAgentRunning, isFalse);

      await subscription.cancel();
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 3. sessionActivity excludes projects with no active sessions
    // -------------------------------------------------------------------------

    test("sessionActivity excludes projects with no active sessions", () async {
      final repo = SseEventRepository(mockConnectionService);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = repo.sessionActivity.listen((activity) {
        if (activity.isEmpty) {
          completer.complete(activity);
        }
      });

      // Emit a projectsSummary event with no active sessions for "/bar"
      final event = SseEvent(
        data: const SesoriProjectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "/bar",
              activeSessions: [],
            ),
          ],
        ),
      );
      eventController.add(event);

      final activity = await completer.future;
      expect(activity, isEmpty);

      await subscription.cancel();
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 4. sessionActivity handles multiple projects
    // -------------------------------------------------------------------------

    test("sessionActivity handles multiple projects", () async {
      final repo = SseEventRepository(mockConnectionService);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = repo.sessionActivity.listen((activity) {
        if (activity.length == 2) {
          completer.complete(activity);
        }
      });

      // Emit a projectsSummary event with active sessions for multiple projects.
      final event = SseEvent(
        data: const SesoriProjectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "/foo",
              activeSessions: [
                ActiveSession(id: "s1", mainAgentRunning: false, childSessionIds: []),
              ],
            ),
            ProjectActivitySummary(
              id: "/bar",
              activeSessions: [
                ActiveSession(id: "s2", mainAgentRunning: true, childSessionIds: []),
                ActiveSession(id: "s3", mainAgentRunning: false, childSessionIds: []),
              ],
            ),
          ],
        ),
      );
      eventController.add(event);

      final activity = await completer.future;
      expect(activity.keys, unorderedEquals({"/foo", "/bar"}));
      expect(activity["/foo"]!.keys, equals({"s1"}));
      expect(activity["/bar"]!.keys, unorderedEquals({"s2", "s3"}));

      await subscription.cancel();
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 5. sessionActivity updates when new event arrives
    // -------------------------------------------------------------------------

    test("sessionActivity updates when new event arrives", () async {
      final repo = SseEventRepository(mockConnectionService);

      final activities = <Map<String, Map<String, SessionActivityInfo>>>[];
      final subscription = repo.sessionActivity.listen((activity) {
        if (activity.isNotEmpty) {
          activities.add(activity);
        }
      });

      // First event
      eventController.add(
        SseEvent(
          data: const SesoriProjectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "/foo",
                activeSessions: [
                  ActiveSession(id: "s1", mainAgentRunning: false, childSessionIds: []),
                ],
              ),
            ],
          ),
        ),
      );

      // Wait for first emission
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Second event with updated data
      eventController.add(
        SseEvent(
          data: const SesoriProjectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "/foo",
                activeSessions: [
                  ActiveSession(id: "s1", mainAgentRunning: false, childSessionIds: []),
                  ActiveSession(id: "s2", mainAgentRunning: true, childSessionIds: []),
                ],
              ),
            ],
          ),
        ),
      );

      // Wait for second emission
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(activities.length, 2);
      expect(activities[0].keys, equals({"/foo"}));
      expect(activities[0]["/foo"]!.keys, equals({"s1"}));
      expect(activities[1].keys, equals({"/foo"}));
      expect(activities[1]["/foo"]!.keys, unorderedEquals({"s1", "s2"}));

      await subscription.cancel();
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 6. projectActivity defaults to empty map
    // -------------------------------------------------------------------------

    test("projectActivity defaults to empty map", () {
      final repo = SseEventRepository(mockConnectionService);
      expect(repo.currentProjectActivity, isEmpty);
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 7. projectActivity emits active session counts from projectsSummary event
    // -------------------------------------------------------------------------

    test("projectActivity emits active session counts from projectsSummary event", () async {
      final repo = SseEventRepository(mockConnectionService);

      final completer = Completer<Map<String, int>>();
      final subscription = repo.projectActivity.listen((activity) {
        if (activity.isNotEmpty) {
          completer.complete(activity);
        }
      });

      // Emit a projectsSummary event with active sessions for "/foo"
      final event = SseEvent(
        data: const SesoriProjectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "/foo",
              activeSessions: [
                ActiveSession(id: "s1", mainAgentRunning: false, childSessionIds: []),
                ActiveSession(id: "s2", mainAgentRunning: true, childSessionIds: []),
                ActiveSession(id: "s3", mainAgentRunning: false, childSessionIds: []),
              ],
            ),
          ],
        ),
      );
      eventController.add(event);

      final activity = await completer.future;
      expect(activity, {"/foo": 3});

      await subscription.cancel();
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 8. projectActivity excludes projects with no active sessions
    // -------------------------------------------------------------------------

    test("projectActivity excludes projects with no active sessions", () async {
      final repo = SseEventRepository(mockConnectionService);

      final completer = Completer<Map<String, int>>();
      final subscription = repo.projectActivity.listen((activity) {
        if (activity.isEmpty) {
          completer.complete(activity);
        }
      });

      // Emit a projectsSummary event with no active sessions for "/bar"
      final event = SseEvent(
        data: const SesoriProjectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "/bar",
              activeSessions: [],
            ),
          ],
        ),
      );
      eventController.add(event);

      final activity = await completer.future;
      expect(activity, isEmpty);

      await subscription.cancel();
      repo.onDispose();
    });

    // -------------------------------------------------------------------------
    // 9. Non-projectsSummary events are ignored
    // -------------------------------------------------------------------------

    test("non-projectsSummary events are ignored", () async {
      final repo = SseEventRepository(mockConnectionService);

      var emissionCount = 0;
      final subscription = repo.sessionActivity.listen((_) => emissionCount++);

      // Wait for initial seeded value
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final initialCount = emissionCount;

      // Emit a non-projectsSummary event (should be ignored)
      final event = SseEvent(
        data: const SesoriSessionCreated(
          info: Session(
            id: "s1",
            projectID: "p1",
            directory: "/foo",
            time: SessionTime(created: 1, updated: 2),
          ),
        ),
      );
      eventController.add(event);

      // Wait a bit to ensure no additional emission
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should not have increased from initial count
      expect(emissionCount, initialCount);

      await subscription.cancel();
      repo.onDispose();
    });
  });
}
