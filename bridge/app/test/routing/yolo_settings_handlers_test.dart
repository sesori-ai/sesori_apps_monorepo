import "dart:convert";

import "package:sesori_bridge/src/api/bridge_settings_api.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/routing/get_yolo_settings_handler.dart";
import "package:sesori_bridge/src/routing/patch_bridge_settings_handler.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";

void main() {
  group("YOLO settings handlers", () {
    late _MemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late YoloSettingsService service;
    late PatchBridgeSettingsHandler patchHandler;

    setUp(() async {
      api = _MemoryBridgeSettingsApi();
      repository = BridgeSettingsRepository(api: api);
      await repository.loadSettings();
      service = YoloSettingsService(bridgeSettingsRepository: repository);
      patchHandler = PatchBridgeSettingsHandler(
        pullRequestRefreshSettingsService: PullRequestRefreshSettingsService(
          bridgeSettingsRepository: repository,
        ),
        yoloSettingsService: service,
      );
    });

    tearDown(() => repository.dispose());

    test("GET returns the committed setting", () async {
      final response = await GetYoloSettingsHandler(settingsService: service).handleInternal(
        makeRequest("GET", "/settings/yolo"),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.status, 200);
      expect(YoloSettingsResponse.fromJson(jsonDecodeMap(response.body!)), const YoloSettingsResponse(enabled: false));
    });

    test("PATCH persists and returns the committed setting", () async {
      final response = await patchHandler.handleInternal(
        makeRequest("PATCH", "/settings", body: jsonEncode(const BridgeSettingUpdate.yolo(enabled: true).toJson())),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body!)),
        const BridgeSettingUpdate.yolo(enabled: true),
      );
      expect(jsonDecodeMap(api.config!)["yolo"], isTrue);
    });
  });
}

class _MemoryBridgeSettingsApi implements BridgeSettingsApi {
  String? config = '{"yolo":false,"pullRequestRefreshIntervalSeconds":30}';

  @override
  String get configFilePath => "/tmp/config.json";

  @override
  Future<String?> readConfig() async => config;

  @override
  Future<void> writeConfig(String jsonContent) async => config = jsonContent;
}
