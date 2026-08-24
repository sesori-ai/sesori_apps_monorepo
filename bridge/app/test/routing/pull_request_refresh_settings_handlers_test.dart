import "dart:convert";

import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/routing/get_pull_request_refresh_settings_handler.dart";
import "package:sesori_bridge/src/routing/patch_bridge_settings_handler.dart";
import "package:sesori_bridge/src/routing/request_handler.dart";
import "package:sesori_bridge/src/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";
import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  group("pull request refresh settings handlers", () {
    late InMemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late PullRequestRefreshSettingsService service;
    late YoloSettingsService yoloService;

    setUp(() async {
      api = InMemoryBridgeSettingsApi(config: '{"pullRequestRefreshIntervalSeconds":30}');
      repository = BridgeSettingsRepository(api: api);
      await repository.loadSettings();
      service = PullRequestRefreshSettingsService(bridgeSettingsRepository: repository);
      yoloService = YoloSettingsService(
        bridgeSettingsRepository: repository,
        permissionAutoApprovalService: _FakePermissionAutoApprovalService(),
      );
    });

    tearDown(() => repository.dispose());

    test("GET returns the committed interval", () async {
      final response = await GetPullRequestRefreshSettingsHandler(settingsService: service).routeForTest(
        makeRequest("GET", "/settings/pull-request-refresh"),
      );

      expect(response.status, 200);
      expect(
        PullRequestRefreshSettingsResponse.fromJson(jsonDecodeMap(response.body!)),
        const PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      );
    });

    test("PATCH declares only the generic settings route", () {
      final handler = PatchBridgeSettingsHandler(
        pullRequestRefreshSettingsService: service,
        yoloSettingsService: yoloService,
      );

      expect(handler.method, HttpMethod.patch);
      expect(handler.path, "/settings");
      expect(
        handler.matches(
          requestMethod: HttpMethod.patch,
          target: Uri.parse("/settings/pull-request-refresh"),
        ),
        isFalse,
      );
    });

    test("PATCH persists and returns the committed interval", () async {
      final response =
          await PatchBridgeSettingsHandler(
            pullRequestRefreshSettingsService: service,
            yoloSettingsService: yoloService,
          ).routeForTest(
            makeRequest(
              "PATCH",
              "/settings",
              body: jsonEncode(
                const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 45).toJson(),
              ),
            ),
          );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body!)),
        const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 45),
      );
      expect((jsonDecode(api.config!) as Map)["pullRequestRefreshIntervalSeconds"], 45);
    });

    test("PATCH returns a typed 400 for an out-of-range interval", () async {
      final response =
          await PatchBridgeSettingsHandler(
            pullRequestRefreshSettingsService: service,
            yoloSettingsService: yoloService,
          ).routeForTest(
            makeRequest(
              "PATCH",
              "/settings",
              body: jsonEncode(
                const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 14).toJson(),
              ),
            ),
          );

      expect(response.status, 400);
      expect(response.headers["content-type"], "application/json");
      expect(
        BridgeSettingUpdateRejection.fromJson(jsonDecodeMap(response.body!)),
        const BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
          minimumIntervalSeconds: 15,
          maximumIntervalSeconds: 3600,
        ),
      );
      expect(api.writeCount, 0);
    });

    test("PATCH rejects non-integer JSON before the service", () async {
      final response =
          await PatchBridgeSettingsHandler(
            pullRequestRefreshSettingsService: service,
            yoloSettingsService: yoloService,
          ).routeForTest(
            makeRequest(
              "PATCH",
              "/settings",
              body: jsonEncode({
                "type": "pullRequestRefreshInterval",
                "intervalSeconds": 30.5,
              }),
            ),
          );

      expect(response.status, 400);
      expect(api.writeCount, 0);
    });

    test("PATCH rejects an unknown setting variant before the service", () async {
      final response =
          await PatchBridgeSettingsHandler(
            pullRequestRefreshSettingsService: service,
            yoloSettingsService: yoloService,
          ).routeForTest(
            makeRequest(
              "PATCH",
              "/settings",
              body: jsonEncode({"type": "futureSetting", "enabled": true}),
            ),
          );

      expect(response.status, 400);
      expect(response.headers["content-type"], "application/json");
      expect(
        BridgeSettingUpdateRejection.fromJson(jsonDecodeMap(response.body!)),
        const BridgeSettingUpdateRejection.unknown(),
      );
      expect(api.writeCount, 0);
    });
  });
}

class _FakePermissionAutoApprovalService() implements PermissionAutoApprovalService {
  @override
  Future<void> approvePending() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
