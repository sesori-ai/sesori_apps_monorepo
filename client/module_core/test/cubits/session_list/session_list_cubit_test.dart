import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_state.dart";
import "package:sesori_dart_core/src/repositories/models/session_cleanup_rejection.dart" as domain;
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/models/session_cleanup_outcome.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/src/services/session_cleanup_service.dart";
import "package:sesori_dart_core/src/services/session_list_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionListCubit", () {
    late MockSessionRepository mockSessionService;
    late FakeCatalogRescanService fakeCatalogRescanService;
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
      fakeCatalogRescanService = FakeCatalogRescanService();
      mockSessionService = MockSessionRepository();
      mockProjectRepository = MockProjectRepository();
      sessionListService = SessionListService(
        repository: mockProjectRepository,
        activityCalculator: const SessionActivityCalculator(),
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

    /// Convenience factory — stubs must be set up before calling this.
    SessionListCubit buildCubit({List<Session> sessions = const []}) => SessionListCubit(
      sessions: sessions,
      sessionRepository: mockSessionService,
      sessionCleanupService: SessionCleanupService(repository: mockSessionService),
      sessionListService: sessionListService,
      connectionService: mockConnectionService,
      sseEventTracker: mockSseEventTracker,
      sessionUnseenTracker: fakeSessionUnseenTracker,
      projectId: projectId,
      failureReporter: mockFailureReporter,
      catalogRescanService: fakeCatalogRescanService,
    );

    /// The constructor never fetches. This starts the refresh a list performs
    /// when it first opens, so the fetched sessions are the first emission.
    SessionListCubit buildRefreshingCubit() {
      final cubit = buildCubit();
      unawaited(cubit.refreshSessions());
      return cubit;
    }

    test("seeded sessions show without a fetch and renames refresh the list", () async {
      final session = testSession(title: "Original");
      when(() => mockSessionService.renameSession(sessionId: session.id, title: "Renamed"))
          .thenAnswer((_) async => ApiResponse.success(session.copyWith(title: "Renamed")));
      final cubit = buildCubit(sessions: [session]);
      expect(cubit.state.sessions.single.id, session.id);
      verifyNever(
        () => mockProjectRepository.listSessions(
          projectId: any(named: "projectId"),
        ),
      );
      when(
        () => mockProjectRepository.listSessions(projectId: projectId),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [session.copyWith(title: "Renamed")])));
      expect(await cubit.renameSession(sessionId: session.id, title: "Renamed"), isTrue);
      expect(cubit.state.sessions.single.title, "Renamed");
      // A later successful sidebar retry can discover a row this scope never
      // received. Refresh only that menu target, preserving the other row.
      final later = testSession(id: "later-session", title: "Discovered later");
      cubit.updateActionSession(session: later);
      expect(
        cubit.state.sessions.map((session) => session.id),
        containsAll([session.id, later.id]),
      );
      when(() => mockSessionService.renameSession(sessionId: later.id, title: "Later renamed"))
          .thenAnswer((_) async => ApiResponse.success(later.copyWith(title: "Later renamed")));
      when(() => mockProjectRepository.listSessions(projectId: projectId)).thenAnswer(
        (_) async => ApiResponse.success(
          SessionListResponse(
            items: [
              session.copyWith(title: "Renamed"),
              later.copyWith(title: "Later renamed"),
            ],
          ),
        ),
      );
      expect(await cubit.renameSession(sessionId: later.id, title: "Later renamed"), isTrue);
      await cubit.close();
      verify(() => mockProjectRepository.listSessions(projectId: projectId)).called(2);
    });

    blocTest<SessionListCubit, SessionListState>(
      "REST session list is sorted by updated timestamp descending",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "untitled").copyWith(
                  time: const SessionTime(created: 1000, updated: 9000, archived: null),
                ),
                testSession(id: "B", title: "bravo").copyWith(
                  time: const SessionTime(created: 1000, updated: 4000, archived: null),
                ),
                testSession(id: "a", title: "alpha").copyWith(
                  time: const SessionTime(created: 1000, updated: 1000, archived: null),
                ),
                testSession(id: "A", title: "Alpha").copyWith(
                  time: const SessionTime(created: 1000, updated: 3000, archived: null),
                ),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      expect: () => [
        isA<SessionListState>().having(
          (state) => state.sessions.map((session) => session.id).toList(),
          "session order",
          ["untitled", "B", "A", "a"],
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "running activity received after REST creates a timestamp-ordered prefix",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "C", title: "Charlie"),
                testSession(id: "B", title: "Bravo"),
                testSession(id: "A", title: "Alpha"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (_) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "C": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "A": const SessionActivityInfo(isRetrying: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>().having(
          (state) => state.sessions.map((session) => session.id).toList(),
          "session order",
          ["A", "C", "B"],
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "running activity received before REST uses timestamps when sessions arrive",
      build: () {
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "C": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "A": const SessionActivityInfo(isRetrying: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "C", title: "Charlie"),
                testSession(id: "B", title: "Bravo"),
                testSession(id: "A", title: "Alpha"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      expect: () => [
        isA<SessionListState>().having(
          (state) => state.sessions.map((session) => session.id).toList(),
          "session order",
          ["A", "C", "B"],
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "refreshSessions: replaces the seeded sessions with the server list",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
        return buildCubit(sessions: [testSession(id: "s1")]);
      },
      act: (cubit) async {
        expect(await cubit.refreshSessions(), isTrue);
      },
      expect: () => [
        isA<SessionListState>().having(
          (s) => s.sessions,
          "sessions",
          isEmpty,
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "refreshSessions: keeps archived sessions out of the visible list",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(
                  id: "archived",
                  archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
                ),
                testSession(id: "active"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      expect: () => [
        isA<SessionListState>().having(
          (s) => s.sessions.map((session) => session.id).toList(),
          "visible sessions",
          ["active"],
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // deleteSession success — optimistic removal, API succeeds, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "deleteSession: optimistically removes session and returns true on API success",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            force: any(named: "force"),
          ),
        ).thenAnswer((_) async => ApiResponse<void>.success(null));
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: false,
          force: false,
        );
        expect(result, SessionCleanupOutcome.completed);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>().having(
          (s) => s.sessions,
          "sessions after delete",
          isEmpty,
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "deleteSession: stores cleanup rejection and restores session on 409",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            force: any(named: "force"),
          ),
        ).thenThrow(
          _cleanupRejected(const CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main")),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: true,
          force: false,
        );
        expect(result, isNull);
        expect(
          cubit.lastCleanupRejection?.issues.first,
          const CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main"),
        );
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>().having((s) => s.sessions, "sessions after optimistic delete", isEmpty),
        isA<SessionListState>().having((s) => s.sessions.length, "sessions after rollback", 1),
      ],
    );

    // -------------------------------------------------------------------------
    // refreshSessions success — emits the new sessions, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "refreshSessions: emits the refreshed sessions and returns true",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "Original")],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Return different data on refresh to prove new data is used.
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "Refreshed")],
            ),
          ),
        );
        final result = await cubit.refreshSessions();
        expect(result, isTrue);
      },
      skip: 1, // skip the first refresh's emission
      expect: () => [
        isA<SessionListState>().having(
          (s) => s.sessions.first.title,
          "refreshed session title",
          "Refreshed",
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // refreshSessions failure — keeps current state, returns false
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "refreshSessions: keeps current state and returns false on API failure",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession()])),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to error for the refresh call.
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        final result = await cubit.refreshSessions();
        expect(result, isFalse);
      },
      skip: 1, // skip the first refresh's emission
      // No state changes — current state is preserved.
      expect: () => <SessionListState>[],
    );

    // -------------------------------------------------------------------------
    // SSE events from other projects are ignored
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.created for same project adds to list",
      build: () {
        const existing = Session(
          approvalOverride: null,
          autoContinuation: null,
          branchName: null,
          id: "s1",
          pluginId: legacyMissingPluginId,
          projectID: projectId,
          directory: "/home/user/my-project",
          parentID: null,
          title: "Existing",
          time: SessionTime(created: 1, updated: 2, archived: null),
          pullRequest: null,
          promptDefaults: null,
          lastUserActivityAt: null,
        );
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const SessionListResponse(items: [existing])),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionCreated(
              info: Session(
                approvalOverride: null,
                autoContinuation: null,
                branchName: null,
                id: "s2",
                pluginId: legacyMissingPluginId,
                projectID: projectId,
                directory: "/home/user/my-project",
                parentID: null,
                title: "New",
                time: SessionTime(created: 3, updated: 4, archived: null),
                pullRequest: null,
                promptDefaults: null,
                lastUserActivityAt: null,
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>().having((s) => s.sessions.length, "sessions count", 2).having(
          (s) => s.sessions.map((session) => session.id).toList(),
          "session order",
          ["s2", "s1"],
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.updated for same project updates existing session",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Original"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          SseEvent(
            data: SesoriSseEvent.sessionUpdated(
              info: testSession(id: "s1", title: "Updated"),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>()
            .having((s) => s.sessions.length, "sessions count", 1)
            .having((s) => s.sessions.first.title, "updated title", "Updated"),
      ],
    );

    test("PR-free session.updated preserves REST PR data until sessions.updated refreshes it", () async {
      const mergedPullRequest = PullRequestInfo(
        number: 690,
        url: "https://github.com/sesori-ai/sesori_apps_monorepo/pull/690",
        title: "Merged pull request",
        state: PrState.merged,
        mergeableStatus: PrMergeableStatus.unknown,
        reviewDecision: PrReviewDecision.unknown,
        checkStatus: PrCheckStatus.success,
      );
      final withPullRequest = testSession(id: "s1", title: "Original").copyWith(
        pullRequest: mergedPullRequest,
      );
      final withoutPullRequest = testSession(id: "s1", title: "Updated");
      final responses = <SessionListResponse>[
        SessionListResponse(items: [withPullRequest]),
        SessionListResponse(items: [withoutPullRequest]),
      ];
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) async => ApiResponse.success(responses.removeAt(0)));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refreshSessions();
      expect(cubit.state.sessions.single.pullRequest, mergedPullRequest);
      eventController.add(
        SseEvent(
          data: SesoriSseEvent.sessionUpdated(info: withoutPullRequest),
        ),
      );
      final afterSessionUpdate = await cubit.stream.firstWhere(
        (state) => state.sessions.single.title == "Updated",
      );
      expect(afterSessionUpdate.sessions.single.pullRequest, mergedPullRequest);

      eventController.add(
        SseEvent(data: const SesoriSessionsUpdated(projectID: projectId)),
      );
      final afterAuthoritativeRefresh = await cubit.stream.firstWhere(
        (state) => state.sessions.single.pullRequest == null,
      );
      expect(afterAuthoritativeRefresh.sessions.single.pullRequest, isNull);
    });

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.updated timestamp reorders sessions",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "A", title: "Alpha").copyWith(
                  time: const SessionTime(created: 1000, updated: 3000, archived: null),
                ),
                testSession(id: "B", title: "Bravo").copyWith(
                  time: const SessionTime(created: 1000, updated: 2000, archived: null),
                ),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          SseEvent(
            data: SesoriSseEvent.sessionUpdated(
              info: testSession(id: "B", title: "Bravo").copyWith(
                time: const SessionTime(created: 1000, updated: 9000, archived: null),
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>()
            .having(
              (state) => state.sessions.map((session) => session.id).toList(),
              "session order",
              ["B", "A"],
            )
            .having(
              (state) => state.sessions.first.time?.updated,
              "updated timestamp",
              9000,
            ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.deleted for same project removes from list",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "First"),
                testSession(id: "s2", title: "Second"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          SseEvent(
            data: SesoriSseEvent.sessionDeleted(
              info: testSession(id: "s1", title: "First"),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>()
            .having((s) => s.sessions.length, "sessions count", 1)
            .having((s) => s.sessions.first.id, "remaining session", "s2"),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.created for child session is ignored",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionCreated(
              info: Session(
                approvalOverride: null,
                autoContinuation: null,
                branchName: null,
                id: "child-1",
                pluginId: legacyMissingPluginId,
                projectID: projectId,
                parentID: "s1",
                directory: "/home/user/my-project",
                title: "Child Session",
                time: SessionTime(created: 1, updated: 2, archived: null),
                pullRequest: null,
                promptDefaults: null,
                lastUserActivityAt: null,
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => <SessionListState>[],
    );

    blocTest<SessionListCubit, SessionListState>(
      "connection reconnect triggers silent refresh",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "First"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "First"),
                testSession(id: "s2", title: "Second"),
              ],
            ),
          ),
        );

        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
          bridgeId: null,
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>().having((s) => s.sessions.length, "sessions count after reconnect", 2),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "rapid ConnectionConnected events coalesce into single refresh",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        // Wait for the first refresh to complete.
        await Future<void>.delayed(Duration.zero);
        // Reset interaction count after the first refresh.
        reset(mockProjectRepository);

        // Use a Completer so the first refresh stays in-flight while the
        // second ConnectionConnected arrives — this is what exercises the guard.
        final completer = Completer<ApiResponse<SessionListResponse>>();
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) => completer.future);

        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
          bridgeId: null,
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
        const connected = ConnectionStatus.connected(config: config, health: health);

        // Fire two rapid ConnectionConnected events.
        statusController.add(connected);
        statusController.add(connected);
        await Future<void>.delayed(Duration.zero);

        // Let the in-flight refresh complete.
        completer.complete(ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => <SessionListState>[],
      verify: (_) {
        // Should have been called only once despite two ConnectionConnected events.
        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).called(1);
      },
    );

    test("constructor does not fetch, even when the connection is already connected", () async {
      // The cubit receives this replayed status immediately on subscribe.
      const config = ServerConnectionConfig(
        relayHost: "relay.example.com",
        authToken: "test-token",
        bridgeId: null,
      );
      const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
      statusController.add(
        const ConnectionStatus.connected(config: config, health: health),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => mockProjectRepository.listSessions(
          projectId: any(named: "projectId"),
        ),
      );
    });

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.created for a different project is ignored",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.created event for a different project.
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionCreated(
              info: Session(
                approvalOverride: null,
                autoContinuation: null,
                branchName: null,
                id: "foreign-session",
                pluginId: legacyMissingPluginId,
                projectID: "project-other",
                directory: "/other/project",
                parentID: null,
                title: "Foreign Session",
                time: SessionTime(created: 1, updated: 2, archived: null),
                pullRequest: null,
                promptDefaults: null,
                lastUserActivityAt: null,
              ),
            ),
          ),
        );
        // Give the event time to be processed.
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1, // skip the first refresh's emission
      // No state changes — the foreign session must be ignored.
      expect: () => <SessionListState>[],
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.updated for a different project is ignored",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.updated event for a different project.
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionUpdated(
              info: Session(
                approvalOverride: null,
                autoContinuation: null,
                branchName: null,
                id: "foreign-session",
                pluginId: legacyMissingPluginId,
                projectID: "project-other",
                directory: "/other/project",
                parentID: null,
                title: "Foreign Session Updated",
                time: SessionTime(created: 1, updated: 3, archived: null),
                pullRequest: null,
                promptDefaults: null,
                lastUserActivityAt: null,
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => <SessionListState>[],
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.deleted for a different project is ignored",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.deleted event for a different project.
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionDeleted(
              info: Session(
                approvalOverride: null,
                autoContinuation: null,
                branchName: null,
                id: "foreign-session",
                pluginId: legacyMissingPluginId,
                projectID: "project-other",
                directory: "/other/project",
                parentID: null,
                title: null,
                time: SessionTime(created: 1, updated: 2, archived: null),
                pullRequest: null,
                promptDefaults: null,
                lastUserActivityAt: null,
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => <SessionListState>[],
    );

    // -------------------------------------------------------------------------
    // Root "global" project — sessions in subdirectories still belong here
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "global project includes sessions in any subdirectory",
      build: () {
        const sessions = [
          Session(
            approvalOverride: null,
            autoContinuation: null,
            branchName: null,
            id: "s1",
            pluginId: legacyMissingPluginId,
            projectID: "global",
            directory: "/tmp/foo",
            parentID: null,
            title: "Under /tmp/foo",
            time: SessionTime(created: 1, updated: 2, archived: null),
            pullRequest: null,
            promptDefaults: null,
            lastUserActivityAt: null,
          ),
          Session(
            approvalOverride: null,
            autoContinuation: null,
            branchName: null,
            id: "s2",
            pluginId: legacyMissingPluginId,
            projectID: "global",
            directory: "/home/bar",
            parentID: null,
            title: "Under /home/bar",
            time: SessionTime(created: 3, updated: 4, archived: null),
            pullRequest: null,
            promptDefaults: null,
            lastUserActivityAt: null,
          ),
        ];
        when(
          () => mockProjectRepository.listSessions(
            projectId: "global",
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const SessionListResponse(items: sessions)),
        );
        final cubit = SessionListCubit(
          sessions: const [],
          sessionRepository: mockSessionService,
          sessionCleanupService: SessionCleanupService(repository: mockSessionService),
          sessionListService: sessionListService,
          connectionService: mockConnectionService,
          sseEventTracker: mockSseEventTracker,
          sessionUnseenTracker: fakeSessionUnseenTracker,
          projectId: "global",
          failureReporter: mockFailureReporter,
          catalogRescanService: fakeCatalogRescanService,
        );
        unawaited(cubit.refreshSessions());
        return cubit;
      },
      expect: () => [
        isA<SessionListState>().having(
          (s) => s.sessions.length,
          "all sessions under root",
          2,
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // activeSessionIds from SseEventTracker
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "state includes activeSessionIds from SseEventTracker",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
                testSession(id: "s2", title: "Session 2"),
              ],
            ),
          ),
        );
        // Mock the repository to emit activity for this project.
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        return buildRefreshingCubit();
      },
      expect: () => [
        isA<SessionListState>().having((s) => s.sessions.length, "sessions count", 2).having(
          (s) => s.activeSessionIds,
          "activeSessionIds",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // activeSessionIds updates when activity changes
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds updates when activity changes",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
                testSession(id: "s2", title: "Session 2"),
              ],
            ),
          ),
        );
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        // Wait for the first refresh
        await Future<void>.delayed(Duration.zero);
        // Emit initial activity
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        await awaitState(
          cubit: cubit,
          predicate: (state) => state.activeSessionIds.length == 1 && state.activeSessionIds.containsKey("s1"),
          description: "SessionListState with s1 active",
        );
        // Emit updated activity
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
      },
      skip: 1, // skip the first refresh's emission
      expect: () => [
        // First activity update: only s1 is active
        isA<SessionListState>().having((s) => s.sessions.length, "sessions count", 2).having(
          (s) => s.activeSessionIds,
          "activeSessionIds after first update",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        ),
        // Second activity update: both s1 and s2 are active
        isA<SessionListState>().having((s) => s.sessions.length, "sessions count", 2).having(
          (s) => s.activeSessionIds,
          "activeSessionIds after second update",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // activeSessionIds excludes sessions from other projects
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds excludes sessions from other projects",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
              ],
            ),
          ),
        );
        // Emit activity for this project and another.
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
          "project-2": {
            "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "s3": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        return buildRefreshingCubit();
      },
      expect: () => [
        isA<SessionListState>().having((s) => s.sessions.length, "sessions count", 1).having(
          (s) => s.activeSessionIds,
          "activeSessionIds for this project only",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // renameSession success — updates optimistically and returns true
    // -------------------------------------------------------------------------

    late Completer<ApiResponse<Session>> renameSessionCompleter;
    blocTest<SessionListCubit, SessionListState>(
      "renameSession: updates the title before the request completes and returns true on success",
      build: () {
        renameSessionCompleter = Completer<ApiResponse<Session>>();
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "Original")],
            ),
          ),
        );
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "New Title"),
        ).thenAnswer((_) => renameSessionCompleter.future);
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "New Title")],
            ),
          ),
        );

        final rename = cubit.renameSession(sessionId: "s1", title: "New Title");
        expect(cubit.state.sessions.first.title, "New Title");

        renameSessionCompleter.complete(ApiResponse.success(testSession(id: "s1", title: "New Title")));
        expect(await rename, isTrue);
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>().having(
          (s) => s.sessions.first.title,
          "optimistic session title",
          "New Title",
        ),
      ],
      verify: (_) {
        verify(() => mockSessionService.renameSession(sessionId: "s1", title: "New Title")).called(1);
      },
    );

    test("renameSession replaces an active refresh with a post-write read", () async {
      final original = testSession(id: "s1", title: "Original");
      final renamed = testSession(id: "s1", title: "New Title");
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [original])));
      final renameCompleter = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "New Title"),
      ).thenAnswer((_) => renameCompleter.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();

      final staleRefreshCompleter = Completer<ApiResponse<SessionListResponse>>();
      final postRenameRefreshCompleter = Completer<ApiResponse<SessionListResponse>>();
      var refreshRequestCount = 0;
      when(
        () => mockProjectRepository.listSessions(projectId: projectId),
      ).thenAnswer((_) {
        refreshRequestCount++;
        return refreshRequestCount == 1 ? staleRefreshCompleter.future : postRenameRefreshCompleter.future;
      });

      final staleRefresh = cubit.refreshSessions();
      final rename = cubit.renameSession(sessionId: "s1", title: "New Title");
      expect(cubit.state.sessions.single.title, "New Title");

      renameCompleter.complete(ApiResponse.success(renamed));
      expect(await rename, isTrue);
      expect(refreshRequestCount, 2);

      staleRefreshCompleter.complete(ApiResponse.success(SessionListResponse(items: [original])));
      postRenameRefreshCompleter.complete(ApiResponse.success(SessionListResponse(items: [renamed])));
      expect(await staleRefresh, isTrue);
      expect(cubit.state.sessions.single.title, "New Title");
    });

    test("renameSession keeps a pending refresh successful and restores the pre-rename title", () async {
      final original = testSession(id: "s1", title: "Original");
      final stale = testSession(id: "s1", title: "Stale snapshot");
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [original])));
      final renameCompleter = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "New Title"),
      ).thenAnswer((_) => renameCompleter.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();

      final refreshCompleter = Completer<ApiResponse<SessionListResponse>>();
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) => refreshCompleter.future);

      final refresh = cubit.refreshSessions();
      final rename = cubit.renameSession(sessionId: "s1", title: "New Title");
      refreshCompleter.complete(ApiResponse.success(SessionListResponse(items: [stale])));

      expect(await refresh, isTrue);
      expect(cubit.state.sessions.single.title, "New Title");

      renameCompleter.complete(ApiResponse<Session>.error(ApiError.generic()));
      expect(await rename, isFalse);
      expect(cubit.state.sessions.single.title, "Original");
    });

    test("renameSession restores a null committed title after two overlapping failures", () async {
      final original = testSession(id: "s1", title: null);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [original])));
      final firstRenameCompleter = Completer<ApiResponse<Session>>();
      final secondRenameCompleter = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "First title"),
      ).thenAnswer((_) => firstRenameCompleter.future);
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "Second title"),
      ).thenAnswer((_) => secondRenameCompleter.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();

      final firstRename = cubit.renameSession(sessionId: "s1", title: "First title");
      final secondRename = cubit.renameSession(sessionId: "s1", title: "Second title");
      expect(cubit.state.sessions.single.title, "Second title");

      firstRenameCompleter.complete(ApiResponse<Session>.error(ApiError.generic()));
      expect(await firstRename, isFalse);
      expect(cubit.state.sessions.single.title, "Second title");

      secondRenameCompleter.complete(ApiResponse<Session>.error(ApiError.generic()));
      expect(await secondRename, isFalse);
      expect(cubit.state.sessions.single.title, isNull);
    });

    test("renameSession restores an older in-flight success after newer renames fail", () async {
      final original = testSession(id: "s1", title: "Original");
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [original])));
      final firstRenameCompleter = Completer<ApiResponse<Session>>();
      final secondRenameCompleter = Completer<ApiResponse<Session>>();
      final thirdRenameCompleter = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "First title"),
      ).thenAnswer((_) => firstRenameCompleter.future);
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "Second title"),
      ).thenAnswer((_) => secondRenameCompleter.future);
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "Third title"),
      ).thenAnswer((_) => thirdRenameCompleter.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();

      final firstRename = cubit.renameSession(sessionId: "s1", title: "First title");
      final secondRename = cubit.renameSession(sessionId: "s1", title: "Second title");
      secondRenameCompleter.complete(ApiResponse<Session>.error(ApiError.generic()));
      expect(await secondRename, isFalse);
      expect(cubit.state.sessions.single.title, "First title");

      final thirdRename = cubit.renameSession(sessionId: "s1", title: "Third title");
      firstRenameCompleter.complete(ApiResponse.success(original.copyWith(title: "First title")));
      expect(await firstRename, isTrue);
      expect(cubit.state.sessions.single.title, "Third title");

      thirdRenameCompleter.complete(ApiResponse<Session>.error(ApiError.generic()));
      expect(await thirdRename, isFalse);
      expect(cubit.state.sessions.single.title, "First title");
    });

    test("renameSession restores the latest confirmed title when a newer rename fails", () async {
      final original = testSession(id: "s1", title: "Original");
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [original])));
      final firstRenameCompleter = Completer<ApiResponse<Session>>();
      final secondRenameCompleter = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "First title"),
      ).thenAnswer((_) => firstRenameCompleter.future);
      when(
        () => mockSessionService.renameSession(sessionId: "s1", title: "Second title"),
      ).thenAnswer((_) => secondRenameCompleter.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();

      final firstRename = cubit.renameSession(sessionId: "s1", title: "First title");
      final secondRename = cubit.renameSession(sessionId: "s1", title: "Second title");

      firstRenameCompleter.complete(ApiResponse.success(original.copyWith(title: "First title")));
      expect(await firstRename, isTrue);
      expect(cubit.state.sessions.single.title, "Second title");

      secondRenameCompleter.complete(ApiResponse<Session>.error(ApiError.generic()));
      expect(await secondRename, isFalse);
      expect(cubit.state.sessions.single.title, "First title");
    });

    // -------------------------------------------------------------------------
    // renameSession failure — restores the previous title and returns false
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "renameSession: restores the previous title when the request fails",
      build: () {
        renameSessionCompleter = Completer<ApiResponse<Session>>();
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "Original")],
            ),
          ),
        );
        when(
          () => mockSessionService.renameSession(sessionId: "s1", title: "New Title"),
        ).thenAnswer((_) => renameSessionCompleter.future);
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final rename = cubit.renameSession(sessionId: "s1", title: "New Title");
        expect(cubit.state.sessions.first.title, "New Title");

        renameSessionCompleter.complete(ApiResponse<Session>.error(ApiError.generic()));
        expect(await rename, isFalse);
      },
      skip: 1,
      expect: () => [
        isA<SessionListState>().having(
          (s) => s.sessions.first.title,
          "optimistic session title",
          "New Title",
        ),
        isA<SessionListState>().having(
          (s) => s.sessions.first.title,
          "restored session title",
          "Original",
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // activeSessionIds is empty when no activity for this project
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds is empty when no activity for this project",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
              ],
            ),
          ),
        );
        // Emit activity for a different project.
        mockSseEventTracker.emitSessionActivity({
          "project-2": {
            "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        return buildRefreshingCubit();
      },
      expect: () => [
        isA<SessionListState>()
            .having((s) => s.sessions.length, "sessions count", 1)
            .having((s) => s.activeSessionIds, "activeSessionIds empty", isEmpty),
      ],
    );

    // -------------------------------------------------------------------------
    // activeSessionIds propagates awaitingInput from SessionActivityInfo
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds propagates awaitingInput true from SessionActivityInfo",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
              ],
            ),
          ),
        );
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(
              mainAgentRunning: true,
              awaitingInput: true,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
          },
        });
        return buildRefreshingCubit();
      },
      expect: () => [
        isA<SessionListState>().having((s) => s.sessions.length, "sessions count", 1).having(
          (s) => s.activeSessionIds,
          "activeSessionIds with awaitingInput",
          {
            "s1": const SessionActivityInfo(
              mainAgentRunning: true,
              awaitingInput: true,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
          },
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // Stale reconnect
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "stale signal triggers a silent refresh",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(title: "Original")])));
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero); // let the first refresh complete
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(title: "Refreshed")])));
        mockConnectionService.emitDataMayBeStale();
        await Future<void>.delayed(Duration.zero); // let the stale refresh complete
      },
      expect: () => [
        isA<SessionListState>().having((s) => s.sessions.single.title, "first refresh title", "Original"),
        isA<SessionListState>().having((s) => s.sessions.single.title, "stale refresh title", "Refreshed"),
      ],
    );

    final reconnectResponses = <Completer<ApiResponse<SessionListResponse>>>[];
    blocTest<SessionListCubit, SessionListState>(
      "stale + ConnectionConnected refresh coalesced into single API call",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) {
          final response = Completer<ApiResponse<SessionListResponse>>();
          reconnectResponses.add(response);
          return response.future;
        });
        return buildRefreshingCubit();
      },
      act: (cubit) async {
        reconnectResponses.single.complete(ApiResponse.success(SessionListResponse(items: [testSession()])));
        await awaitState(
          cubit: cubit,
          predicate: (state) => state.sessions.isNotEmpty,
          description: "first refreshed SessionListState",
        );
        // Emit both stale and ConnectionConnected simultaneously
        mockConnectionService.emitDataMayBeStale();
        statusController.add(
          const ConnectionStatus.connected(
            config: ServerConnectionConfig(relayHost: "test.example.com", authToken: null, bridgeId: null),
            health: HealthResponse(healthy: true, version: "0.1.0", filesystemAccessDegraded: false),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(reconnectResponses, hasLength(2));
        reconnectResponses.last.complete(
          ApiResponse.success(SessionListResponse(items: [testSession(title: "Refreshed")])),
        );
        await awaitState(
          cubit: cubit,
          predicate: (state) => state.sessions.single.title == "Refreshed",
          description: "coalesced refresh applied",
        );
      },
      verify: (cubit) {
        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).called(2);
      },
    );

    test("fetch seeds the tracker with the REST unseen flags", () async {
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          SessionListResponse(
            items: [
              testSession(id: "s1", unseen: true, lastUserActivityAt: 20),
              testSession(id: "s2"),
            ],
          ),
        ),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();

      expect(
        fakeSessionUnseenTracker.seededSessions.single.stateBySessionId,
        equals({
          "s1": (unseen: true, lastUserActivityAt: 20),
          "s2": (unseen: false, lastUserActivityAt: null),
        }),
      );
      expect(cubit.state.unseenBySessionId, equals({"s1": true, "s2": false}));
    });

    test("live tracker marker reorders running sessions and advances displayed recency", () async {
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          SessionListResponse(
            items: [
              testSession(id: "newer").copyWith(
                time: const SessionTime(created: 1, updated: 20, archived: null),
              ),
              testSession(id: "older").copyWith(
                time: const SessionTime(created: 1, updated: 10, archived: null),
              ),
            ],
          ),
        ),
      );
      mockSseEventTracker.emitSessionActivity({
        projectId: {
          "newer": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          "older": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
        },
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();
      expect(cubit.state.sessions.map((session) => session.id), ["newer", "older"]);

      fakeSessionUnseenTracker.emitSessionUnseen({
        projectId: {
          "newer": (unseen: false, lastUserActivityAt: 20),
          "older": (unseen: true, lastUserActivityAt: 30),
        },
      });
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state;
      expect(state.sessions.map((session) => session.id), ["older", "newer"]);
      expect(state.sessions.first.time?.updated, 30);
      expect(state.sessions.first.lastUserActivityAt, 30);
    });

    test("live marker received during REST fetch wins over the stale seed", () async {
      final response = Completer<ApiResponse<SessionListResponse>>();
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer((_) => response.future);
      mockSseEventTracker.emitSessionActivity({
        projectId: {
          "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
        },
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      final refresh = cubit.refreshSessions();
      fakeSessionUnseenTracker.emitSessionUnseen({
        projectId: {
          "s1": (unseen: true, lastUserActivityAt: 30),
          "s2": (unseen: false, lastUserActivityAt: 10),
        },
      });
      response.complete(
        ApiResponse.success(
          SessionListResponse(
            items: [
              testSession(id: "s1", lastUserActivityAt: 5),
              testSession(id: "s2", lastUserActivityAt: 40),
            ],
          ),
        ),
      );
      expect(await refresh, isTrue);

      expect(cubit.state.sessions.map((session) => session.id), ["s1", "s2"]);
      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"]?.lastUserActivityAt, 30);
    });

    test("live tracker updates re-emit the merged unseen map", () async {
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();
      expect(cubit.state.unseenBySessionId["s1"], isFalse);

      fakeSessionUnseenTracker.emitSessionUnseen({
        projectId: {"s1": (unseen: true, lastUserActivityAt: null)},
      });
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.unseenBySessionId["s1"], isTrue);
    });

    test("markSessionSeen applies the change to the tracker optimistically", () async {
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1", unseen: true)])),
      );
      when(
        () => mockSessionService.markSessionSeen(sessionId: "s1", read: true),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();
      expect(cubit.state.unseenBySessionId["s1"], isTrue);

      await cubit.markSessionSeen(sessionId: "s1", read: true);
      await Future<void>.delayed(Duration.zero);

      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"]?.unseen, isFalse);
      expect(cubit.state.unseenBySessionId["s1"], isFalse);
      verify(() => mockSessionService.markSessionSeen(sessionId: "s1", read: true)).called(1);
    });

    test("markSessionSeen failure refetches the authoritative list", () async {
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1", unseen: true)])),
      );
      when(
        () => mockSessionService.markSessionSeen(sessionId: "s1", read: true),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.refreshSessions();
      clearInteractions(mockProjectRepository);

      await cubit.markSessionSeen(sessionId: "s1", read: true);
      await Future<void>.delayed(Duration.zero);

      // No local rollback bookkeeping: the failed request triggers a silent
      // refetch, whose seed restores the authoritative unseen flags.
      verify(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
        ),
      ).called(1);
      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"]?.unseen, isTrue);
      expect(cubit.state.unseenBySessionId["s1"], isTrue);
    });

    test("action scope close retains a dialog through rename, mark recovery and delete", () async {
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
        () => mockSessionService.deleteSession(sessionId: session.id, deleteWorktree: true, force: false),
      ).thenAnswer((_) => deleteReply.future);
      when(
        () => mockProjectRepository.listSessions(projectId: projectId),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [session])));
      final cubit = buildCubit(sessions: [session]);

      final releaseDialog = cubit.retainActionScope();
      final close = cubit.close();
      expect(cubit.isClosed, isFalse);
      final rename = cubit.renameSession(sessionId: session.id, title: "Renamed");
      final mutation = cubit.markSessionSeen(sessionId: session.id, read: true);
      final deletion = cubit.deleteSession(sessionId: session.id, deleteWorktree: true, force: false);
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
      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?[session.id]?.unseen, isTrue);
      verify(() => mockProjectRepository.listSessions(projectId: projectId)).called(1);
      verify(
        () => mockSessionService.deleteSession(sessionId: session.id, deleteWorktree: true, force: false),
      ).called(1);
    });

    group("catalog change refresh", () {
      Future<ApiResponse<SessionListResponse>> successfulResponse({required List<Session> sessions}) {
        return Future<ApiResponse<SessionListResponse>>.value(
          ApiResponse.success(SessionListResponse(items: sessions)),
        );
      }

      test("refreshes after a committed catalog change", () async {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: [])));
        final cubit = buildCubit();
        addTearDown(cubit.close);

        fakeCatalogRescanService.emitCatalogChanged();
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).called(1);
      });

      test("post-commit data wins over an overlapping earlier read", () async {
        final olderRefresh = Completer<ApiResponse<SessionListResponse>>();
        final postCommit = Completer<ApiResponse<SessionListResponse>>();
        final catalogSession = testSession(id: "catalog", title: "Imported after scan");
        var requestCount = 0;
        Future<ApiResponse<SessionListResponse>> nextResponse() => switch (requestCount++) {
          0 => successfulResponse(sessions: const []),
          1 => olderRefresh.future,
          2 => postCommit.future,
          _ => throw StateError("unexpected session list request"),
        };
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) => nextResponse());

        final cubit = buildCubit();
        addTearDown(cubit.close);
        expect(await cubit.refreshSessions(), isTrue);

        unawaited(cubit.refreshSessions());
        await Future<void>.delayed(Duration.zero);
        fakeCatalogRescanService.emitCatalogChanged();
        await Future<void>.delayed(Duration.zero);
        expect(requestCount, 3, reason: "the catalog refresh must not coalesce onto the older refresh");

        postCommit.complete(ApiResponse.success(SessionListResponse(items: [catalogSession])));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.sessions, [catalogSession]);

        olderRefresh.complete(ApiResponse.success(const SessionListResponse(items: [])));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.sessions, [catalogSession]);
      });

      test("a superseded explicit refresh reports the catalog refresh failure", () async {
        final explicitRefresh = Completer<ApiResponse<SessionListResponse>>();
        var requestCount = 0;
        Future<ApiResponse<SessionListResponse>> nextResponse() => switch (requestCount++) {
          0 => successfulResponse(sessions: const []),
          1 => explicitRefresh.future,
          2 => Future<ApiResponse<SessionListResponse>>.value(ApiResponse.error(ApiError.generic())),
          _ => successfulResponse(sessions: const []),
        };
        when(
          () => mockProjectRepository.listSessions(projectId: projectId),
        ).thenAnswer((_) => nextResponse());

        final cubit = buildCubit();
        addTearDown(cubit.close);
        expect(await cubit.refreshSessions(), isTrue);

        final refresh = cubit.refreshSessions();
        await Future<void>.delayed(Duration.zero);
        fakeCatalogRescanService.emitCatalogChanged();
        await Future<void>.delayed(Duration.zero);
        expect(requestCount, 3);

        explicitRefresh.complete(ApiResponse.success(const SessionListResponse(items: [])));
        expect(await refresh, isFalse);
        expect(requestCount, 3, reason: "the stale explicit read must not rearm the failed catalog refresh");
      });

      test("runs a trailing catalog refresh after another commit arrives in flight", () async {
        final firstPostCommit = Completer<ApiResponse<SessionListResponse>>();
        final secondPostCommit = Completer<ApiResponse<SessionListResponse>>();
        final firstSession = testSession(id: "first", title: "First import");
        final secondSession = testSession(id: "second", title: "Second import");
        var requestCount = 0;
        Future<ApiResponse<SessionListResponse>> nextResponse() => switch (requestCount++) {
          0 => successfulResponse(sessions: const []),
          1 => firstPostCommit.future,
          2 => secondPostCommit.future,
          _ => throw StateError("unexpected session list request"),
        };
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) => nextResponse());

        final cubit = buildCubit();
        addTearDown(cubit.close);
        expect(await cubit.refreshSessions(), isTrue);

        fakeCatalogRescanService
          ..emitCatalogChanged()
          ..emitCatalogChanged();
        await Future<void>.delayed(Duration.zero);
        expect(requestCount, 2);

        firstPostCommit.complete(ApiResponse.success(SessionListResponse(items: [firstSession])));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(requestCount, 3, reason: "the second commit needs a later snapshot");

        secondPostCommit.complete(ApiResponse.success(SessionListResponse(items: [secondSession])));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.sessions, [secondSession]);
      });

      test("preserves a failed catalog refresh for the next ordinary refresh", () async {
        final catalogSession = testSession(id: "catalog", title: "Imported after retry");
        var requestCount = 0;
        Future<ApiResponse<SessionListResponse>> nextResponse() => switch (requestCount++) {
          0 => successfulResponse(sessions: const []),
          1 => Future<ApiResponse<SessionListResponse>>.value(ApiResponse.error(ApiError.generic())),
          2 => successfulResponse(sessions: [catalogSession]),
          _ => throw StateError("unexpected session list request"),
        };
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
          ),
        ).thenAnswer((_) => nextResponse());

        final cubit = buildCubit();
        addTearDown(cubit.close);
        expect(await cubit.refreshSessions(), isTrue);

        fakeCatalogRescanService.emitCatalogChanged();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(requestCount, 2, reason: "a failed catalog refresh must not retry in a loop");

        expect(await cubit.refreshSessions(), isTrue);
        expect(requestCount, 3);
        expect(cubit.state.sessions, [catalogSession]);
      });
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
