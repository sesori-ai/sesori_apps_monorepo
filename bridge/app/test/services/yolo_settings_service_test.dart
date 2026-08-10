import "dart:async";

import "package:sesori_bridge/src/api/bridge_settings_api.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("YoloSettingsService", () {
    late _MemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late YoloSettingsService service;

    setUp(() async {
      api = _MemoryBridgeSettingsApi();
      repository = BridgeSettingsRepository(api: api);
      await repository.loadSettings();
      service = YoloSettingsService(bridgeSettingsRepository: repository);
    });

    tearDown(() => repository.dispose());

    test("returns, persists, and publishes the live setting", () async {
      expect(service.currentSettings, const YoloSettingsResponse(enabled: false));
      final changes = <YoloSettingsResponse>[];
      final subscription = service.changes.listen(changes.add);

      expect(await service.update(enabled: true), const YoloSettingsResponse(enabled: true));

      expect(service.currentSettings.enabled, isTrue);
      expect(jsonDecodeMap(api.config!)["yolo"], isTrue);
      expect(changes, [const YoloSettingsResponse(enabled: true)]);
      await subscription.cancel();
    });

    test("an unchanged value does not rewrite or publish", () async {
      final changes = <YoloSettingsResponse>[];
      final subscription = service.changes.listen(changes.add);

      expect(await service.update(enabled: false), const YoloSettingsResponse(enabled: false));

      expect(api.writeCount, 0);
      expect(changes, isEmpty);
      await subscription.cancel();
    });
  });
}

class _MemoryBridgeSettingsApi implements BridgeSettingsApi {
  String? config = '{"yolo":false,"pullRequestRefreshIntervalSeconds":30}';
  int writeCount = 0;

  @override
  String get configFilePath => "/tmp/config.json";

  @override
  Future<String?> readConfig() async => config;

  @override
  Future<void> writeConfig(String jsonContent) async {
    config = jsonContent;
    writeCount++;
  }
}
