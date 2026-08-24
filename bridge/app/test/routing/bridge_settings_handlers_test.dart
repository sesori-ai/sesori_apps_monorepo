import "dart:convert";

import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/routing/get_bridge_settings_handler.dart";
import "package:sesori_bridge/src/routing/patch_bridge_settings_handler.dart";
import "package:sesori_bridge/src/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";
import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  group("bridge settings handlers", () {
    late InMemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late YoloSettingsService service;
    late PatchBridgeSettingsHandler patchHandler;

    setUp(() async {
      api = InMemoryBridgeSettingsApi(config: '{"yolo":false,"pullRequestRefreshIntervalSeconds":30}');
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
      final response = await GetBridgeSettingsHandler(settingsRepository: repository).routeForTest(
        makeRequest("GET", "/settings"),
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
      final response = await patchHandler.routeForTest(
        makeRequest("PATCH", "/settings", body: jsonEncode(const BridgeSettingUpdate.yolo(enabled: true).toJson())),
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
