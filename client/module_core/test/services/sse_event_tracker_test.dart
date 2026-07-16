import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockConnectionService extends Mock implements ConnectionService {}

class MockFailureReporter extends Mock implements FailureReporter {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  group("SseEventTracker", () {
    late MockConnectionService mockConnectionService;
    late MockFailureReporter mockFailureReporter;
    late StreamController<SseEvent> eventController;
    late BehaviorSubject<ConnectionStatus> statusController;
    late bool throwOnEventCancel;

    setUp(() {
      mockConnectionService = MockConnectionService();
      mockFailureReporter = MockFailureReporter();
      throwOnEventCancel = false;
      eventController = StreamController<SseEvent>(
        onCancel: () async {
          if (throwOnEventCancel) {
            throw StateError("event subscription cancellation failed");
          }
        },
      );
      statusController = BehaviorSubject.seeded(const ConnectionStatus.disconnected());
      when(() => mockConnectionService.events).thenAnswer((_) => eventController.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
      when(
        () => mockFailureReporter.recordFailure(
          error: any(named: "error"),
          stackTrace: any(named: "stackTrace"),
          uniqueIdentifier: any(named: "uniqueIdentifier"),
          fatal: any(named: "fatal"),
          reason: any(named: "reason"),
          information: any(named: "information"),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await eventController.close();
      await statusController.close();
    });

    // -------------------------------------------------------------------------
    // 1. sessionActivity defaults to empty map
    // -------------------------------------------------------------------------

    test("sessionActivity defaults to empty map", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);
      expect(tracker.currentSessionActivity, isEmpty);
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 2. sessionActivity emits active session info from projectsSummary event
    // -------------------------------------------------------------------------

    test("sessionActivity emits active session info from projectsSummary event", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = tracker.sessionActivity.listen((activity) {
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
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 3. sessionActivity excludes projects with no active sessions
    // -------------------------------------------------------------------------

    test("sessionActivity excludes projects with no active sessions", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = tracker.sessionActivity.listen((activity) {
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
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 4. sessionActivity handles multiple projects
    // -------------------------------------------------------------------------

    test("sessionActivity handles multiple projects", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = tracker.sessionActivity.listen((activity) {
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
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 5. sessionActivity updates when new event arrives
    // -------------------------------------------------------------------------

    test("sessionActivity updates when new event arrives", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final activities = <Map<String, Map<String, SessionActivityInfo>>>[];
      final subscription = tracker.sessionActivity.listen((activity) {
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
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 6. projectActivity defaults to empty map
    // -------------------------------------------------------------------------

    test("projectActivity defaults to empty map", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);
      expect(tracker.currentProjectActivity, isEmpty);
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 7. projectActivity emits active session counts from projectsSummary event
    // -------------------------------------------------------------------------

    test("projectActivity emits active session counts from projectsSummary event", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, int>>();
      final subscription = tracker.projectActivity.listen((activity) {
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
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 8. projectActivity excludes projects with no active sessions
    // -------------------------------------------------------------------------

    test("projectActivity excludes projects with no active sessions", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, int>>();
      final subscription = tracker.projectActivity.listen((activity) {
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
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 9. Non-projectsSummary events are ignored
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // 10. awaitingInput true is mapped to SessionActivityInfo
    // -------------------------------------------------------------------------

    test("sessionActivity maps awaitingInput true from ActiveSession", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = tracker.sessionActivity.listen((activity) {
        if (activity.isNotEmpty) {
          completer.complete(activity);
        }
      });

      final event = SseEvent(
        data: const SesoriProjectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "/foo",
              activeSessions: [
                ActiveSession(id: "s1", mainAgentRunning: true, awaitingInput: true),
              ],
            ),
          ],
        ),
      );
      eventController.add(event);

      final activity = await completer.future;
      expect(activity["/foo"]!["s1"]!.awaitingInput, isTrue);
      expect(activity["/foo"]!["s1"]!.mainAgentRunning, isTrue);

      await subscription.cancel();
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 11. awaitingInput false is mapped to SessionActivityInfo
    // -------------------------------------------------------------------------

    test("sessionActivity maps awaitingInput false from ActiveSession", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, Map<String, SessionActivityInfo>>>();
      final subscription = tracker.sessionActivity.listen((activity) {
        if (activity.isNotEmpty) {
          completer.complete(activity);
        }
      });

      final event = SseEvent(
        data: const SesoriProjectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "/foo",
              activeSessions: [
                ActiveSession(id: "s1", mainAgentRunning: true, awaitingInput: false),
              ],
            ),
          ],
        ),
      );
      eventController.add(event);

      final activity = await completer.future;
      expect(activity["/foo"]!["s1"]!.awaitingInput, isFalse);
      expect(activity["/foo"]!["s1"]!.mainAgentRunning, isTrue);

      await subscription.cancel();
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 12. Non-projectsSummary events are ignored
    // -------------------------------------------------------------------------

    test("non-projectsSummary events are ignored", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      var emissionCount = 0;
      final subscription = tracker.sessionActivity.listen((_) => emissionCount++);

      // Wait for initial seeded value
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final initialCount = emissionCount;

      // Emit a non-projectsSummary event (should be ignored)
      final event = SseEvent(
        data: const SesoriSessionCreated(
          info: Session(
            branchName: null,
            id: "s1",
            pluginId: legacyMissingPluginId,
            projectID: "p1",
            directory: "/foo",
            parentID: null,
            title: null,
            time: SessionTime(created: 1, updated: 2, archived: null),
            pullRequest: null,
            promptDefaults: null,
          ),
        ),
      );
      eventController.add(event);

      // Wait a bit to ensure no additional emission
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should not have increased from initial count
      expect(emissionCount, initialCount);

      await subscription.cancel();
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 13. projectTimestampUpdates emits complete project updates
    // -------------------------------------------------------------------------

    test("projectTimestampUpdates emits complete project.updated events", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      final completer = Completer<Map<String, int>>();
      final subscription = tracker.projectTimestampUpdates.listen((update) {
        if (update.isNotEmpty) {
          completer.complete(update);
        }
      });

      eventController.add(
        SseEvent(
          data: const SesoriProjectUpdated(
            projectID: "project-1",
            updatedAt: 12345,
          ),
        ),
      );

      final update = await completer.future;
      expect(update, {"project-1": 12345});

      await subscription.cancel();
      await tracker.onDispose();
    });

    test("projectTimestampUpdates retains cumulative per-project maxima", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);
      final updates = <Map<String, int>>[];
      final subscription = tracker.projectTimestampUpdates.skip(1).listen(updates.add);

      eventController.add(
        SseEvent(
          data: const SesoriProjectUpdated(projectID: "project-1", updatedAt: 200),
        ),
      );
      eventController.add(
        SseEvent(
          data: const SesoriProjectUpdated(projectID: "project-2", updatedAt: 300),
        ),
      );
      eventController.add(
        SseEvent(
          data: const SesoriProjectUpdated(projectID: "project-1", updatedAt: 100),
        ),
      );
      eventController.add(
        SseEvent(
          data: const SesoriProjectUpdated(projectID: "project-1", updatedAt: 200),
        ),
      );
      eventController.add(
        SseEvent(
          data: const SesoriProjectUpdated(projectID: "project-1", updatedAt: 400),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(updates, [
        {"project-1": 200},
        {"project-1": 200, "project-2": 300},
        {"project-1": 400, "project-2": 300},
      ]);
      expect(tracker.currentProjectTimestampUpdates, {"project-1": 400, "project-2": 300});

      await subscription.cancel();
      await tracker.onDispose();
    });

    test("projectTimestampUpdates clears on explicit disconnect", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      eventController.add(
        SseEvent(
          data: const SesoriProjectUpdated(projectID: "project-1", updatedAt: 400),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tracker.currentProjectTimestampUpdates, {"project-1": 400});

      statusController.add(const ConnectionStatus.disconnected());
      await Future<void>.delayed(Duration.zero);

      expect(tracker.currentProjectTimestampUpdates, isEmpty);
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 14. projectTimestampUpdates ignores incomplete project.updated events
    // -------------------------------------------------------------------------

    test("projectTimestampUpdates ignores incomplete project.updated events", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      var emissionCount = 0;
      final subscription = tracker.projectTimestampUpdates.listen((_) => emissionCount++);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final initialCount = emissionCount;

      eventController.add(
        SseEvent(
          data: const SesoriSseEvent.projectUpdated(projectID: null, updatedAt: null),
        ),
      );
      eventController.add(
        SseEvent(
          data: const SesoriSseEvent.projectUpdated(projectID: null, updatedAt: 12345),
        ),
      );
      eventController.add(
        SseEvent(
          data: const SesoriSseEvent.projectUpdated(projectID: "project-1", updatedAt: null),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissionCount, initialCount);

      await subscription.cancel();
      await tracker.onDispose();
    });

    // -------------------------------------------------------------------------
    // 15. projectTimestampUpdates ignores non-project.updated events
    // -------------------------------------------------------------------------

    test("projectTimestampUpdates ignores non-project.updated events", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);

      var emissionCount = 0;
      final subscription = tracker.projectTimestampUpdates.listen((_) => emissionCount++);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final initialCount = emissionCount;

      eventController.add(
        SseEvent(
          data: const SesoriProjectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "/foo",
                activeSessions: [],
              ),
            ],
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissionCount, initialCount);

      await subscription.cancel();
      await tracker.onDispose();
    });

    test("onDispose closes every exposed stream", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);
      final projectActivityDone = tracker.projectActivity.drain<void>();
      final sessionActivityDone = tracker.sessionActivity.drain<void>();
      final timestampUpdatesDone = tracker.projectTimestampUpdates.drain<void>();

      await tracker.onDispose();

      await Future.wait([
        projectActivityDone,
        sessionActivityDone,
        timestampUpdatesDone,
      ]);
    });

    test("onDispose closes every exposed stream when event cancellation throws", () async {
      final tracker = SseEventTracker(mockConnectionService, failureReporter: mockFailureReporter);
      var closedStreamCount = 0;
      tracker.projectActivity.listen((_) {}, onDone: () => closedStreamCount++);
      tracker.sessionActivity.listen((_) {}, onDone: () => closedStreamCount++);
      tracker.projectTimestampUpdates.listen((_) {}, onDone: () => closedStreamCount++);
      throwOnEventCancel = true;

      await expectLater(tracker.onDispose(), throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);

      expect(closedStreamCount, 3);
    });
  });
}
