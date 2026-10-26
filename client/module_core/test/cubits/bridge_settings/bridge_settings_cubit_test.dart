import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/bridge_settings/bridge_settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/bridge_settings/bridge_settings_state.dart";
import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:sesori_dart_core/src/services/bridge_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsService() extends Mock implements BridgeSettingsService;

void main() {
  late _MockBridgeSettingsService service;
  late _FakeConnectionService connection;

  setUp(() {
    service = _MockBridgeSettingsService();
    connection = _FakeConnectionService(initialStatus: _connected);
    addTearDown(connection.dispose);
  });

  test("loads one aggregate snapshot", () async {
    _stubLoad(service, yoloEnabled: true);
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsReady>(cubit);

    final state = cubit.state as BridgeSettingsReady;
    expect(state.yoloEnabled, isTrue);
    expect(state.yoloMutation, isA<YoloMutationIdle>());
    expect((state.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isTrue);
    verify(service.load).called(1);
  });

  test("treats session-open warm-up as unsupported when an older aggregate omits it", () async {
    when(service.load).thenAnswer(
      (_) async => const BridgeSettingsLoadSupported(
        response: BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: false),
          warmUpPluginsOnSessionOpen: null,
        ),
      ),
    );
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsReady>(cubit);

    expect(
      (cubit.state as BridgeSettingsReady).pluginWarmupMutation,
      isA<PluginWarmupMutationUnsupported>(),
    );
  });

  test("a bridge without the settings route is unsupported", () async {
    when(service.load).thenAnswer((_) async => const BridgeSettingsLoadUnsupported());
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsUnsupported>(cubit);

    verify(service.load).called(1);
  });

  test("keeps setting mutation presentation independent", () async {
    _stubLoad(service, yoloEnabled: false);
    when(() => service.updateYolo(enabled: true)).thenAnswer(
      (_) async => YoloSettingsMutationFailure(error: ApiError.generic()),
    );
    when(() => service.updatePluginWarmup(enabled: false)).thenAnswer(
      (_) async => const PluginWarmupSettingsMutationCommitted(enabled: false),
    );
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);
    final afterYolo = cubit.state as BridgeSettingsReady;
    expect(afterYolo.yoloMutation, isA<YoloMutationFailed>());
    expect((afterYolo.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isTrue);

    await cubit.updatePluginWarmup(enabled: false, expectedState: afterYolo);
    final afterWarmup = cubit.state as BridgeSettingsReady;
    expect((afterWarmup.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isFalse);
    expect(afterWarmup.yoloMutation, isA<YoloMutationFailed>());
  });

  test("commits session-open warm-up without reloading the bridge", () async {
    _stubLoad(service, yoloEnabled: false);
    when(() => service.updatePluginWarmup(enabled: false)).thenAnswer(
      (_) async => const PluginWarmupSettingsMutationCommitted(enabled: false),
    );
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updatePluginWarmup(
      enabled: false,
      expectedState: cubit.state as BridgeSettingsReady,
    );

    final mutation = (cubit.state as BridgeSettingsReady).pluginWarmupMutation;
    expect((mutation as PluginWarmupMutationIdle).enabled, isFalse);
    verify(() => service.updatePluginWarmup(enabled: false)).called(1);
    verify(service.load).called(1);
  });

  test("unexpected load failures remain retryable", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      if (loadCalls == 1) throw StateError("unexpected load failure");
      return Future.value(_loadResult(yoloEnabled: false));
    });
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsFailure>(cubit);

    await cubit.refresh();

    expect(cubit.state, isA<BridgeSettingsReady>());
    expect(loadCalls, 2);
  });

  test("failed uncertain reconciliation affects only the mutated row", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return loadCalls == 1 ? _loadResult(yoloEnabled: false) : BridgeSettingsLoadFailure(error: ApiError.generic());
    });
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) async => const YoloSettingsMutationUncertain());
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);

    final state = cubit.state as BridgeSettingsReady;
    expect(state.yoloMutation, isA<YoloMutationUncertain>());
    expect((state.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isTrue);
  });

  test("closing during an aggregate load suppresses its late result", () async {
    final load = Completer<BridgeSettingsLoadResult>();
    when(service.load).thenAnswer((_) => load.future);
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    await _waitUntil(() => cubit.state is BridgeSettingsLoading);

    final close = cubit.close();
    load.complete(_loadResult(yoloEnabled: true));
    await close;

    expect(cubit.isClosed, isTrue);
  });

  test("reconciles an uncertain mutation with one aggregate reload", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return _loadResult(yoloEnabled: loadCalls > 1);
    });
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) async => const YoloSettingsMutationUncertain());
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);

    expect((cubit.state as BridgeSettingsReady).yoloEnabled, isTrue);
    expect(loadCalls, 2);
  });

  test("coalesces refresh requested during a mutation", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return _loadResult(yoloEnabled: false);
    });
    final mutation = Completer<YoloSettingsMutationResult>();
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) => mutation.future);
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    final update = cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);
    await _waitUntil(
      () => switch (cubit.state) {
        BridgeSettingsReady(yoloMutation: YoloMutationInProgress()) => true,
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

  test("fences obsolete loads across reconnect and ignores stale toggles", () async {
    final firstLoad = Completer<BridgeSettingsLoadResult>();
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      return loadCalls == 1 ? firstLoad.future : Future.value(_loadResult(yoloEnabled: false));
    });
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitUntil(() => loadCalls == 1);
    connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
    connection.emitStatus(_connected);
    firstLoad.complete(_loadResult(yoloEnabled: true));
    await _waitUntil(
      () => switch (cubit.state) {
        BridgeSettingsReady(yoloEnabled: false) => true,
        _ => false,
      },
    );
    final current = cubit.state;

    await cubit.updateYolo(
      enabled: false,
      expectedState: const BridgeSettingsReady(
        yoloEnabled: true,
        yoloMutation: YoloMutationIdle(),
        pluginWarmupMutation: PluginWarmupMutationIdle(enabled: true),
      ),
    );

    expect(cubit.state, same(current));
    verifyNever(() => service.updateYolo(enabled: any(named: "enabled")));
  });
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null);
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

BridgeSettingsLoadSupported _loadResult({required bool yoloEnabled}) {
  return BridgeSettingsLoadSupported(
    response: BridgeSettingsResponse(
      pullRequestRefresh: const PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      yolo: YoloSettingsResponse(enabled: yoloEnabled),
      warmUpPluginsOnSessionOpen: true,
    ),
  );
}

void _stubLoad(_MockBridgeSettingsService service, {required bool yoloEnabled}) {
  when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: yoloEnabled));
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
