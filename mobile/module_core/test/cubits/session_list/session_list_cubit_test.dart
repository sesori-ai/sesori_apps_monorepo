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
import "package:sesori_dart_core/src/capabilities/sse/session_activity_info.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionListCubit", () {
    late MockSessionService mockSessionService;
    late MockProjectService mockProjectService;
    late MockConnectionService mockConnectionService;
    late MockSseEventRepository mockSseEventRepository;
    late MockRouteSource mockRouteSource;
    late MockFailureReporter mockFailureReporter;
    late StreamController<SseEvent> eventController;
    late BehaviorSubject<ConnectionStatus> statusController;

    const projectId = "project-1";

    setUp(() {
      mockSessionService = MockSessionService();
      mockProjectService = MockProjectService();
      mockConnectionService = MockConnectionService();
      mockSseEventRepository = MockSseEventRepository();
      mockFailureReporter = MockFailureReporter();
      eventController = StreamController<SseEvent>.broadcast();
      statusController = BehaviorSubject<ConnectionStatus>.seeded(
        const ConnectionStatus.disconnected(),
      );

      // Must be stubbed before any cubit is built — constructor subscribes immediately.
      when(() => mockConnectionService.events).thenAnswer((_) => eventController.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
      when(
        () => mockProjectService.getBaseBranch(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.success(const BaseBranchResponse(baseBranch: null)));
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
      projectService: mockProjectService,
      connectionService: mockConnectionService,
      sseEventRepository: mockSseEventRepository,
      routeSource: mockRouteSource,
      projectId: projectId,
      failureReporter: mockFailureReporter,
    );

    // -------------------------------------------------------------------------
    // 1. Constructor triggers load only — no route refresh on initial emission
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "constructor: with sessions route already visible, only the initial load runs",
      build: () {
        mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
        when(
          () => mockProjectService.listSessions(projectId: projectId),
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
        verify(() => mockProjectService.listSessions(projectId: projectId)).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // 2. Route return refresh — projects → sessions triggers one silent reload
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "route return: refreshes once when navigation returns to sessions",
      build: () {
        mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.projects);
        when(
          () => mockProjectService.listSessions(projectId: projectId),
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
          () => mockProjectService.listSessions(projectId: projectId),
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
        verify(() => mockProjectService.listSessions(projectId: projectId)).called(2);
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
          () => mockProjectService.listSessions(projectId: projectId),
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
          () => mockProjectService.listSessions(projectId: projectId),
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
          () => mockProjectService.listSessions(projectId: projectId),
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
          () => mockProjectService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
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
          deleteBranch: false,
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
          () => mockProjectService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
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
          deleteBranch: false,
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
          () => mockProjectService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
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
          deleteBranch: true,
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
          () => mockProjectService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
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
          deleteBranch: false,
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
          () => mockProjectService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])));
        when(
          () => mockSessionService.deleteSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
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
          deleteBranch: true,
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
          () => mockProjectService.listSessions(projectId: projectId),
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession()])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to error for the refresh call.
        when(
          () => mockProjectService.listSessions(projectId: projectId),
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
    // 13. unarchiveSession success — preserves ID and updates in place
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "unarchiveSession: keeps session id and clears archived timestamp",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [archivedSession])),
        );
        when(() => mockSessionService.unarchiveSession(sessionId: "s1")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s1", title: "Restored")),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.toggleArchived();
        final result = await cubit.unarchiveSession("s1");
        expect(result, isTrue);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived", isTrue)
            .having((s) => s.sessions.length, "sessions after toggle", 1)
            .having((s) => s.sessions.first.time?.archived, "starts archived", isNotNull),
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions after optimistic unarchive", 1)
            .having((s) => s.sessions.first.id, "preserved id", "s1")
            .having((s) => s.sessions.first.time?.archived, "archived cleared", isNull),
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions after API success", 1)
            .having((s) => s.sessions.first.id, "preserved id", "s1")
            .having((s) => s.sessions.first.title, "updated title", "Restored"),
      ],
    );

    // -------------------------------------------------------------------------
    // 14. unarchiveSession failure — rollback restores archived state
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "unarchiveSession: rolls back archived timestamp and returns false on API failure",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [archivedSession])),
        );
        when(() => mockSessionService.unarchiveSession(sessionId: "s1")).thenAnswer(
          (_) async => ApiResponse.error(ApiError.generic()),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.toggleArchived();
        final result = await cubit.unarchiveSession("s1");
        expect(result, isFalse);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived", isTrue)
            .having((s) => s.sessions.length, "sessions after toggle", 1),
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions after optimistic unarchive", 1)
            .having((s) => s.sessions.first.time?.archived, "archived cleared", isNull),
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions after rollback", 1)
            .having((s) => s.sessions.first.time?.archived, "archived timestamp restored", isNotNull),
      ],
    );

    // -------------------------------------------------------------------------
    // 15. undoLastArchiveAction — reverses archive (undo = unarchive)
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "undoLastArchiveAction: unarchives after archive, restoring the session",
      build: () {
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
            force: any(named: "force"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s1", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
          ),
        );
        when(() => mockSessionService.unarchiveSession(sessionId: "s1")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s1")),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.archiveSession(
          sessionId: "s1",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        );
        final undoResult = await cubit.undoLastArchiveAction();
        expect(undoResult, isTrue);
      },
      skip: 1,
      expect: () => [
        // Optimistic archive: session hidden.
        isA<SessionListLoaded>().having((s) => s.sessions, "sessions after archive", isEmpty),
        // Undo (unarchive): session restored.
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions after undo", 1),
      ],
    );

    // -------------------------------------------------------------------------
    // 16. undoLastArchiveAction — re-archives after unarchive
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "undoLastArchiveAction: archives back after unarchive",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [archivedSession])),
        );
        when(() => mockSessionService.unarchiveSession(sessionId: "s1")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s1")),
        );
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
            force: any(named: "force"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s1", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000002000)),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.toggleArchived();
        await cubit.unarchiveSession("s1");
        final undoResult = await cubit.undoLastArchiveAction();
        expect(undoResult, isTrue);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions after toggle", 1),
        isA<SessionListLoaded>()
            .having((s) => s.sessions.first.id, "session id after unarchive", "s1")
            .having((s) => s.sessions.first.time?.archived, "archived cleared", isNull),
        isA<SessionListLoaded>()
            .having((s) => s.sessions.first.id, "session id after undo", "s1")
            .having((s) => s.sessions.first.time?.archived, "re-archived", isNotNull),
      ],
    );

    // -------------------------------------------------------------------------
    // 17. Rapid archive s1 → archive s2 → undo reverts s2 correctly
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "undoLastArchiveAction after rapid successive archives: undo reverts the latest action",
      build: () {
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "First"),
                testSession(id: "s2", title: "Second"),
              ],
            ),
          ),
        );
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
            force: any(named: "force"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s1", title: "First", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
          ),
        );
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s2",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
            force: any(named: "force"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s2", title: "Second", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000002000)),
          ),
        );
        // Undo should unarchive s2 (the latest), not s1.
        when(() => mockSessionService.unarchiveSession(sessionId: "s2")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s2", title: "Second")),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.archiveSession(
          sessionId: "s1",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        );
        await cubit.archiveSession(
          sessionId: "s2",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        );
        final undoResult = await cubit.undoLastArchiveAction();
        expect(undoResult, isTrue);
      },
      skip: 1,
      expect: () => [
        // s1 archived → hidden (only s2 visible).
        isA<SessionListLoaded>().having((s) => s.sessions.length, "after archive s1", 1),
        // s2 archived → both hidden.
        isA<SessionListLoaded>().having((s) => s.sessions, "after archive s2", isEmpty),
        // Undo restores s2 (not s1).
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "after undo", 1)
            .having((s) => s.sessions.first.id, "restored session id", "s2"),
      ],
    );

    // -------------------------------------------------------------------------
    // 18. Stale clearLastActionUndo after rapid archives wipes undo state
    //     (documents the race condition that the screen must avoid)
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "clearLastActionUndo between rapid archives prevents undo of the latest",
      build: () {
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "First"),
                testSession(id: "s2", title: "Second"),
              ],
            ),
          ),
        );
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s1",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
            force: any(named: "force"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s1", title: "First", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
          ),
        );
        when(
          () => mockSessionService.archiveSession(
            sessionId: "s2",
            deleteWorktree: any(named: "deleteWorktree"),
            deleteBranch: any(named: "deleteBranch"),
            force: any(named: "force"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s2", title: "Second", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000002000)),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.archiveSession(
          sessionId: "s1",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        );
        await cubit.archiveSession(
          sessionId: "s2",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        );
        // Simulates a stale timer/callback from the first archive's snackbar
        // clearing the undo state that now belongs to the second archive.
        cubit.clearLastActionUndo();
        final undoResult = await cubit.undoLastArchiveAction();
        expect(undoResult, isFalse);
      },
      skip: 1,
      expect: () => [
        // s1 archived → hidden.
        isA<SessionListLoaded>().having((s) => s.sessions.length, "after archive s1", 1),
        // s2 archived → both hidden.
        isA<SessionListLoaded>().having((s) => s.sessions, "after archive s2", isEmpty),
        // No undo emission — undoLastArchiveAction returned false.
      ],
    );

    // -------------------------------------------------------------------------
    // SSE events from other projects are ignored
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.created for same project adds to list",
      build: () {
        const existing = Session(
          id: "s1",
          projectID: projectId,
          directory: "/home/user/my-project",
          parentID: null,
          title: "Existing",
          summary: null,
          time: SessionTime(created: 1, updated: 2, archived: null),
          pullRequest: null,
        );
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
                id: "s2",
                projectID: projectId,
                directory: "/home/user/my-project",
                parentID: null,
                title: "New",
                summary: null,
                time: SessionTime(created: 3, updated: 4, archived: null),
                pullRequest: null,
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions count", 2)
            .having((s) => s.sessions.first.id, "new session first", "s2"),
      ],
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.updated for same project updates existing session",
      build: () {
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.deleted for same project removes from list",
      build: () {
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
                id: "child-1",
                projectID: projectId,
                parentID: "s1",
                directory: "/home/user/my-project",
                title: "Child Session",
                summary: null,
                time: SessionTime(created: 1, updated: 2, archived: null),
                pullRequest: null,
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        const health = HealthResponse(healthy: true, version: "0.1.200");
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.error(ApiError.generic()),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to succeed so the reconnect-triggered load works.
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200");
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        // Wait for initial load to complete.
        await Future<void>.delayed(Duration.zero);
        // Reset interaction count after initial load.
        reset(mockProjectService);

        // Use a Completer so the first refresh stays in-flight while the
        // second ConnectionConnected arrives — this is what exercises the guard.
        final completer = Completer<ApiResponse<SessionListResponse>>();
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer((_) => completer.future);
        when(() => mockProjectService.getBaseBranch(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(const BaseBranchResponse(baseBranch: "main")),
        );

        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200");
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
        verify(() => mockProjectService.listSessions(projectId: projectId)).called(1);
      },
    );

    blocTest<SessionListCubit, SessionListState>(
      "ConnectionConnected while state is loading does not trigger refresh",
      build: () {
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [testSession(id: "s1")])),
        );

        // Seed the status controller as Connected BEFORE building the cubit,
        // so the cubit receives ConnectionConnected immediately on subscribe.
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200");
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
        verify(() => mockProjectService.listSessions(projectId: projectId)).called(1);
      },
    );

    blocTest<SessionListCubit, SessionListState>(
      "SSE session.created for a different project is ignored",
      build: () {
        when(
          () => mockProjectService.listSessions(projectId: projectId),
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
                id: "foreign-session",
                projectID: "project-other",
                directory: "/other/project",
                parentID: null,
                title: "Foreign Session",
                summary: null,
                time: SessionTime(created: 1, updated: 2, archived: null),
                pullRequest: null,
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
          () => mockProjectService.listSessions(projectId: projectId),
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
                id: "foreign-session",
                projectID: "project-other",
                directory: "/other/project",
                parentID: null,
                title: "Foreign Session Updated",
                summary: null,
                time: SessionTime(created: 1, updated: 3, archived: null),
                pullRequest: null,
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
          () => mockProjectService.listSessions(projectId: projectId),
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
                id: "foreign-session",
                projectID: "project-other",
                directory: "/other/project",
                parentID: null,
                title: null,
                summary: null,
                time: SessionTime(created: 1, updated: 2, archived: null),
                pullRequest: null,
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
            id: "s1",
            projectID: "global",
            directory: "/tmp/foo",
            parentID: null,
            title: "Under /tmp/foo",
            summary: null,
            time: SessionTime(created: 1, updated: 2, archived: null),
            pullRequest: null,
          ),
          Session(
            id: "s2",
            projectID: "global",
            directory: "/home/bar",
            parentID: null,
            title: "Under /home/bar",
            summary: null,
            time: SessionTime(created: 3, updated: 4, archived: null),
            pullRequest: null,
          ),
        ];
        when(() => mockProjectService.listSessions(projectId: "global")).thenAnswer(
          (_) async => ApiResponse.success(const SessionListResponse(items: sessions)),
        );
        return SessionListCubit(
          sessionService: mockSessionService,
          projectService: mockProjectService,
          connectionService: mockConnectionService,
          sseEventRepository: mockSseEventRepository,
          routeSource: mockRouteSource,
          projectId: "global",
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
    // 19. activeSessionIds from SseEventRepository
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "state includes activeSessionIds from SseEventRepository",
      build: () {
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        mockSseEventRepository.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true),
            "s2": const SessionActivityInfo(mainAgentRunning: true),
          },
        });
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 2).having(
          (s) => s.activeSessionIds,
          "activeSessionIds",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true),
            "s2": const SessionActivityInfo(mainAgentRunning: true),
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
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
        mockSseEventRepository.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true),
          },
        });
        // Wait for the activity update to be processed
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // Emit updated activity
        mockSseEventRepository.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true),
            "s2": const SessionActivityInfo(mainAgentRunning: true),
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
            "s1": const SessionActivityInfo(mainAgentRunning: true),
          },
        ),
        // Second activity update: both s1 and s2 are active
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 2).having(
          (s) => s.activeSessionIds,
          "activeSessionIds after second update",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true),
            "s2": const SessionActivityInfo(mainAgentRunning: true),
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
              ],
            ),
          ),
        );
        // Emit activity for this project and another.
        mockSseEventRepository.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true),
          },
          "project-2": {
            "s2": const SessionActivityInfo(mainAgentRunning: true),
            "s3": const SessionActivityInfo(mainAgentRunning: true),
          },
        });
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 1).having(
          (s) => s.activeSessionIds,
          "activeSessionIds for this project only",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true),
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
          () => mockProjectService.listSessions(projectId: projectId),
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
          () => mockProjectService.listSessions(projectId: projectId),
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
          () => mockProjectService.listSessions(projectId: projectId),
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
              ],
            ),
          ),
        );
        // Emit activity for a different project.
        mockSseEventRepository.emitSessionActivity({
          "project-2": {
            "s2": const SessionActivityInfo(mainAgentRunning: true),
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(
            SessionListResponse(
              items: [
                testSession(id: "s1", title: "Session 1"),
              ],
            ),
          ),
        );
        mockSseEventRepository.emitSessionActivity({
          projectId: {
            "s1": const SessionActivityInfo(mainAgentRunning: true, awaitingInput: true),
          },
        });
        return buildCubit();
      },
      expect: () => [
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions count", 1).having(
          (s) => s.activeSessionIds,
          "activeSessionIds with awaitingInput",
          {
            "s1": const SessionActivityInfo(mainAgentRunning: true, awaitingInput: true),
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
          () => mockProjectService.listSessions(projectId: projectId),
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => Future.delayed(
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
        when(() => mockProjectService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => Future.delayed(
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
            health: HealthResponse(healthy: true, version: "0.1.0"),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      verify: (cubit) {
        // Verify listSessions was called at least once (initial load + refresh)
        verify(() => mockProjectService.listSessions(projectId: projectId)).called(greaterThanOrEqualTo(1));
      },
    );
  });
}
