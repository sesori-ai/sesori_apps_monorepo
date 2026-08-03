import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/pull_request_refresh_settings/pull_request_refresh_settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/pull_request_refresh_settings/pull_request_refresh_settings_state.dart";
import "package:sesori_dart_core/src/repositories/models/pull_request_refresh_settings_result.dart";
import "package:sesori_dart_core/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockPullRequestRefreshSettingsService extends Mock implements PullRequestRefreshSettingsService {}

void main() {
  late _MockPullRequestRefreshSettingsService service;
  late _FakeConnectionService connection;

  setUpAll(() {
    registerFallbackValue(const PullRequestRefreshSettingsRequest(intervalSeconds: 30));
  });

  setUp(() {
    service = _MockPullRequestRefreshSettingsService();
    connection = _FakeConnectionService(initialStatus: _connected);
    addTearDown(connection.dispose);
  });

  test("loads the committed bridge value", () async {
    _stubLoad(service, intervalSeconds: 30);
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    expect((cubit.state as PullRequestRefreshSettingsReady).intervalSeconds, 30);
  });

  test("surfaces unsupported old bridges and retryable load failures", () async {
    when(service.load).thenAnswer((_) async => const PullRequestRefreshSettingsLoadUnsupported());
    final unsupported = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(unsupported.close);
    await _waitForState<PullRequestRefreshSettingsUnsupported>(unsupported);

    when(service.load).thenAnswer(
      (_) async => PullRequestRefreshSettingsLoadFailure(error: ApiError.generic()),
    );
    final failed = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(failed.close);
    await _waitForState<PullRequestRefreshSettingsFailure>(failed);

    _stubLoad(service, intervalSeconds: 30);
    await failed.refresh();
    expect(failed.state, isA<PullRequestRefreshSettingsReady>());
  });

  test("invalid input dispatches no mutation", () async {
    _stubLoad(service, intervalSeconds: 30);
    when(
      () => service.planUpdate(input: "bad", bounds: null),
    ).thenReturn(const PullRequestRefreshSettingsUpdateInvalid());
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    await cubit.update(input: "bad");

    expect((cubit.state as PullRequestRefreshSettingsReady).mutation, isA<PullRequestRefreshSettingsMutationFailed>());
    verifyNever(() => service.update(request: any(named: "request")));
  });

  test("delegates input validation to the service plan", () async {
    _stubLoad(service, intervalSeconds: 30);
    when(
      () => service.planUpdate(input: "14", bounds: null),
    ).thenReturn(const PullRequestRefreshSettingsUpdateInvalid());
    _stubPlan(service, input: "45", intervalSeconds: 45);
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    expect(
      cubit.validateUpdateInput(input: "14"),
      PullRequestRefreshSettingsInputValidation.invalid,
    );
    expect(
      cubit.validateUpdateInput(input: "45"),
      PullRequestRefreshSettingsInputValidation.valid,
    );
    verify(() => service.planUpdate(input: "14", bounds: null)).called(1);
    verify(() => service.planUpdate(input: "45", bounds: null)).called(1);
  });

  test("successful update publishes the bridge-committed value", () async {
    _stubLoad(service, intervalSeconds: 30);
    _stubPlan(service, input: "45", intervalSeconds: 45);
    when(
      () => service.update(request: any(named: "request")),
    ).thenAnswer(
      (_) async => const PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 46),
      ),
    );
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    await cubit.update(input: "45");

    final state = cubit.state as PullRequestRefreshSettingsReady;
    expect(state.intervalSeconds, 46);
    expect(state.mutation, isA<PullRequestRefreshSettingsMutationIdle>());
  });

  test("uncertain mutation refreshes before another update can be sent", () async {
    final reconciliation = Completer<PullRequestRefreshSettingsLoadResult>();
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      return loadCalls == 1
          ? Future.value(
              const PullRequestRefreshSettingsLoadSupported(
                response: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
              ),
            )
          : reconciliation.future;
    });
    _stubPlan(service, input: "45", intervalSeconds: 45);
    _stubPlan(service, input: "60", intervalSeconds: 60);
    var updateCalls = 0;
    when(
      () => service.update(request: any(named: "request")),
    ).thenAnswer((_) async {
      updateCalls++;
      return updateCalls == 1
          ? const PullRequestRefreshSettingsMutationUncertain()
          : const PullRequestRefreshSettingsMutationCommitted(
              response: PullRequestRefreshSettingsResponse(intervalSeconds: 60),
            );
    });
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    final firstUpdate = cubit.update(input: "45");
    await _waitUntil(() => loadCalls == 2);
    await cubit.update(input: "60");
    expect(updateCalls, 1);

    reconciliation.complete(
      PullRequestRefreshSettingsLoadFailure(error: ApiError.generic()),
    );
    await firstUpdate;
    expect(cubit.state, isA<PullRequestRefreshSettingsUncertain>());

    _stubLoad(service, intervalSeconds: 45);
    await cubit.refresh();
    await cubit.update(input: "60");
    expect(updateCalls, 2);
    expect((cubit.state as PullRequestRefreshSettingsReady).intervalSeconds, 60);
  });

  test("waits for a connection and fences an obsolete load across reconnect", () async {
    connection.emitStatus(const ConnectionStatus.disconnected());
    final firstLoad = Completer<PullRequestRefreshSettingsLoadResult>();
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      return loadCalls == 1
          ? firstLoad.future
          : Future.value(
              const PullRequestRefreshSettingsLoadSupported(
                response: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
              ),
            );
    });
    final publishedIntervals = <int>[];
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    final subscription = cubit.stream.listen((state) {
      if (state case PullRequestRefreshSettingsReady(:final intervalSeconds)) {
        publishedIntervals.add(intervalSeconds);
      }
    });
    addTearDown(subscription.cancel);

    expect(cubit.state, isA<PullRequestRefreshSettingsDisconnected>());
    await Future<void>.delayed(Duration.zero);
    expect(loadCalls, 0);

    connection.emitStatus(_connected);
    await _waitUntil(() => loadCalls == 1);
    connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
    connection.emitStatus(_connected);
    firstLoad.complete(
      const PullRequestRefreshSettingsLoadSupported(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 99),
      ),
    );

    await _waitUntil(
      () => switch (cubit.state) {
        PullRequestRefreshSettingsReady(intervalSeconds: 45) => true,
        _ => false,
      },
    );
    expect(publishedIntervals, [45]);
    expect(loadCalls, 2);
  });

  test("fences an obsolete mutation response and reloads the new bridge", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer(
      (_) async => PullRequestRefreshSettingsLoadSupported(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: loadCalls++ == 0 ? 30 : 60),
      ),
    );
    _stubPlan(service, input: "45", intervalSeconds: 45);
    final mutation = Completer<PullRequestRefreshSettingsMutationResult>();
    when(() => service.update(request: any(named: "request"))).thenAnswer((_) => mutation.future);
    final publishedIntervals = <int>[];
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    final subscription = cubit.stream.listen((state) {
      if (state case PullRequestRefreshSettingsReady(:final intervalSeconds)) {
        publishedIntervals.add(intervalSeconds);
      }
    });
    addTearDown(subscription.cancel);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    final update = cubit.update(input: "45");
    await _waitUntil(
      () => switch (cubit.state) {
        PullRequestRefreshSettingsReady(mutation: PullRequestRefreshSettingsMutationInProgress()) => true,
        _ => false,
      },
    );
    connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
    connection.emitStatus(_connected);
    mutation.complete(
      const PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      ),
    );
    await update;

    await _waitUntil(
      () => switch (cubit.state) {
        PullRequestRefreshSettingsReady(intervalSeconds: 60) => true,
        _ => false,
      },
    );
    expect(publishedIntervals, [30, 30, 60]);
    expect(loadCalls, 2);
  });

  test("an unexpected load failure stays observable and does not wedge retry", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      if (loadCalls == 1) throw StateError("unexpected load failure");
      return Future.value(
        const PullRequestRefreshSettingsLoadSupported(
          response: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
        ),
      );
    });
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<PullRequestRefreshSettingsFailure>(cubit);
    await cubit.refresh();

    expect(cubit.state, isA<PullRequestRefreshSettingsReady>());
    expect(loadCalls, 2);
  });

  test("an unexpected update failure stays observable and does not wedge mutation", () async {
    _stubLoad(service, intervalSeconds: 30);
    _stubPlan(service, input: "45", intervalSeconds: 45);
    var updateCalls = 0;
    when(() => service.update(request: any(named: "request"))).thenAnswer((_) {
      updateCalls++;
      if (updateCalls == 1) throw StateError("unexpected update failure");
      return Future.value(
        const PullRequestRefreshSettingsMutationCommitted(
          response: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
        ),
      );
    });
    final cubit = PullRequestRefreshSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<PullRequestRefreshSettingsReady>(cubit);

    await cubit.update(input: "45");
    expect(
      (cubit.state as PullRequestRefreshSettingsReady).mutation,
      isA<PullRequestRefreshSettingsMutationFailed>(),
    );

    await cubit.update(input: "45");
    expect((cubit.state as PullRequestRefreshSettingsReady).intervalSeconds, 45);
    expect(updateCalls, 2);
  });
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com");
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

void _stubLoad(_MockPullRequestRefreshSettingsService service, {required int intervalSeconds}) {
  when(service.load).thenAnswer(
    (_) async => PullRequestRefreshSettingsLoadSupported(
      response: PullRequestRefreshSettingsResponse(intervalSeconds: intervalSeconds),
    ),
  );
}

void _stubPlan(
  _MockPullRequestRefreshSettingsService service, {
  required String input,
  required int intervalSeconds,
}) {
  when(
    () => service.planUpdate(input: input, bounds: null),
  ).thenReturn(
    PullRequestRefreshSettingsUpdateRequest(
      request: PullRequestRefreshSettingsRequest(intervalSeconds: intervalSeconds),
    ),
  );
}

Future<void> _waitForState<T extends PullRequestRefreshSettingsState>(PullRequestRefreshSettingsCubit cubit) async {
  if (cubit.state is T) return;
  await cubit.stream.firstWhere((state) => state is T);
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("Condition was not reached");
}

final class _FakeConnectionService implements ConnectionService {
  _FakeConnectionService({required ConnectionStatus initialStatus}) : _statuses = BehaviorSubject.seeded(initialStatus);

  final BehaviorSubject<ConnectionStatus> _statuses;

  @override
  ConnectionStatus get currentStatus => _statuses.value;

  @override
  ValueStream<ConnectionStatus> get status => _statuses.stream;

  void emitStatus(ConnectionStatus status) => _statuses.add(status);

  @override
  Future<void> dispose() => _statuses.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
