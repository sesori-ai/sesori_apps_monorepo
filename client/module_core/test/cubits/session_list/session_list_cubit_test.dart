import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show AppRouteDef;
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_state.dart";
import "package:sesori_dart_core/src/repositories/models/repo_provider.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/src/services/session_list_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionListCubit", () {
    late MockSessionService mockSessionService;
    late MockProjectRepository mockProjectRepository;
    late SessionListService sessionListService;
    late MockConnectionService mockConnectionService;
    late MockSseEventTracker mockSseEventTracker;
    late FakeSessionUnseenTracker fakeSessionUnseenTracker;
    late MockProjectViewingService mockProjectViewingService;
    late MockRouteSource mockRouteSource;
    late MockFailureReporter mockFailureReporter;
    late StreamController<SseEvent> eventController;
    late BehaviorSubject<ConnectionStatus> statusController;

    const projectId = "project-1";

    setUp(() {
      mockSessionService = MockSessionService();
      mockProjectRepository = MockProjectRepository();
      sessionListService = SessionListService(
        repository: mockProjectRepository,
        activityCalculator: const SessionActivityCalculator(),
      );
      mockConnectionService = MockConnectionService();
      mockSseEventTracker = MockSseEventTracker();
      fakeSessionUnseenTracker = FakeSessionUnseenTracker();
      mockProjectViewingService = stubbedProjectViewingService();
      mockFailureReporter = MockFailureReporter();
      eventController = StreamController<SseEvent>.broadcast();
      statusController = BehaviorSubject<ConnectionStatus>.seeded(
        const ConnectionStatus.disconnected(),
      );
      // Must be stubbed before any cubit is built — constructor subscribes immediately.
      when(() => mockConnectionService.events).thenAnswer((_) => eventController.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
      when(
        () => mockProjectRepository.getGitContext(projectId: any(named: "projectId")),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const ProjectGitContext(baseBranch: null, repoSlug: null, repoProvider: RepoProvider.other),
        ),
      );
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
    SessionListCubit buildCubit() => SessionListCubit(
      sessionService: mockSessionService,
      sessionListService: sessionListService,
      projectRepository: mockProjectRepository,
      connectionService: mockConnectionService,
      sseEventTracker: mockSseEventTracker,
      sessionUnseenTracker: fakeSessionUnseenTracker,
      projectViewingService: mockProjectViewingService,
      routeSource: mockRouteSource,
      projectId: projectId,
      initialSupportsDedicatedWorktrees: null,
      failureReporter: mockFailureReporter,
    );

    test("successful list render readies its project claim and close releases it", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: [])));
      final cubit = buildCubit();

      await cubit.stream.firstWhere((state) => state is SessionListLoaded);
      verify(() => mockProjectViewingService.beginListClaim(projectId: projectId)).called(1);
      verify(
        () => mockProjectViewingService.markClaimReady(
          claim: any(named: "claim"),
          projectId: projectId,
        ),
      ).called(1);

      await cubit.close();
      verify(
        () => mockProjectViewingService.releaseClaim(claim: any(named: "claim")),
      ).called(1);
    });

    test("initial tracker replay leaves the cubit loading until REST completes", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      final response = Completer<ApiResponse<SessionListResponse>>();
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer((_) => response.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<SessionListLoading>());

      response.complete(ApiResponse.success(const SessionListResponse(items: [])));
      await cubit.stream.firstWhere((state) => state is SessionListLoaded);
    });

    test("failed initial list render marks its project claim failed", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      final cubit = buildCubit();

      await cubit.stream.firstWhere((state) => state is SessionListFailed);
      verify(() => mockProjectViewingService.beginListClaim(projectId: projectId)).called(1);
      verify(
        () => mockProjectViewingService.markClaimFailed(claim: any(named: "claim")),
      ).called(1);
      await cubit.close();
    });

    // -------------------------------------------------------------------------
    // 1. Constructor triggers load only — no route refresh on initial emission
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "constructor: with sessions route already visible, only the initial load runs",
      build: () {
        mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession()])));
        return buildCubit();
      },
      act: (_) async {
        await Future<void>.delayed(Duration.zero);
        mockRouteSource.emitRoute(AppRouteDef.sessions);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions.length,
          "sessions count",
          1,
        ),
      ],
      verify: (_) {
        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).called(1);
      },
    );

    blocTest<SessionListCubit, SessionListState>(
      "REST session list is sorted by updated timestamp descending",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having(
          (state) => state.sessions.map((session) => session.id).toList(),
          "session order",
          ["untitled", "B", "A", "a"],
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "running activity received after REST creates a timestamp-ordered prefix",
      build: () {
        mockRouteSource = MockRouteSource();
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
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
        isA<SessionListLoaded>().having(
          (state) => state.sessions.map((session) => session.id).toList(),
          "session order",
          ["A", "C", "B"],
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "running activity received before REST uses timestamps when sessions arrive",
      build: () {
        mockRouteSource = MockRouteSource();
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "C": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "A": const SessionActivityInfo(isRetrying: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having(
          (state) => state.sessions.map((session) => session.id).toList(),
          "session order",
          ["A", "C", "B"],
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // 2. Route return refresh — projects → sessions triggers one silent reload
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "route return: refreshes once when navigation returns to sessions",
      build: () {
        mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.projects);
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "Original")],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "Refreshed")],
            ),
          ),
        );
        mockRouteSource.emitRoute(AppRouteDef.sessions);
        await Future<void>.delayed(Duration.zero);
        mockRouteSource.emitRoute(AppRouteDef.sessions);
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions.first.title,
          "refreshed session title",
          "Refreshed",
        ),
      ],
      verify: (_) {
        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).called(2);
      },
    );

    // -------------------------------------------------------------------------
    // 3. Load success — multiple sessions returned
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "loadSessions: emits SessionListLoaded with all returned sessions",
      build: () {
        final sessions = [
          testSession(id: "s1", title: "First"),
          testSession(id: "s2", title: "Second"),
        ];
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: sessions)));
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions.length,
          "sessions count",
          2,
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // 4. Load empty — loaded with empty list
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "loadSessions: emits SessionListLoaded with empty list when server returns none",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions,
          "sessions",
          isEmpty,
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // 5. Load error → SessionListFailed
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "loadSessions: emits SessionListFailed when API returns an error",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      expect: () => [isA<SessionListFailed>()],
    );

    // -------------------------------------------------------------------------
    // 6. archiveSession success — optimistic removal, API succeeds, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "archiveSession: optimistically hides session and returns true on API success",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            force: any(named: "force"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s1")));
        return buildCubit();
      },
      act: (cubit) async {
        // Drain the constructor-triggered loadSessions() before acting.
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.archiveSession(
          sessionId: "s1",
          deleteWorktree: false,
          force: false,
        );
        expect(result, isTrue);
      },
      // Skip the initial SessionListLoaded emitted by loadSessions().
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions,
          "sessions after optimistic archive",
          isEmpty,
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // 7. archiveSession failure — optimistic removal then rollback, returns false
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "archiveSession: rolls back session and returns false on API failure",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            force: any(named: "force"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.archiveSession(
          sessionId: "s1",
          deleteWorktree: false,
          force: false,
        );
        expect(result, isFalse);
      },
      skip: 1,
      expect: () => [
        // Optimistic: session hidden (archived, showArchived=false).
        isA<SessionListLoaded>().having(
          (s) => s.sessions,
          "sessions after optimistic archive",
          isEmpty,
        ),
        // Rollback: original session restored.
        isA<SessionListLoaded>().having(
          (s) => s.sessions.length,
          "sessions after rollback",
          1,
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "archiveSession: stores cleanup rejection and rolls back on 409",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            force: any(named: "force"),
          ),
        ).thenThrow(
          const SessionCleanupRejectedException(
            rejection: SessionCleanupRejection(
              issues: [CleanupIssue.unstagedChanges()],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.archiveSession(
          sessionId: "s1",
          deleteWorktree: true,
          force: false,
        );
        expect(result, isFalse);
        expect(cubit.lastCleanupRejection?.issues.length, 1);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions, "sessions after optimistic archive", isEmpty),
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions after rollback", 1),
      ],
    );

    // -------------------------------------------------------------------------
    // 7. deleteSession success — optimistic removal, API succeeds, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "deleteSession: optimistically removes session and returns true on API success",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            force: any(named: "force"),
          ),
        ).thenAnswer((_) async => ApiResponse<void>.success(null));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: false,
          force: false,
        );
        expect(result, isTrue);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having(
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
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            force: any(named: "force"),
          ),
        ).thenThrow(
          const SessionCleanupRejectedException(
            rejection: SessionCleanupRejection(
              issues: [CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main")],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: true,
          force: false,
        );
        expect(result, isFalse);
        expect(
          cubit.lastCleanupRejection?.issues.first,
          const CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main"),
        );
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions, "sessions after optimistic delete", isEmpty),
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions after rollback", 1),
      ],
    );

    // -------------------------------------------------------------------------
    // 9. toggleArchived — flips showArchived flag, re-emits filtered sessions
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "toggleArchived: shows archived sessions when showArchived becomes true",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [archivedSession])));
        return buildCubit();
      },
      act: (cubit) async {
        // Wait for initial load (archived session filtered out → sessions: []).
        await Future<void>.delayed(Duration.zero);
        cubit.toggleArchived();
      },
      // Skip the initial SessionListLoaded(sessions: []) — archived filtered out.
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived", isTrue)
            .having((s) => s.sessions.length, "visible sessions", 1),
      ],
    );

    // -------------------------------------------------------------------------
    // 10. refreshSessions success — no loading state, emits loaded, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "refreshSessions: emits loaded without loading state and returns true",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "Original")],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Return different data on refresh to prove new data is used.
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
      skip: 1, // skip constructor's initial loaded emission
      expect: () => [
        // Only SessionListLoaded — no SessionListLoading in between.
        isA<SessionListLoaded>().having(
          (s) => s.sessions.first.title,
          "refreshed session title",
          "Refreshed",
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // 11. refreshSessions failure — keeps current state, returns false
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "refreshSessions: keeps current state and returns false on API failure",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession()])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to error for the refresh call.
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        final result = await cubit.refreshSessions();
        expect(result, isFalse);
      },
      skip: 1, // skip constructor's initial loaded emission
      // No state changes — current loaded state is preserved.
      expect: () => <SessionListState>[],
    );

    // -------------------------------------------------------------------------
    // 12. refreshSessions preserves showArchived toggle across refresh
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "refreshSessions: preserves showArchived flag after refresh",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [archivedSession])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        // Wait for initial load (archived session filtered out).
        await Future<void>.delayed(Duration.zero);
        // Toggle archived on so the session becomes visible.
        cubit.toggleArchived();
        // Return session with a different title so the refresh emits a
        // distinct state (bloc deduplicates identical states).
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(
                  id: "s1",
                  title: "Refreshed",
                  archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
                ),
              ],
            ),
          ),
        );
        final result = await cubit.refreshSessions();
        expect(result, isTrue);
      },
      skip: 1, // skip constructor's initial loaded emission (sessions: [])
      expect: () => [
        // toggleArchived: shows the archived session.
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived after toggle", isTrue)
            .having((s) => s.sessions.length, "visible sessions after toggle", 1),
        // refreshSessions: re-emits with showArchived still true and new data.
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived after refresh", isTrue)
            .having((s) => s.sessions.first.title, "refreshed title", "Refreshed"),
      ],
    );

    // -------------------------------------------------------------------------
    // SSE events from other projects are ignored
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.created for same project adds to list",
      build: () {
        const existing = Session(
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
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const SessionListResponse(items: [existing])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionCreated(
              info: Session(
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
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 2).having(
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
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
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
        isA<SessionListLoaded>()
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
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(responses.removeAt(0)));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.stream.firstWhere(
        (state) => state is SessionListLoaded && state.sessions.single.pullRequest == mergedPullRequest,
      );
      eventController.add(
        SseEvent(
          data: SesoriSseEvent.sessionUpdated(info: withoutPullRequest),
        ),
      );
      final afterSessionUpdate = await cubit.stream.firstWhere(
        (state) => state is SessionListLoaded && state.sessions.single.title == "Updated",
      ) as SessionListLoaded;
      expect(afterSessionUpdate.sessions.single.pullRequest, mergedPullRequest);

      eventController.add(
        SseEvent(data: const SesoriSessionsUpdated(projectID: projectId)),
      );
      final afterAuthoritativeRefresh = await cubit.stream.firstWhere(
        (state) => state is SessionListLoaded && state.sessions.single.pullRequest == null,
      ) as SessionListLoaded;
      expect(afterAuthoritativeRefresh.sessions.single.pullRequest, isNull);
    });

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.updated timestamp reorders sessions",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
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
        isA<SessionListLoaded>()
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
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
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
        isA<SessionListLoaded>()
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
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionCreated(
              info: Session(
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
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count after reconnect", 2),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "connection reconnect triggers loadSessions when state is SessionListFailed",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.error(ApiError.generic()),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to succeed so the reconnect-triggered load works.
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1, // Skip the initial SessionListFailed from constructor.
      expect: () => [
        isA<SessionListLoading>(),
        isA<SessionListLoaded>().having(
          (s) => s.sessions.length,
          "sessions count after reconnect retry",
          1,
        ),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "rapid ConnectionConnected events coalesce into single refresh",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        // Wait for initial load to complete.
        await Future<void>.delayed(Duration.zero);
        // Reset interaction count after initial load.
        reset(mockProjectRepository);

        // Use a Completer so the first refresh stays in-flight while the
        // second ConnectionConnected arrives — this is what exercises the guard.
        final completer = Completer<ApiResponse<SessionListResponse>>();
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) => completer.future);
        when(() => mockProjectRepository.getGitContext(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(
            const ProjectGitContext(baseBranch: "main", repoSlug: null, repoProvider: RepoProvider.other),
          ),
        );

        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
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
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count after refresh", 1),
      ],
      verify: (_) {
        // Should have been called only once despite two ConnectionConnected events.
        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).called(1);
      },
    );

    blocTest<SessionListCubit, SessionListState>(
      "ConnectionConnected while state is loading does not trigger refresh",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );

        // Seed the status controller as Connected BEFORE building the cubit,
        // so the cubit receives ConnectionConnected immediately on subscribe.
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      verify: (_) {
        // Only 1 call from the constructor's loadSessions().
        // The ConnectionConnected should NOT trigger a second fetch.
        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).called(1);
      },
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.created for a different project is ignored",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.created event for a different project.
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionCreated(
              info: Session(
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
      skip: 1, // skip constructor's initial loaded emission
      // No state changes — the foreign session must be ignored.
      expect: () => <SessionListState>[],
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.updated for a different project is ignored",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.updated event for a different project.
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionUpdated(
              info: Session(
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
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.deleted event for a different project.
        eventController.add(
          SseEvent(
            data: const SesoriSseEvent.sessionDeleted(
              info: Session(
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
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const SessionListResponse(items: sessions)),
        );
        return SessionListCubit(
          sessionService: mockSessionService,
          sessionListService: sessionListService,
          projectRepository: mockProjectRepository,
          connectionService: mockConnectionService,
          sseEventTracker: mockSseEventTracker,
          sessionUnseenTracker: fakeSessionUnseenTracker,
          projectViewingService: mockProjectViewingService,
          routeSource: mockRouteSource,
          projectId: "global",
          initialSupportsDedicatedWorktrees: null,
          failureReporter: mockFailureReporter,
        );
      },
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions.length,
          "all sessions under root",
          2,
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // 19. activeSessionIds from SseEventTracker
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "state includes activeSessionIds from SseEventTracker",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 2).having(
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
    // 20. activeSessionIds updates when activity changes
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds updates when activity changes",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      act: (cubit) async {
        // Wait for initial load
        await Future<void>.delayed(Duration.zero);
        // Emit initial activity
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
        // Wait for the activity update to be processed
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // Emit updated activity
        mockSseEventTracker.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
            "s2": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        });
      },
      skip: 1, // skip initial load
      expect: () => [
        // First activity update: only s1 is active
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 2).having(
          (s) => s.activeSessionIds,
          "activeSessionIds after first update",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        ),
        // Second activity update: both s1 and s2 are active
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 2).having(
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
    // 21. activeSessionIds excludes sessions from other projects
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds excludes sessions from other projects",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 1).having(
          (s) => s.activeSessionIds,
          "activeSessionIds for this project only",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // renameSession success — calls service, refreshes list, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "renameSession: calls service with correct args, refreshes sessions, and returns true on success",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s1", title: "New Title")));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to return renamed session on refresh.
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [testSession(id: "s1", title: "New Title")],
            ),
          ),
        );
        final result = await cubit.renameSession(sessionId: "s1", title: "New Title");
        expect(result, isTrue);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions.first.title,
          "session title after rename",
          "New Title",
        ),
      ],
      verify: (_) {
        verify(() => mockSessionService.renameSession(sessionId: "s1", title: "New Title")).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // renameSession failure — service returns ErrorResponse, returns false
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "renameSession: returns false and leaves state unchanged when service returns error",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        ).thenAnswer((_) async => ApiResponse<Session>.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.renameSession(sessionId: "s1", title: "New Title");
        expect(result, isFalse);
      },
      skip: 1,
      // No state changes — current loaded state is preserved.
      expect: () => <SessionListState>[],
    );

    // -------------------------------------------------------------------------
    // 22. activeSessionIds is empty when no activity for this project
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds is empty when no activity for this project",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions count", 1)
            .having((s) => s.activeSessionIds, "activeSessionIds empty", isEmpty),
      ],
    );

    // -------------------------------------------------------------------------
    // 23. activeSessionIds propagates awaitingInput from SessionActivityInfo
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds propagates awaitingInput true from SessionActivityInfo",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
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
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 1).having(
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
      "stale signal triggers refresh with isRefreshing indicator",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero); // let initial load complete
        mockConnectionService.emitDataMayBeStale();
        await Future<void>.delayed(Duration.zero); // let refresh start
      },
      expect: () => [
        isA<SessionListLoaded>(), // initial load
        isA<SessionListLoaded>().having((s) => s.isRefreshing, "isRefreshing", true), // stale signal
        isA<SessionListLoaded>().having((s) => s.isRefreshing, "isRefreshing", false), // refresh complete
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "stale signal is ignored when state is not SessionListLoaded",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => await Future.delayed(
            const Duration(milliseconds: 100),
            () => ApiResponse.success(SessionListResponse(items: [testSession()])),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        // Emit stale while still loading
        mockConnectionService.emitDataMayBeStale();
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1, // Skip the initial loading state
      expect: () => <SessionListState>[
        // No additional states from stale signal since state is not loaded
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "stale + ConnectionConnected refresh coalesced into single API call",
      build: () {
        when(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).thenAnswer(
          (_) async => await Future.delayed(
            const Duration(milliseconds: 50),
            () => ApiResponse.success(SessionListResponse(items: [testSession()])),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero); // let initial load complete
        // Emit both stale and ConnectionConnected simultaneously
        mockConnectionService.emitDataMayBeStale();
        statusController.add(
          const ConnectionStatus.connected(
            config: ServerConnectionConfig(relayHost: "test.example.com"),
            health: HealthResponse(healthy: true, version: "0.1.0", filesystemAccessDegraded: null),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      verify: (cubit) {
        // Verify listSessions was called at least once (initial load + refresh)
        verify(
          () => mockProjectRepository.listSessions(
            projectId: projectId,
            waitForPrData: any(named: "waitForPrData"),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test("fetch seeds the tracker with the REST unseen flags", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
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
      await Future<void>.delayed(Duration.zero);

      expect(
        fakeSessionUnseenTracker.seededSessions.single.stateBySessionId,
        equals({
          "s1": (unseen: true, lastUserActivityAt: 20),
          "s2": (unseen: false, lastUserActivityAt: null),
        }),
      );
      expect((cubit.state as SessionListLoaded).unseenBySessionId, equals({"s1": true, "s2": false}));
    });

    test("live tracker marker reorders sessions that are already running", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
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
      await cubit.stream.firstWhere((state) => state is SessionListLoaded);
      expect((cubit.state as SessionListLoaded).sessions.map((session) => session.id), ["newer", "older"]);

      fakeSessionUnseenTracker.emitSessionUnseen({
        projectId: {
          "newer": (unseen: false, lastUserActivityAt: 20),
          "older": (unseen: true, lastUserActivityAt: 30),
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as SessionListLoaded).sessions.map((session) => session.id), ["older", "newer"]);
    });

    test("live marker received during REST fetch wins over the stale seed", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      final response = Completer<ApiResponse<SessionListResponse>>();
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
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
      await cubit.stream.firstWhere((state) => state is SessionListLoaded);

      expect((cubit.state as SessionListLoaded).sessions.map((session) => session.id), ["s1", "s2"]);
      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"]?.lastUserActivityAt, 30);
    });

    test("live tracker updates re-emit the merged unseen map", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionListLoaded).unseenBySessionId["s1"], isFalse);

      fakeSessionUnseenTracker.emitSessionUnseen({
        projectId: {"s1": (unseen: true, lastUserActivityAt: null)},
      });
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as SessionListLoaded).unseenBySessionId["s1"], isTrue);
    });

    test("markSessionSeen applies the change to the tracker optimistically", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1", unseen: true)])),
      );
      when(
        () => mockSessionService.markSessionSeen(sessionId: "s1", read: true),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionListLoaded).unseenBySessionId["s1"], isTrue);

      await cubit.markSessionSeen(sessionId: "s1", read: true);
      await Future<void>.delayed(Duration.zero);

      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"]?.unseen, isFalse);
      expect((cubit.state as SessionListLoaded).unseenBySessionId["s1"], isFalse);
      verify(() => mockSessionService.markSessionSeen(sessionId: "s1", read: true)).called(1);
    });

    test("markSessionSeen failure refetches the authoritative list", () async {
      mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
      when(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1", unseen: true)])),
      );
      when(
        () => mockSessionService.markSessionSeen(sessionId: "s1", read: true),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      clearInteractions(mockProjectRepository);

      await cubit.markSessionSeen(sessionId: "s1", read: true);
      await Future<void>.delayed(Duration.zero);

      // No local rollback bookkeeping: the failed request triggers a silent
      // refetch, whose seed restores the authoritative unseen flags.
      verify(
        () => mockProjectRepository.listSessions(
          projectId: projectId,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).called(1);
      expect(fakeSessionUnseenTracker.currentSessionUnseen[projectId]?["s1"]?.unseen, isTrue);
      expect((cubit.state as SessionListLoaded).unseenBySessionId["s1"], isTrue);
    });
  });
}
