import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

class _MockSessionRepository() extends Mock implements SessionRepository;

void main() {
  late _MockSessionRepository repository;
  late PendingSessionArchiveCubit cubit;
  late List<PendingSessionArchiveOutcome> outcomes;
  final first = testSession(id: "first");
  final second = testSession(id: "second");

  void stubArchive({required String sessionId, required Future<ApiResponse<shared.Session>> Function() answer}) {
    when(
      () => repository.archiveSession(
        sessionId: sessionId,
        deleteWorktree: any(named: "deleteWorktree"),
        force: any(named: "force"),
      ),
    ).thenAnswer((_) => answer());
  }

  setUp(() {
    repository = _MockSessionRepository();
    cubit = PendingSessionArchiveCubit(repository: repository);
    outcomes = [];
    cubit.outcomes.listen(outcomes.add);
  });

  test("Undo inside the window sends nothing and brings the row back", () {
    fakeAsync((async) {
      cubit.archive(session: first, deleteWorktree: true);
      expect(cubit.state.hiddenIds, {"first"});

      cubit.undo();
      async.elapse(PendingSessionArchiveCubit.undoWindow * 2);

      expect(cubit.state.hiddenIds, isEmpty);
      verifyNever(
        () => repository.archiveSession(
          sessionId: any(named: "sessionId"),
          deleteWorktree: any(named: "deleteWorktree"),
          force: any(named: "force"),
        ),
      );
    });
  });

  test("the timer commits through the repository and the id stays hidden without any event", () {
    fakeAsync((async) {
      stubArchive(sessionId: "first", answer: () async => ApiResponse.success(first));

      cubit.archive(session: first, deleteWorktree: false);
      async.elapse(PendingSessionArchiveCubit.undoWindow);

      verify(() => repository.archiveSession(sessionId: "first", deleteWorktree: false, force: false)).called(1);
      expect(outcomes.single, isA<PendingSessionArchiveCommitted>());
      expect(cubit.state.window, isA<PendingArchiveIdle>());
      expect(cubit.state.hiddenIds, {"first"});
    });
  });

  test("a second archive commits the first, whose late refusal leaves the second window intact", () {
    fakeAsync((async) {
      final firstReply = Completer<ApiResponse<shared.Session>>();
      stubArchive(sessionId: "first", answer: () => firstReply.future);

      cubit
        ..archive(session: first, deleteWorktree: true)
        ..archive(session: second, deleteWorktree: true);
      async.flushMicrotasks();
      verify(() => repository.archiveSession(sessionId: "first", deleteWorktree: true, force: false)).called(1);
      expect(cubit.state.hiddenIds, {"first", "second"});

      const rejection = shared.SessionCleanupRejection(issues: [shared.CleanupIssue.unstagedChanges()]);
      firstReply.completeError(
        SessionCleanupRejectedException(
          rejection: SessionCleanupRejection(issues: rejection.issues),
          innerError: const SessionCleanupApiRejectedException(rejection: rejection),
        ),
      );
      async.flushMicrotasks();

      expect(outcomes.single, isA<PendingSessionArchiveRefused>().having((o) => o.session.id, "session", "first"));
      expect(cubit.state.window, isA<PendingArchiveOpen>().having((w) => w.session.id, "session", "second"));
      expect(cubit.state.hiddenIds, {"second"});
    });
  });

  test("any other failure reports failed and the row returns", () {
    fakeAsync((async) {
      stubArchive(sessionId: "first", answer: () async => ApiResponse.error(ApiError.generic()));
      stubArchive(sessionId: "second", answer: () async => throw StateError("connection lost"));

      cubit.archive(session: first, deleteWorktree: true);
      async.elapse(PendingSessionArchiveCubit.undoWindow);
      cubit.archive(session: second, deleteWorktree: true);
      async.elapse(PendingSessionArchiveCubit.undoWindow);

      expect(outcomes, [isA<PendingSessionArchiveFailed>(), isA<PendingSessionArchiveFailed>()]);
      expect(cubit.state.hiddenIds, isEmpty);
    });
  });

  test("closing inside the window sends nothing", () {
    fakeAsync((async) {
      cubit.archive(session: first, deleteWorktree: true);
      unawaited(cubit.close());
      async.elapse(PendingSessionArchiveCubit.undoWindow * 2);

      verifyNever(
        () => repository.archiveSession(
          sessionId: any(named: "sessionId"),
          deleteWorktree: any(named: "deleteWorktree"),
          force: any(named: "force"),
        ),
      );
    });
  });
}
