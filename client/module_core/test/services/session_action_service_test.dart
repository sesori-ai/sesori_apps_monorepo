import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/repositories/models/session_cleanup_rejection.dart" as domain;
import "package:sesori_dart_core/src/services/models/session_cleanup_outcome.dart";
import "package:sesori_dart_core/src/services/models/session_delete_result.dart";
import "package:sesori_dart_core/src/services/session_action_service.dart";
import "package:sesori_dart_core/src/services/session_cleanup_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  const projectId = "project-1";
  late MockSessionRepository sessionRepository;
  late FakeSessionUnseenTracker unseen;
  late MockFailureReporter failureReporter;
  late SessionActionService actions;

  setUp(() {
    sessionRepository = MockSessionRepository();
    unseen = FakeSessionUnseenTracker();
    failureReporter = MockFailureReporter();
    when(
      () => failureReporter.recordFailure(
        error: any(named: "error"),
        stackTrace: any(named: "stackTrace"),
        uniqueIdentifier: any(named: "uniqueIdentifier"),
        fatal: any(named: "fatal"),
        reason: any(named: "reason"),
        information: any(named: "information"),
      ),
    ).thenAnswer((_) async {});
    actions = SessionActionService(
      sessionRepository: sessionRepository,
      sessionCleanupService: SessionCleanupService(repository: sessionRepository),
      sessionUnseenTracker: unseen,
      failureReporter: failureReporter,
    );
  });

  tearDown(() => unseen.onDispose());

  group("delete", () {
    void stubDelete(Future<ApiResponse<void>> Function() answer) => when(
      () => sessionRepository.deleteSession(
        sessionId: "s1",
        deleteWorktree: any(named: "deleteWorktree"),
        deleteSessionFolder: any(named: "deleteSessionFolder"),
        force: any(named: "force"),
      ),
    ).thenAnswer((_) => answer());

    Future<SessionDeleteResult> delete() =>
        actions.deleteSession(sessionId: "s1", deleteWorktree: true, deleteSessionFolder: false, force: false);

    test("returns the outcome", () async {
      stubDelete(() async => ApiResponse<void>.success(null));

      expect(
        await delete(),
        isA<SessionDeleted>().having((r) => r.outcome, "outcome", SessionCleanupOutcome.completed),
      );
    });

    test("returns a cleanup rejection for the force dialog", () async {
      const issue = CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main");
      const rejection = SessionCleanupRejection(issues: [issue]);
      stubDelete(
        () => throw domain.SessionCleanupRejectedException(
          rejection: domain.SessionCleanupRejection(issues: rejection.issues),
          innerError: const SessionCleanupApiRejectedException(rejection: rejection),
        ),
      );

      expect(
        await delete(),
        isA<SessionDeleteRejected>().having((r) => r.rejection.issues.single, "issue", issue),
      );
    });

    test("reports a failed request", () async {
      stubDelete(() async => ApiResponse<void>.error(ApiError.generic()));

      expect(await delete(), isA<SessionDeleteFailed>());
    });
  });

  group("mark read or unread", () {
    test("applies the change to the tracker before the bridge answers", () async {
      when(
        () => sessionRepository.markSessionSeen(sessionId: "s1", read: true),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final mark = actions.markSessionSeen(projectId: projectId, sessionId: "s1", read: true);
      expect(unseen.currentSessionUnseen[projectId]?["s1"]?.unseen, isFalse);
      await mark;

      expect(unseen.currentSessionUnseen[projectId]?["s1"]?.unseen, isFalse);
    });

    test("a failed request restores the tracker's previous value", () async {
      when(
        () => sessionRepository.markSessionSeen(sessionId: "s1", read: false),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      unseen.emitSessionUnseen({
        projectId: {"s1": (unseen: false, lastUserActivityAt: 42)},
      });

      await actions.markSessionSeen(projectId: projectId, sessionId: "s1", read: false);

      expect(unseen.currentSessionUnseen[projectId]?["s1"], (unseen: false, lastUserActivityAt: 42));
    });

    test("a thrown request drops an entry the tracker did not have", () async {
      when(() => sessionRepository.markSessionSeen(sessionId: "s1", read: true)).thenThrow(StateError("transport"));

      await actions.markSessionSeen(projectId: projectId, sessionId: "s1", read: true);

      expect(unseen.currentSessionUnseen[projectId]?.containsKey("s1"), isFalse);
    });
  });
}
