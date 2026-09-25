import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/repositories/bridge_settings_repository.dart";
import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:sesori_dart_core/src/services/bridge_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsRepository() extends Mock implements BridgeSettingsRepository;

void main() {
  late _MockBridgeSettingsRepository repository;
  late BehaviorSubject<ConnectionStatus> statuses;
  late _MockConnectionService connection;

  setUp(() {
    repository = _MockBridgeSettingsRepository();
    statuses = BehaviorSubject.seeded(const ConnectionStatus.disconnected());
    connection = _MockConnectionService();
    when(() => connection.status).thenAnswer((_) => statuses.stream);
    addTearDown(statuses.close);
  });

  BridgeSettingsService buildService() {
    final service = BridgeSettingsService(repository: repository, connectionService: connection);
    addTearDown(service.onDispose);
    return service;
  }

  test("loads the YOLO flag when the bridge connects", () async {
    when(repository.load).thenAnswer((_) async => _loaded(yoloEnabled: true));
    final service = buildService();
    expect(service.yoloSettings.value.enabled, isFalse);
    verifyNever(repository.load);

    statuses.add(_connected);

    await expectLater(service.yoloSettings, emitsThrough(const YoloSettingsResponse(enabled: true)));
    verify(repository.load).called(1);
  });

  test("keeps the last-known flag when the load fails", () async {
    when(repository.load).thenAnswer((_) async => _loaded(yoloEnabled: true));
    final service = buildService();
    await service.load();

    when(repository.load).thenAnswer((_) async => BridgeSettingsLoadFailure(error: ApiError.generic()));
    await service.load();

    expect(service.yoloSettings.value.enabled, isTrue);
  });

  test("an older bridge without the setting reads as off", () async {
    when(repository.load).thenAnswer((_) async => _loaded(yoloEnabled: true));
    final service = buildService();
    await service.load();

    when(repository.load).thenAnswer((_) async => const BridgeSettingsLoadUnsupported());
    await service.load();

    expect(service.yoloSettings.value.enabled, isFalse);
  });

  test("a committed YOLO save updates the stream", () async {
    when(() => repository.updateYolo(enabled: true)).thenAnswer(
      (_) async => const YoloSettingsMutationCommitted(response: YoloSettingsResponse(enabled: true)),
    );
    final service = buildService();

    final result = await service.updateYolo(enabled: true);

    expect(result, isA<YoloSettingsMutationCommitted>());
    expect(service.yoloSettings.value.enabled, isTrue);
  });

  test("a committed YOLO save keeps the loaded per-session support", () async {
    when(repository.load).thenAnswer(
      (_) async => const BridgeSettingsLoadSupported(
        response: BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 60),
          yolo: YoloSettingsResponse(enabled: false, supportsSessionOverride: true),
          warmUpPluginsOnSessionOpen: true,
        ),
      ),
    );
    when(() => repository.updateYolo(enabled: true)).thenAnswer(
      (_) async => const YoloSettingsMutationCommitted(response: YoloSettingsResponse(enabled: true)),
    );
    final service = buildService();
    await service.load();

    await service.updateYolo(enabled: true);

    expect(service.yoloSettings.value, const YoloSettingsResponse(enabled: true, supportsSessionOverride: true));
  });

  test("a failed YOLO save leaves the stream unchanged", () async {
    when(() => repository.updateYolo(enabled: true)).thenAnswer(
      (_) async => YoloSettingsMutationFailure(error: ApiError.generic()),
    );
    final service = buildService();

    await service.updateYolo(enabled: true);

    expect(service.yoloSettings.value.enabled, isFalse);
  });
}

class _MockConnectionService() extends Mock implements ConnectionService;

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: null);
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

BridgeSettingsLoadSupported _loaded({required bool yoloEnabled}) {
  return BridgeSettingsLoadSupported(
    response: BridgeSettingsResponse(
      pullRequestRefresh: const PullRequestRefreshSettingsResponse(intervalSeconds: 60),
      yolo: YoloSettingsResponse(enabled: yoloEnabled),
      warmUpPluginsOnSessionOpen: true,
    ),
  );
}
