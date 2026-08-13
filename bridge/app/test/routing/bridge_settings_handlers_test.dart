import "dart:convert";

import "package:sesori_bridge/src/api/bridge_settings_api.dart";
import "package:sesori_bridge/src/bridge/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/routing/get_bridge_settings_handler.dart";
import "package:sesori_bridge/src/routing/patch_bridge_settings_handler.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";

void main() {
  group("bridge settings handlers", () {
    late _MemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late YoloSettingsService service;
    late PatchBridgeSettingsHandler patchHandler;

    setUp(() async {
      api = _MemoryBridgeSettingsApi();
      repository = BridgeSettingsRepository(api: api);
      await repository.loadSettings();
      service = YoloSettingsService(
        bridgeSettingsRepository: repository,
        permissionAutoApprovalService: _FakePermissionAutoApprovalService(),
      );
      patchHandler = PatchBridgeSettingsHandler(
        pullRequestRefreshSettingsService: PullRequestRefreshSettingsService(
          bridgeSettingsRepository: repository,
        ),
        yoloSettingsService: service,
      );
    });

    tearDown(() => repository.dispose());

    test("GET returns both settings from one committed snapshot", () async {
      final response = await GetBridgeSettingsHandler(settingsRepository: repository).handleInternal(
        makeRequest("GET", "/settings"),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.status, 200);
      expect(
        BridgeSettingsResponse.fromJson(jsonDecodeMap(response.body!)),
        const BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: false),
        ),
      );
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

class _FakePermissionAutoApprovalService() implements PermissionAutoApprovalService {
  @override
  Future<void> approvePending() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryBridgeSettingsApi() implements BridgeSettingsApi {
  String? config = '{"yolo":false,"pullRequestRefreshIntervalSeconds":30}';

  @override
  String get configFilePath => "/tmp/config.json";

  @override
  Future<String?> readConfig() async => config;

  @override
  Future<void> writeConfig(String jsonContent) async => config = jsonContent;
}
