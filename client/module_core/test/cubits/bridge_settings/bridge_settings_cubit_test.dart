import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/bridge_settings/bridge_settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/bridge_settings/bridge_settings_state.dart";
import "package:sesori_dart_core/src/repositories/bridge_settings_repository.dart";
import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsRepository() extends Mock implements BridgeSettingsRepository;

void main() {
  late _MockBridgeSettingsRepository service;
  late _FakeConnectionService connection;

  setUp(() {
    service = _MockBridgeSettingsRepository();
    connection = _FakeConnectionService(initialStatus: _connected);
    addTearDown(connection.dispose);
  });

  test("loads one full aggregate snapshot", () async {
    _stubFullLoad(service, intervalSeconds: 30, yoloEnabled: true);
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsReadyFull>(cubit);

    final state = cubit.state as BridgeSettingsReadyFull;
    expect(state.pullRequestRefreshIntervalSeconds, 30);
    expect(state.yoloEnabled, isTrue);
    for (final input in ["14", " 45 ", "3601"]) {
      expect(cubit.validatePullRequestRefreshInput(input: input), PullRequestRefreshInputValidation.valid);
    }
    for (final input in ["", "15.5", "0", "-30"]) {
      expect(cubit.validatePullRequestRefreshInput(input: input), PullRequestRefreshInputValidation.invalid);
    }
    verify(service.load).called(1);
  });

  test("represents legacy PR-only support explicitly", () async {
    when(service.load).thenAnswer(
      (_) async => const BridgeSettingsLoadLegacyPartial(
        pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      ),
    );
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsReadyLegacyPartial>(cubit);

    expect((cubit.state as BridgeSettingsReadyLegacyPartial).pullRequestRefreshIntervalSeconds, 45);
  });

  test("keeps setting mutation presentation independent", () async {
    _stubFullLoad(service, intervalSeconds: 30, yoloEnabled: false);
    when(() => service.updatePullRequestRefresh(intervalSeconds: 45)).thenAnswer(
      (_) async => const PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 46),
      ),
    );
    when(() => service.updateYolo(enabled: true)).thenAnswer(
      (_) async => YoloSettingsMutationFailure(error: ApiError.generic()),
    );
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReadyFull>(cubit);

    await cubit.updatePullRequestRefresh(input: "45", expectedState: cubit.state as BridgeSettingsReadyFull);
    final afterPullRequest = cubit.state as BridgeSettingsReadyFull;
    expect(afterPullRequest.pullRequestRefreshIntervalSeconds, 46);
    expect(afterPullRequest.yoloMutation, isA<YoloMutationIdle>());

    await cubit.updateYolo(enabled: true, expectedState: afterPullRequest);
    final afterYolo = cubit.state as BridgeSettingsReadyFull;
    expect(afterYolo.pullRequestRefreshIntervalSeconds, 46);
    expect(afterYolo.yoloMutation, isA<YoloMutationFailed>());
  });

  test("keeps YOLO available when the PR mutation route is unsupported", () async {
    _stubFullLoad(service, intervalSeconds: 30, yoloEnabled: true);
    when(() => service.updatePullRequestRefresh(intervalSeconds: 45)).thenAnswer(
      (_) async => const PullRequestRefreshSettingsMutationUnsupported(),
    );
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReadyFull>(cubit);

    await cubit.updatePullRequestRefresh(input: "45", expectedState: cubit.state as BridgeSettingsReadyFull);

    final state = cubit.state as BridgeSettingsReadyFull;
    expect(state.pullRequestRefreshMutation, isA<PullRequestRefreshMutationUnsupported>());
    expect(state.yoloEnabled, isTrue);
    expect(state.yoloMutation, isA<YoloMutationIdle>());
  });

  test("retains bridge-reported PR bounds for later editor validation", () async {
    final bounds = PullRequestRefreshSettingsBounds(
      minimumIntervalSeconds: 20,
      maximumIntervalSeconds: 120,
    );
    _stubFullLoad(service, intervalSeconds: 30, yoloEnabled: false);
    when(() => service.updatePullRequestRefresh(intervalSeconds: 10)).thenAnswer(
      (_) async => PullRequestRefreshSettingsMutationRejected(bounds: bounds),
    );
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReadyFull>(cubit);

    await cubit.updatePullRequestRefresh(input: "10", expectedState: cubit.state as BridgeSettingsReadyFull);

    expect(cubit.validatePullRequestRefreshInput(input: "10"), PullRequestRefreshInputValidation.invalid);
    for (final input in ["", "15.5", "0", "-30", "19", "121"]) {
      expect(cubit.validatePullRequestRefreshInput(input: input), PullRequestRefreshInputValidation.invalid);
    }
    for (final input in ["20", " 45 ", "120"]) {
      expect(cubit.validatePullRequestRefreshInput(input: input), PullRequestRefreshInputValidation.valid);
    }
    expect((cubit.state as BridgeSettingsReadyFull).validationBounds, same(bounds));
  });

  test("unexpected load failures remain retryable", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      if (loadCalls == 1) throw StateError("unexpected load failure");
      return Future.value(_fullResult(intervalSeconds: 30, yoloEnabled: false));
    });
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsFailure>(cubit);

    await cubit.refresh();

    expect(cubit.state, isA<BridgeSettingsReadyFull>());
    expect(loadCalls, 2);
  });

  test("failed uncertain reconciliation affects only the mutated row", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return loadCalls == 1
          ? _fullResult(intervalSeconds: 30, yoloEnabled: false)
          : BridgeSettingsLoadFailure(error: ApiError.generic());
    });
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) async => const YoloSettingsMutationUncertain());
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReadyFull>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReadyFull);

    final state = cubit.state as BridgeSettingsReadyFull;
    expect(state.yoloMutation, isA<YoloMutationUncertain>());
    expect(state.pullRequestRefreshIntervalSeconds, 30);
    expect(state.pullRequestRefreshMutation, isA<PullRequestRefreshMutationIdle>());
  });

  test("closing during an aggregate load suppresses its late result", () async {
    final load = Completer<BridgeSettingsLoadResult>();
    when(service.load).thenAnswer((_) => load.future);
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    await _waitUntil(() => cubit.state is BridgeSettingsLoading);

    final close = cubit.close();
    load.complete(_fullResult(intervalSeconds: 30, yoloEnabled: true));
    await close;

    expect(cubit.isClosed, isTrue);
  });

  test("reconciles an uncertain mutation with one aggregate reload", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return _fullResult(intervalSeconds: 30, yoloEnabled: loadCalls > 1);
    });
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) async => const YoloSettingsMutationUncertain());
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReadyFull>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReadyFull);

    expect((cubit.state as BridgeSettingsReadyFull).yoloEnabled, isTrue);
    expect(loadCalls, 2);
  });

  test("coalesces refresh requested during a mutation", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return _fullResult(intervalSeconds: 30, yoloEnabled: false);
    });
    final mutation = Completer<YoloSettingsMutationResult>();
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) => mutation.future);
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReadyFull>(cubit);

    final update = cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReadyFull);
    await _waitUntil(
      () => switch (cubit.state) {
        BridgeSettingsReadyFull(yoloMutation: YoloMutationInProgress()) => true,
        _ => false,
      },
    );
    await cubit.refresh();
    await cubit.refresh();
    mutation.complete(
      const YoloSettingsMutationCommitted(response: YoloSettingsResponse(enabled: true)),
    );
    await update;
    await _waitUntil(() => loadCalls >= 2);

    verify(service.load).called(2);
  });

  test("fences obsolete loads across reconnect and rejects stale editors", () async {
    final firstLoad = Completer<BridgeSettingsLoadResult>();
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      return loadCalls == 1 ? firstLoad.future : Future.value(_fullResult(intervalSeconds: 60, yoloEnabled: false));
    });
    final cubit = BridgeSettingsCubit(repository: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitUntil(() => loadCalls == 1);
    connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
    connection.emitStatus(_connected);
    firstLoad.complete(_fullResult(intervalSeconds: 30, yoloEnabled: false));
    await _waitUntil(
      () => switch (cubit.state) {
        BridgeSettingsReadyFull(pullRequestRefreshIntervalSeconds: 60) => true,
        _ => false,
      },
    );
    final current = cubit.state as BridgeSettingsReadyFull;

    final acceptance = await cubit.updatePullRequestRefresh(
      input: "45",
      expectedState: const BridgeSettingsReadyFull(
        pullRequestRefreshIntervalSeconds: 30,
        pullRequestRefreshMutation: PullRequestRefreshMutationIdle(validationBounds: null),
        yoloEnabled: false,
        yoloMutation: YoloMutationIdle(),
      ),
    );

    expect(acceptance, BridgeSettingsUpdateAcceptance.rejected);
    expect(current.pullRequestRefreshIntervalSeconds, 60);
  });
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: null);
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

BridgeSettingsLoadSupported _fullResult({required int intervalSeconds, required bool yoloEnabled}) {
  return BridgeSettingsLoadSupported(
    response: BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: intervalSeconds),
      yolo: YoloSettingsResponse(enabled: yoloEnabled),
    ),
  );
}

void _stubFullLoad(
  _MockBridgeSettingsRepository service, {
  required int intervalSeconds,
  required bool yoloEnabled,
}) {
  when(service.load).thenAnswer(
    (_) async => _fullResult(intervalSeconds: intervalSeconds, yoloEnabled: yoloEnabled),
  );
}

Future<void> _waitForState<T extends BridgeSettingsState>(BridgeSettingsCubit cubit) async {
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

final class _FakeConnectionService({required ConnectionStatus initialStatus}) implements ConnectionService {
  final BehaviorSubject<ConnectionStatus> _statuses = BehaviorSubject.seeded(initialStatus);

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
