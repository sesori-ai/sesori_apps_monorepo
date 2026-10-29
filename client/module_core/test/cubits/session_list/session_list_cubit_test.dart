import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_cubit.dart";
import "package:sesori_dart_core/src/repositories/models/session_cleanup_rejection.dart" as domain;
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/models/session_cleanup_outcome.dart";
import "package:sesori_dart_core/src/services/session_cleanup_service.dart";
import "package:sesori_dart_core/src/services/session_list_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionListCubit", () {
    late MockSessionRepository mockSessionService;
    late MockProjectRepository mockProjectRepository;
    late SessionListService sessionListService;
    late MockConnectionService mockConnectionService;
    late MockSseEventTracker mockSseEventTracker;
    late FakeSessionUnseenTracker fakeSessionUnseenTracker;
    late MockFailureReporter mockFailureReporter;
    late StreamController<SseEvent> eventController;
    late BehaviorSubject<ConnectionStatus> statusController;

    const projectId = "project-1";

    setUp(() {
      mockSessionService = MockSessionRepository();
      mockProjectRepository = MockProjectRepository();
      sessionListService = SessionListService(
        repository: mockProjectRepository,
      );
      mockConnectionService = MockConnectionService();
      mockSseEventTracker = MockSseEventTracker();
      fakeSessionUnseenTracker = FakeSessionUnseenTracker();
      mockFailureReporter = MockFailureReporter();
      eventController = StreamController<SseEvent>.broadcast();
      statusController = BehaviorSubject<ConnectionStatus>.seeded(
        const ConnectionStatus.disconnected(),
      );
      // Must be stubbed before any cubit is built — constructor subscribes immediately.
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

    SessionListCubit buildCubit({required List<Session> sessions}) {
      final cubit = SessionListCubit(
        sessions: sessions,
        sessionRepository: mockSessionService,
        sessionCleanupService: SessionCleanupService(repository: mockSessionService),
        sessionListService: sessionListService,
        connectionService: mockConnectionService,
        sseEventTracker: mockSseEventTracker,
        sessionUnseenTracker: fakeSessionUnseenTracker,
        projectId: projectId,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    Future<void> emitEvent(SesoriSseEvent data) async {
      eventController.add(SseEvent(data: data));
      await Future<void>.delayed(Duration.zero);
    }

    void verifyNoListRequests() {
      verifyNever(() => mockProjectRepository.listSessions(projectId: any(named: "projectId")));
    }

    test("shows the given sessions, newest first and without archived ones", () {
      final cubit = buildCubit(
        sessions: [
          testSession(id: "older").copyWith(time: const SessionTime(created: 1, updated: 10, archived: null)),
          testSession(id: "archived", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
          testSession(id: "newer").copyWith(time: const SessionTime(created: 1, updated: 20, archived: null)),
        ],
      );

      expect(cubit.state.sessions.map((session) => session.id), ["newer", "older"]);
      verifyNoListRequests();
    });

    test("updateActionSession adds a menu target without replacing the other rows", () {
      final cubit = buildCubit(sessions: [testSession(id: "s1")]);

      cubit.updateActionSession(
        session: testSession(id: "s2", title: "Later"),
      );

      expect(cubit.state.sessions.map((session) => session.id), containsAll(["s1", "s2"]));
    });

    test("reconnect and stale signals make no requests", () async {
      final cubit = buildCubit(sessions: [testSession(id: "s1")]);

      statusController.add(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token", bridgeId: null),
          health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
        ),
      );
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(Duration.zero);

      verifyNoListRequests();
      expect(cubit.state.sessions.single.id, "s1");
    });

    group("session events", () {
      test("session.updated updates and reorders a held session", () async {
        final cubit = buildCubit(
          sessions: [
            testSession(id: "A").copyWith(time: const SessionTime(created: 1, updated: 30, archived: null)),
            testSession(id: "B").copyWith(time: const SessionTime(created: 1, updated: 20, archived: null)),
          ],
        );

        await emitEvent(
          SesoriSseEvent.sessionUpdated(
            info: testSession(
              id: "B",
              title: "Updated",
            ).copyWith(time: const SessionTime(created: 1, updated: 90, archived: null)),
          ),
        );

        expect(cubit.state.sessions.map((session) => session.id), ["B", "A"]);
        expect(cubit.state.sessions.first.title, "Updated");
      });

      test("session.updated for a session it does not hold is ignored", () async {
        final cubit = buildCubit(sessions: [testSession(id: "s1")]);
        final states = <Object>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);

        await emitEvent(SesoriSseEvent.sessionUpdated(info: testSession(id: "other")));

        expect(states, isEmpty);
        expect(cubit.state.sessions.single.id, "s1");
      });

      test("session.created is ignored", () async {
        final cubit = buildCubit(sessions: [testSession(id: "s1")]);

        await emitEvent(SesoriSseEvent.sessionCreated(info: testSession(id: "s2")));

        expect(cubit.state.sessions.single.id, "s1");
      });

      test("session.deleted removes a held session", () async {
        final cubit = buildCubit(
          sessions: [
            testSession(id: "s1"),
            testSession(id: "s2"),
          ],
        );

        await emitEvent(SesoriSseEvent.sessionDeleted(info: testSession(id: "s1")));

        expect(cubit.state.sessions.single.id, "s2");
      });

      test("events for a different project are ignored", () async {
        final foreign = testSession(id: "s1").copyWith(projectID: "project-other", title: "Foreign");
        final cubit = buildCubit(
          sessions: [testSession(id: "s1", title: "Mine")],
        );

        await emitEvent(SesoriSseEvent.sessionUpdated(info: foreign));
        await emitEvent(SesoriSseEvent.sessionDeleted(info: foreign));

        expect(cubit.state.sessions.single.title, "Mine");
      });
    });

    group("activity", () {
      test("activeSessionIds follows this project's activity only", () async {
        const running = SessionActivityInfo(
          mainAgentRunning: true,
          isRunning: true,
          lastUserActivityAt: null,
          updatedAt: null,
        );
        mockSseEventTracker.emitSessionActivity({
          projectId: {"s1": running},
          "project-2": {"s2": running},
        });
        final cubit = buildCubit(
          sessions: [
            testSession(id: "s1"),
            testSession(id: "s2"),
          ],
        );
        expect(cubit.state.activeSessionIds, {"s1": running});

        mockSseEventTracker.emitSessionActivity({
          projectId: {"s1": running, "s2": running},
        });
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.activeSessionIds, {"s1": running, "s2": running});
      });

      test("running sessions lead the list", () {
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "C": const SessionActivityInfo(
              mainAgentRunning: true,
              isRunning: true,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
            "A": const SessionActivityInfo(
              isRetrying: true,
              isRunning: true,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
          },
        });
        final cubit = buildCubit(
          sessions: [
            testSession(id: "C"),
            testSession(id: "B"),
            testSession(id: "A"),
          ],
        );

        expect(cubit.state.sessions.map((session) => session.id), ["A", "C", "B"]);
      });

      test("live tracker updates re-emit the merged unseen map", () async {
        final cubit = buildCubit(sessions: [testSession(id: "s1")]);
        expect(cubit.state.unseenBySessionId["s1"], isFalse);

        fakeSessionUnseenTracker.emitSessionUnseen({
          projectId: {"s1": (unseen: true, lastUserActivityAt: null)},
        });
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.unseenBySessionId["s1"], isTrue);
      });
    });

    group("delete", () {
      test("optimistically removes the session and returns the outcome", () async {
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: false,
            deleteSessionFolder: true,
            force: false,
          ),
        ).thenAnswer((_) async => ApiResponse<void>.success(null));
        final cubit = buildCubit(sessions: [testSession(id: "s1")]);

        final result = await cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: false,
          deleteSessionFolder: true,
          force: false,
        );

        expect(result, SessionCleanupOutcome.completed);
        expect(cubit.state.sessions, isEmpty);
        verifyNoListRequests();
      });

      test("stores a cleanup rejection and restores the session", () async {
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteSessionFolder: any(named: "deleteSessionFolder"),
            force: any(named: "force"),
          ),
        ).thenThrow(
          _cleanupRejected(const CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main")),
        );
        final cubit = buildCubit(sessions: [testSession(id: "s1")]);

        final result = await cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: true,
          deleteSessionFolder: false,
          force: false,
        );

        expect(result, isNull);
        expect(
          cubit.lastCleanupRejection?.issues.first,
          const CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main"),
        );
        expect(cubit.state.sessions.single.id, "s1");
      });

      test("restores the session when the request fails", () async {
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: false,
            deleteSessionFolder: false,
            force: false,
          ),
        ).thenAnswer((_) async => ApiResponse<void>.error(ApiError.generic()));
        final cubit = buildCubit(sessions: [testSession(id: "s1")]);

        final result = await cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: false,
          deleteSessionFolder: false,
          force: false,
        );

        expect(result, isNull);
        expect(cubit.state.sessions.single.id, "s1");
        verifyNoListRequests();
      });
    });

    group("rename", () {
      test("updates the title before the request completes and keeps it on success", () async {
        final reply = Completer<ApiResponse<Session>>();
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "New Title"),
        ).thenAnswer((_) => reply.future);
        final cubit = buildCubit(
          sessions: [testSession(id: "s1", title: "Original")],
        );

        final rename = cubit.renameSession(sessionId: "s1", title: "New Title");
        expect(cubit.state.sessions.single.title, "New Title");

        reply.complete(ApiResponse.success(testSession(id: "s1", title: "New Title")));
        expect(await rename, isTrue);
        expect(cubit.state.sessions.single.title, "New Title");
        verifyNoListRequests();
      });

      test("restores the previous title when the request fails", () async {
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "New Title"),
        ).thenAnswer((_) async => ApiResponse<Session>.error(ApiError.generic()));
        final cubit = buildCubit(
          sessions: [testSession(id: "s1", title: "Original")],
        );

        expect(await cubit.renameSession(sessionId: "s1", title: "New Title"), isFalse);

        expect(cubit.state.sessions.single.title, "Original");
      });

      test("restores the previous title when the request throws", () async {
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "New Title"),
        ).thenThrow(StateError("transport"));
        final cubit = buildCubit(
          sessions: [testSession(id: "s1", title: "Original")],
        );

        expect(await cubit.renameSession(sessionId: "s1", title: "New Title"), isFalse);

        expect(cubit.state.sessions.single.title, "Original");
      });

      test("returns false for a session it does not hold", () async {
        final cubit = buildCubit(sessions: [testSession(id: "s1")]);

        expect(await cubit.renameSession(sessionId: "other", title: "New Title"), isFalse);

        verifyNever(() => mockSessionService.renameSession(sessionId: "other", title: "New Title"));
      });

      test("restores a null committed title after two overlapping failures", () async {
        final firstReply = Completer<ApiResponse<Session>>();
        final secondReply = Completer<ApiResponse<Session>>();
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "First title"),
        ).thenAnswer((_) => firstReply.future);
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "Second title"),
        ).thenAnswer((_) => secondReply.future);
        final cubit = buildCubit(sessions: [testSession(id: "s1", title: null)]);

        final firstRename = cubit.renameSession(sessionId: "s1", title: "First title");
        final secondRename = cubit.renameSession(sessionId: "s1", title: "Second title");
        expect(cubit.state.sessions.single.title, "Second title");

        firstReply.complete(ApiResponse<Session>.error(ApiError.generic()));
        expect(await firstRename, isFalse);
        expect(cubit.state.sessions.single.title, "Second title");

        secondReply.complete(ApiResponse<Session>.error(ApiError.generic()));
        expect(await secondRename, isFalse);
        expect(cubit.state.sessions.single.title, isNull);
      });

      test("restores an older in-flight success after newer renames fail", () async {
        final original = testSession(id: "s1", title: "Original");
        final firstReply = Completer<ApiResponse<Session>>();
        final secondReply = Completer<ApiResponse<Session>>();
        final thirdReply = Completer<ApiResponse<Session>>();
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "First title"),
        ).thenAnswer((_) => firstReply.future);
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "Second title"),
        ).thenAnswer((_) => secondReply.future);
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "Third title"),
        ).thenAnswer((_) => thirdReply.future);
        final cubit = buildCubit(sessions: [original]);

        final firstRename = cubit.renameSession(sessionId: "s1", title: "First title");
        final secondRename = cubit.renameSession(sessionId: "s1", title: "Second title");
        secondReply.complete(ApiResponse<Session>.error(ApiError.generic()));
        expect(await secondRename, isFalse);
        expect(cubit.state.sessions.single.title, "First title");

        final thirdRename = cubit.renameSession(sessionId: "s1", title: "Third title");
        firstReply.complete(ApiResponse.success(original.copyWith(title: "First title")));
        expect(await firstRename, isTrue);
        expect(cubit.state.sessions.single.title, "Third title");

        thirdReply.complete(ApiResponse<Session>.error(ApiError.generic()));
        expect(await thirdRename, isFalse);
        expect(cubit.state.sessions.single.title, "First title");
      });

      test("restores the latest confirmed title when a newer rename fails", () async {
        final original = testSession(id: "s1", title: "Original");
        final firstReply = Completer<ApiResponse<Session>>();
        final secondReply = Completer<ApiResponse<Session>>();
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "First title"),
        ).thenAnswer((_) => firstReply.future);
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "Second title"),
        ).thenAnswer((_) => secondReply.future);
        final cubit = buildCubit(sessions: [original]);

        final firstRename = cubit.renameSession(sessionId: "s1", title: "First title");
        final secondRename = cubit.renameSession(sessionId: "s1", title: "Second title");

        firstReply.complete(ApiResponse.success(original.copyWith(title: "First title")));
        expect(await firstRename, isTrue);
        expect(cubit.state.sessions.single.title, "Second title");

        secondReply.complete(ApiResponse<Session>.error(ApiError.generic()));
        expect(await secondRename, isFalse);
        expect(cubit.state.sessions.single.title, "First title");
      });
    });

    group("mark read or unread", () {
      test("applies the change to the tracker optimistically", () async {
        when(
          () => mockSessionService.markSessionSeen(sessionId: "s1", read: true),
        ).thenAnswer((_) async => ApiResponse.success(null));
        final cubit = buildCubit(sessions: [testSession(id: "s1", unseen: true)]);
        expect(cubit.state.unseenBySessionId["s1"], isTrue);

        await cubit.markSessionSeen(sessionId: "s1", read: true);
        await Future<void>.delayed(Duration.zero);

        expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"]?.unseen, isFalse);
        expect(cubit.state.unseenBySessionId["s1"], isFalse);
        verify(() => mockSessionService.markSessionSeen(sessionId: "s1", read: true)).called(1);
      });

      test("a failed request restores the tracker's previous value", () async {
        when(
          () => mockSessionService.markSessionSeen(sessionId: "s1", read: false),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        fakeSessionUnseenTracker.emitSessionUnseen({
          projectId: {"s1": (unseen: false, lastUserActivityAt: 42)},
        });
        final cubit = buildCubit(sessions: [testSession(id: "s1", unseen: true)]);
        expect(cubit.state.unseenBySessionId["s1"], isFalse);

        await cubit.markSessionSeen(sessionId: "s1", read: false);
        await Future<void>.delayed(Duration.zero);

        expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"], (
          unseen: false,
          lastUserActivityAt: 42,
        ));
        expect(cubit.state.unseenBySessionId["s1"], isFalse);
        verifyNoListRequests();
      });

      test("a thrown request drops an entry the tracker did not have", () async {
        when(
          () => mockSessionService.markSessionSeen(sessionId: "s1", read: true),
        ).thenThrow(StateError("transport"));
        final cubit = buildCubit(sessions: [testSession(id: "s1", unseen: true)]);

        await cubit.markSessionSeen(sessionId: "s1", read: true);
        await Future<void>.delayed(Duration.zero);

        expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?.containsKey("s1"), isFalse);
        expect(cubit.state.unseenBySessionId["s1"], isTrue);
        verifyNoListRequests();
      });
    });

    test("action scope close retains a dialog through rename, mark rollback and delete", () async {
      final session = testSession(id: "s1", unseen: true);
      final renameReply = Completer<ApiResponse<Session>>();
      final markReply = Completer<ApiResponse<void>>();
      final deleteReply = Completer<ApiResponse<void>>();
      when(
        () => mockSessionService.renameSession(sessionId: session.id, title: "Renamed"),
      ).thenAnswer((_) => renameReply.future);
      when(
        () => mockSessionService.markSessionSeen(sessionId: session.id, read: true),
      ).thenAnswer((_) => markReply.future);
      when(
        () => mockSessionService.deleteSession(
          sessionId: session.id,
          deleteWorktree: true,
          deleteSessionFolder: false,
          force: false,
        ),
      ).thenAnswer((_) => deleteReply.future);
      final cubit = buildCubit(sessions: [session]);

      final releaseDialog = cubit.retainActionScope();
      final close = cubit.close();
      expect(cubit.isClosed, isFalse);
      final rename = cubit.renameSession(sessionId: session.id, title: "Renamed");
      final mutation = cubit.markSessionSeen(sessionId: session.id, read: true);
      final deletion = cubit.deleteSession(
        sessionId: session.id,
        deleteWorktree: true,
        deleteSessionFolder: false,
        force: false,
      );
      releaseDialog();
      releaseDialog();
      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?[session.id]?.unseen, isFalse);

      markReply.complete(ApiResponse.error(ApiError.generic()));
      await mutation;
      expect(cubit.isClosed, isFalse);
      deleteReply.complete(ApiResponse.success(null));
      expect(await deletion, SessionCleanupOutcome.completed);
      expect(cubit.isClosed, isFalse);
      renameReply.complete(ApiResponse.error(ApiError.generic()));
      expect(await rename, isFalse);
      await close;

      expect(cubit.isClosed, isTrue);
      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?.containsKey(session.id), isFalse);
      verifyNoListRequests();
    });
  });
}

domain.SessionCleanupRejectedException _cleanupRejected(CleanupIssue issue) {
  final rejection = SessionCleanupRejection(issues: [issue]);
  return domain.SessionCleanupRejectedException(
    rejection: domain.SessionCleanupRejection(issues: rejection.issues),
    innerError: SessionCleanupApiRejectedException(rejection: rejection),
  );
}
