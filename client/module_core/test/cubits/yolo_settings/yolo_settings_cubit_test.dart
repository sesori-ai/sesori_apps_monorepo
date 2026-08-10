import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/yolo_settings/yolo_settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/yolo_settings/yolo_settings_state.dart";
import "package:sesori_dart_core/src/repositories/models/yolo_settings_result.dart";
import "package:sesori_dart_core/src/repositories/yolo_settings_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockYoloSettingsRepository extends Mock implements YoloSettingsRepository {}

void main() {
  late _MockYoloSettingsRepository repository;
  late _FakeConnectionService connection;

  setUp(() {
    repository = _MockYoloSettingsRepository();
    connection = _FakeConnectionService(initialStatus: _connected);
    addTearDown(connection.dispose);
  });

  test("loads the authoritative value and surfaces old bridges", () async {
    _stubLoad(repository, enabled: false);
    final cubit = YoloSettingsCubit(repository: repository, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<YoloSettingsReady>(cubit);
    expect((cubit.state as YoloSettingsReady).enabled, isFalse);

    when(repository.load).thenAnswer((_) async => const YoloSettingsLoadUnsupported());
    await cubit.refresh();
    expect(cubit.state, isA<YoloSettingsUnsupported>());
  });

  test("keeps the committed value while updating and publishes the response", () async {
    _stubLoad(repository, enabled: false);
    final mutation = Completer<YoloSettingsMutationResult>();
    when(() => repository.update(enabled: true)).thenAnswer((_) => mutation.future);
    final cubit = YoloSettingsCubit(repository: repository, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<YoloSettingsReady>(cubit);
    final ready = cubit.state as YoloSettingsReady;

    final update = cubit.update(enabled: true, expectedState: ready);
    await _waitUntil(() => (cubit.state as YoloSettingsReady).mutation is YoloSettingsMutationInProgress);
    expect((cubit.state as YoloSettingsReady).enabled, isFalse);
    mutation.complete(
      const YoloSettingsMutationCommitted(response: YoloSettingsResponse(enabled: true)),
    );
    await update;

    expect((cubit.state as YoloSettingsReady).enabled, isTrue);
    expect((cubit.state as YoloSettingsReady).mutation, isA<YoloSettingsMutationIdle>());
  });

  test("uncertain mutation reloads authoritatively before allowing another update", () async {
    var loads = 0;
    when(repository.load).thenAnswer(
      (_) async => YoloSettingsLoadSupported(response: YoloSettingsResponse(enabled: loads++ > 0)),
    );
    when(() => repository.update(enabled: true)).thenAnswer((_) async => const YoloSettingsMutationUncertain());
    final cubit = YoloSettingsCubit(repository: repository, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<YoloSettingsReady>(cubit);

    await cubit.update(enabled: true, expectedState: cubit.state as YoloSettingsReady);

    expect(loads, 2);
    expect((cubit.state as YoloSettingsReady).enabled, isTrue);
  });

  test("reloads on reconnection and fences the obsolete bridge response", () async {
    connection.emitStatus(const ConnectionStatus.disconnected());
    final firstLoad = Completer<YoloSettingsLoadResult>();
    var loads = 0;
    when(repository.load).thenAnswer((_) {
      loads++;
      return loads == 1
          ? firstLoad.future
          : Future.value(const YoloSettingsLoadSupported(response: YoloSettingsResponse(enabled: true)));
    });
    final cubit = YoloSettingsCubit(repository: repository, connectionService: connection);
    addTearDown(cubit.close);
    expect(cubit.state, isA<YoloSettingsDisconnected>());

    connection.emitStatus(_connected);
    await _waitUntil(() => loads == 1);
    connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
    connection.emitStatus(_connected);
    firstLoad.complete(const YoloSettingsLoadSupported(response: YoloSettingsResponse(enabled: false)));
    await _waitUntil(
      () => switch (cubit.state) {
        YoloSettingsReady(enabled: true) => true,
        _ => false,
      },
    );

    expect(loads, 2);
  });
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com");
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

void _stubLoad(_MockYoloSettingsRepository repository, {required bool enabled}) {
  when(repository.load).thenAnswer(
    (_) async => YoloSettingsLoadSupported(response: YoloSettingsResponse(enabled: enabled)),
  );
}

Future<void> _waitForState<T extends YoloSettingsState>(YoloSettingsCubit cubit) async {
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
