import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
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
    late BehaviorSubject<ConnectionStatus> status;
    late Future<SessionDiffSummaryResult> Function() nextResponse;
    late SessionDiffSummaryResult nextResult;
    late int requests;

    setUp(() {
      repository = MockSessionRepository();
      connectionService = MockConnectionService();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      requests = 0;
      status = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
      nextResult = const SessionDiffSummaryAvailable(additions: 12, deletions: 2);
      nextResponse = () async => nextResult;
      when(() => connectionService.sessionEvents(sessionId)).thenAnswer((_) => sessionEvents.stream);
      when(() => connectionService.status).thenAnswer((_) => status.stream);
      when(() => repository.getSessionDiffSummary(sessionId: sessionId)).thenAnswer((_) {
        requests++;
        return nextResponse();
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

    test("runs one refresh at a time, then the queued one, so the newest totals win", () {
      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();

        final older = Completer<SessionDiffSummaryResult>();
        final newer = Completer<SessionDiffSummaryResult>();
        final responses = [older, newer];
        nextResponse = () => responses.removeAt(0).future;
        sessionEvents.add(diffEvent);
        async.flushMicrotasks();
        connectionService.emitDataMayBeStale();
        connectionService.emitDataMayBeStale();
        async.flushMicrotasks();
        expect(requests, 2);

        older.complete(const SessionDiffSummaryAvailable(additions: 1, deletions: 1));
        async.flushMicrotasks();
        expect(requests, 3);
        newer.complete(const SessionDiffSummaryAvailable(additions: 5, deletions: 4));
        async.flushMicrotasks();

        expect(requests, 3);
        expect(cubit.state, const DiffSummaryState.counts(additions: 5, deletions: 4));
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test("a failed refresh still runs the refresh queued behind it", () {
      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();

        final failing = Completer<SessionDiffSummaryResult>();
        nextResponse = () => failing.future;
        connectionService.emitDataMayBeStale();
        async.flushMicrotasks();
        connectionService.emitDataMayBeStale();
        async.flushMicrotasks();
        expect(requests, 2);

        nextResponse = () async => const SessionDiffSummaryAvailable(additions: 7, deletions: 0);
        failing.completeError(StateError("relay dropped"));
        async.flushMicrotasks();

        expect(requests, 3);
        expect(cubit.state, const DiffSummaryState.counts(additions: 7, deletions: 0));
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test("refreshes after a reconnect and when data may be stale", () {
      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();
        expect(requests, 1);

        status.add(
          const ConnectionStatus.connected(
            config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
            health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
          ),
        );
        async.flushMicrotasks();
        expect(requests, 2);

        connectionService.emitDataMayBeStale();
        async.flushMicrotasks();
        expect(requests, 3);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });
  });
}
