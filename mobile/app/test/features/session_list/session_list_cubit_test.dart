import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/sse/session_activity_info.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_state.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionListCubit", () {
    late MockSessionService mockSessionService;
    late MockConnectionService mockConnectionService;
    late MockSseEventRepository mockSseEventRepository;
    late StreamController<SseEvent> eventController;

    const projectId = "project-1";

    setUp(() {
      mockSessionService = MockSessionService();
      mockConnectionService = MockConnectionService();
      mockSseEventRepository = MockSseEventRepository();
      eventController = StreamController<SseEvent>.broadcast();

      // Must be stubbed before any cubit is built — constructor subscribes immediately.
      when(() => mockConnectionService.events).thenAnswer((_) => eventController.stream);
    });

    tearDown(() async {
      await eventController.close();
    });

    /// Convenience factory — stubs must be set up before calling this.
    SessionListCubit buildCubit() => SessionListCubit(
      mockSessionService,
      mockConnectionService,
      mockSseEventRepository,
      projectId: projectId,
    );

    // -------------------------------------------------------------------------
    // 1. Constructor triggers load → emits SessionListLoaded
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "constructor: emits SessionListLoaded with sessions after successful load",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession()]));
        return buildCubit();
      },
      // No act — we only verify what the constructor-triggered load emits.
      expect: () => [
        isA<SessionListLoaded>().having(
          (s) => s.sessions.length,
          "sessions count",
          1,
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // 2. Load success — multiple sessions returned
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "loadSessions: emits SessionListLoaded with all returned sessions",
      build: () {
        final sessions = [
          testSession(id: "s1", title: "First"),
          testSession(id: "s2", title: "Second"),
        ];
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(sessions));
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
    // 3. Load empty — loaded with empty list
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "loadSessions: emits SessionListLoaded with empty list when server returns none",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(<Session>[]));
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
    // 4. Load error → SessionListFailed
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "loadSessions: emits SessionListFailed when API returns an error",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      expect: () => [isA<SessionListFailed>()],
    );

    // -------------------------------------------------------------------------
    // 5. archiveSession success — optimistic removal, API succeeds, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "archiveSession: optimistically hides session and returns true on API success",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession(id: "s1")]));
        when(
          () => mockSessionService.archiveSession("s1"),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s1")));
        return buildCubit();
      },
      act: (cubit) async {
        // Drain the constructor-triggered loadSessions() before acting.
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.archiveSession("s1");
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
    // 6. archiveSession failure — optimistic removal then rollback, returns false
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "archiveSession: rolls back session and returns false on API failure",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession(id: "s1")]));
        when(
          () => mockSessionService.archiveSession("s1"),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.archiveSession("s1");
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

    // -------------------------------------------------------------------------
    // 7. deleteSession success — optimistic removal, API succeeds, returns true
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "deleteSession: optimistically removes session and returns true on API success",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession(id: "s1")]));
        when(() => mockSessionService.deleteSession("s1")).thenAnswer((_) async => ApiResponse.success(true));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.deleteSession("s1");
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

    // -------------------------------------------------------------------------
    // 8. createSession — calls API and returns the new Session
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "createSession: calls API and returns the created Session on success",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession()]));
        when(() => mockSessionService.createSession(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "new-session")),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.createSession();
        expect(result?.id, "new-session");
      },
      // createSession emits no state changes — only the initial load is skipped.
      skip: 1,
      expect: () => <SessionListState>[],
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
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([archivedSession]));
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([testSession(id: "s1", title: "Original")]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Return different data on refresh to prove new data is used.
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([testSession(id: "s1", title: "Refreshed")]),
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([testSession()]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to error for the refresh call.
        when(
          () => mockSessionService.listSessions(projectId: projectId),
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([archivedSession]),
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([
            testSession(
              id: "s1",
              title: "Refreshed",
              archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
            ),
          ]),
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
    // 13. unarchiveSession success — optimistically shows session, API succeeds
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "unarchiveSession: optimistically unarchives session and returns true on API success",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([archivedSession]),
        );
        when(() => mockSessionService.unarchiveSession("s1")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s1")),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Toggle archived on so the archived session is visible.
        cubit.toggleArchived();
        final result = await cubit.unarchiveSession("s1");
        expect(result, isTrue);
      },
      // Skip initial load (archived session filtered out → sessions: []).
      skip: 1,
      expect: () => [
        // toggleArchived: shows the archived session.
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived", isTrue)
            .having((s) => s.sessions.length, "sessions after toggle", 1),
        // Optimistic unarchive: session now has archived=null.
        // Server response is identical, so bloc deduplicates — only one emission.
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions after unarchive", 1)
            .having((s) => s.sessions.first.time?.archived, "archived cleared", isNull),
      ],
    );

    // -------------------------------------------------------------------------
    // 14. unarchiveSession failure — rollback restores archived state
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "unarchiveSession: rolls back session and returns false on API failure",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([archivedSession]),
        );
        when(() => mockSessionService.unarchiveSession("s1")).thenAnswer(
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
        // toggleArchived: shows the archived session.
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived", isTrue)
            .having((s) => s.sessions.length, "sessions after toggle", 1),
        // Optimistic unarchive: session still visible.
        isA<SessionListLoaded>().having((s) => s.sessions.length, "sessions after optimistic unarchive", 1),
        // Rollback: archived session restored.
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([testSession(id: "s1")]),
        );
        when(() => mockSessionService.archiveSession("s1")).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s1", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
          ),
        );
        when(() => mockSessionService.unarchiveSession("s1")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s1")),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.archiveSession("s1");
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
    // 16. undoLastArchiveAction — reverses unarchive (undo = re-archive)
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "undoLastArchiveAction: re-archives after unarchive",
      build: () {
        final archivedSession = testSession(
          id: "s1",
          archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        );
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([archivedSession]),
        );
        when(() => mockSessionService.unarchiveSession("s1")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s1")),
        );
        when(() => mockSessionService.archiveSession("s1")).thenAnswer(
          (_) async => ApiResponse.success(archivedSession),
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
        // toggleArchived: shows the archived session.
        isA<SessionListLoaded>()
            .having((s) => s.showArchived, "showArchived", isTrue)
            .having((s) => s.sessions.length, "sessions after toggle", 1),
        // Optimistic unarchive: session now has archived=null.
        // Server response is identical, so bloc deduplicates — only one emission.
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions after unarchive", 1)
            .having((s) => s.sessions.first.time?.archived, "archived cleared", isNull),
        // Undo (re-archive): session still visible (showArchived is true), archived restored.
        isA<SessionListLoaded>()
            .having((s) => s.sessions.length, "sessions after undo", 1)
            .having((s) => s.sessions.first.time?.archived, "re-archived timestamp", isNotNull),
      ],
    );

    // -------------------------------------------------------------------------
    // 17. Rapid archive s1 → archive s2 → undo reverts s2 correctly
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "undoLastArchiveAction after rapid successive archives: undo reverts the latest action",
      build: () {
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([
            testSession(id: "s1", title: "First"),
            testSession(id: "s2", title: "Second"),
          ]),
        );
        when(() => mockSessionService.archiveSession("s1")).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s1", title: "First", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
          ),
        );
        when(() => mockSessionService.archiveSession("s2")).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s2", title: "Second", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000002000)),
          ),
        );
        // Undo should unarchive s2 (the latest), not s1.
        when(() => mockSessionService.unarchiveSession("s2")).thenAnswer(
          (_) async => ApiResponse.success(testSession(id: "s2", title: "Second")),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.archiveSession("s1");
        await cubit.archiveSession("s2");
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([
            testSession(id: "s1", title: "First"),
            testSession(id: "s2", title: "Second"),
          ]),
        );
        when(() => mockSessionService.archiveSession("s1")).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s1", title: "First", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
          ),
        );
        when(() => mockSessionService.archiveSession("s2")).thenAnswer(
          (_) async => ApiResponse.success(
            testSession(id: "s2", title: "Second", archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000002000)),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.archiveSession("s1");
        await cubit.archiveSession("s2");
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
      "SSE session.created for a different project is ignored",
      build: () {
        when(
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession(id: "s1")]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.created event for a different project.
        eventController.add(
          SseEvent(
            data: SesoriSseEvent.sessionCreated(
              info: const Session(
                id: "foreign-session",
                projectID: "project-other",
                directory: "/other/project",
                title: "Foreign Session",
                time: SessionTime(created: 1, updated: 2),
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
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession(id: "s1")]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.updated event for a different project.
        eventController.add(
          SseEvent(
            data: SesoriSseEvent.sessionUpdated(
              info: const Session(
                id: "foreign-session",
                projectID: "project-other",
                directory: "/other/project",
                title: "Foreign Session Updated",
                time: SessionTime(created: 1, updated: 3),
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
          () => mockSessionService.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success([testSession(id: "s1")]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Emit a session.deleted event for a different project.
        eventController.add(
          SseEvent(
            data: SesoriSseEvent.sessionDeleted(
              info: const Session(
                id: "foreign-session",
                projectID: "project-other",
                directory: "/other/project",
                time: SessionTime(created: 1, updated: 2),
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
            title: "Under /tmp/foo",
            time: SessionTime(created: 1, updated: 2),
          ),
          Session(
            id: "s2",
            projectID: "global",
            directory: "/home/bar",
            title: "Under /home/bar",
            time: SessionTime(created: 3, updated: 4),
          ),
        ];
        when(() => mockSessionService.listSessions(projectId: "global")).thenAnswer(
          (_) async => ApiResponse.success(sessions),
        );
        return SessionListCubit(
          mockSessionService,
          mockConnectionService,
          mockSseEventRepository,
          projectId: "global",
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([
            testSession(id: "s1", title: "Session 1"),
            testSession(id: "s2", title: "Session 2"),
          ]),
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([
            testSession(id: "s1", title: "Session 1"),
            testSession(id: "s2", title: "Session 2"),
          ]),
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
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([
            testSession(id: "s1", title: "Session 1"),
          ]),
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
    // 22. activeSessionIds is empty when no activity for this project
    // -------------------------------------------------------------------------

    blocTest<SessionListCubit, SessionListState>(
      "activeSessionIds is empty when no activity for this project",
      build: () {
        when(() => mockSessionService.listSessions(projectId: projectId)).thenAnswer(
          (_) async => ApiResponse.success([
            testSession(id: "s1", title: "Session 1"),
          ]),
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
  });
}
