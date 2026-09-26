import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

void main() {
  late MockSessionRepository repository;
  late SessionCleanupService service;

  setUp(() {
    repository = MockSessionRepository();
    service = SessionCleanupService(repository: repository);
  });

  /// The refusal the bridge answers a cleanup request with.
  SessionCleanupRejectedException refusal(List<shared.CleanupIssue> issues) {
    final rejection = shared.SessionCleanupRejection(issues: issues);
    return SessionCleanupRejectedException(
      rejection: SessionCleanupRejection(issues: rejection.issues),
      innerError: SessionCleanupApiRejectedException(rejection: rejection),
    );
  }

  void stubDelete({required bool deleteWorktree, required List<shared.CleanupIssue>? refusedWith}) {
    final call = when(
      () => repository.deleteSession(sessionId: "s1", deleteWorktree: deleteWorktree, force: false),
    );
    if (refusedWith == null) {
      call.thenAnswer((_) async => ApiResponse<void>.success(null));
    } else {
      call.thenThrow(refusal(refusedWith));
    }
  }

  test("a worktree another live session shares is retried once without cleanup, and kept", () async {
    stubDelete(deleteWorktree: true, refusedWith: const [shared.CleanupIssue.sharedWorktree()]);
    stubDelete(deleteWorktree: false, refusedWith: null);

    final response = await service.deleteSession(sessionId: "s1", deleteWorktree: true, force: false);

    expect(
      response,
      isA<SuccessResponse<SessionCleanupOutcome>>().having(
        (success) => success.data,
        "data",
        SessionCleanupOutcome.sharedWorktreeKept,
      ),
    );
    verify(() => repository.deleteSession(sessionId: "s1", deleteWorktree: false, force: false)).called(1);
  });

  test("a refusal that names no issue is never retried", () async {
    stubDelete(deleteWorktree: true, refusedWith: const []);

    await expectLater(
      service.deleteSession(sessionId: "s1", deleteWorktree: true, force: false),
      throwsA(isA<SessionCleanupRejectedException>()),
    );
    verifyNever(() => repository.deleteSession(sessionId: "s1", deleteWorktree: false, force: false));
  });

  test("a refusal without worktree cleanup requested is not retried again", () async {
    stubDelete(deleteWorktree: false, refusedWith: const [shared.CleanupIssue.sharedWorktree()]);

    await expectLater(
      service.deleteSession(sessionId: "s1", deleteWorktree: false, force: false),
      throwsA(isA<SessionCleanupRejectedException>()),
    );
    verify(() => repository.deleteSession(sessionId: "s1", deleteWorktree: false, force: false)).called(1);
  });
}
