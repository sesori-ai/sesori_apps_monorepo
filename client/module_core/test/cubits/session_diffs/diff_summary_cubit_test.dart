import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/session_diffs/diff_summary_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_diffs/diff_summary_state.dart";
import "package:sesori_dart_core/src/repositories/models/session_diff_summary_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("DiffSummaryCubit", () {
    const sessionId = "session-1";
    const interval = Duration(seconds: 2);
    late MockSessionRepository repository;
    late MockConnectionService connectionService;
    late StreamController<SesoriSessionEvent> sessionEvents;
    late SessionDiffSummaryResult nextResult;
    late int requests;

    setUp(() {
      repository = MockSessionRepository();
      connectionService = MockConnectionService();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      requests = 0;
      nextResult = const SessionDiffSummaryAvailable(additions: 12, deletions: 2);
      when(() => connectionService.sessionEvents(sessionId)).thenAnswer((_) => sessionEvents.stream);
      when(() => repository.getSessionDiffSummary(sessionId: sessionId)).thenAnswer((_) async {
        requests++;
        return nextResult;
      });
    });

    DiffSummaryCubit buildCubit() => DiffSummaryCubit(
      sessionRepository: repository,
      connectionService: connectionService,
      sessionId: sessionId,
      refreshInterval: interval,
    );

    const diffEvent = SesoriSessionDiff(sessionID: sessionId);

    test("loads the totals, then refreshes on file changes at most once per interval", () {
      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();
        expect(cubit.state, const DiffSummaryState.counts(additions: 12, deletions: 2));
        expect(requests, 1);

        nextResult = const SessionDiffSummaryAvailable(additions: 20, deletions: 3);
        for (var i = 0; i < 5; i++) {
          sessionEvents.add(diffEvent);
        }
        async.flushMicrotasks();
        expect(requests, 2);

        async.elapse(interval);
        expect(requests, 3);
        expect(cubit.state, const DiffSummaryState.counts(additions: 20, deletions: 3));

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test("stops asking once the bridge predates the request", () {
      fakeAsync((async) {
        nextResult = const SessionDiffSummaryUnsupported();
        final cubit = buildCubit();
        async.flushMicrotasks();

        sessionEvents.add(diffEvent);
        async.elapse(interval * 2);

        expect(requests, 1);
        expect(cubit.state, const DiffSummaryState.unknown());
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test("keeps the last totals when a refresh fails", () {
      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();

        nextResult = SessionDiffSummaryFailure(
          error: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "git diff --numstat failed"),
        );
        sessionEvents.add(diffEvent);
        async.flushMicrotasks();

        expect(requests, 2);
        expect(cubit.state, const DiffSummaryState.counts(additions: 12, deletions: 2));
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });
  });
}
