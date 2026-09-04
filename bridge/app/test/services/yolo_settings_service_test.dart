import "dart:async";

import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  group("YoloSettingsService", () {
    late InMemoryBridgeSettingsApi api;
    late _FakePermissionAutoApprovalService permissionAutoApprovalService;
    late BridgeSettingsRepository repository;
    late YoloSettingsService service;

    setUp(() async {
      api = InMemoryBridgeSettingsApi(
        config: '{"yolo":false,"pullRequestRefreshIntervalSeconds":30,"warmUpPluginsOnSessionOpen":true}',
      );
      repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();
      permissionAutoApprovalService = _FakePermissionAutoApprovalService();
      service = YoloSettingsService(
        bridgeSettingsRepository: repository,
        permissionAutoApprovalService: permissionAutoApprovalService,
      );
    });

    tearDown(() => repository.dispose());

    test("enabling persists and approves pending permissions", () async {
      expect(service.currentSettings, const YoloSettingsResponse(enabled: false));

      expect(await service.update(enabled: true), const YoloSettingsResponse(enabled: true));

      expect(service.currentSettings.enabled, isTrue);
      expect(jsonDecodeMap(api.config!)["yolo"], isTrue);
      expect(permissionAutoApprovalService.approvePendingCalls, 1);
    });

    test("disabling persists without approving pending permissions", () async {
      await service.update(enabled: true);
      permissionAutoApprovalService.approvePendingCalls = 0;

      expect(await service.update(enabled: false), const YoloSettingsResponse(enabled: false));

      expect(jsonDecodeMap(api.config!)["yolo"], isFalse);
      expect(permissionAutoApprovalService.approvePendingCalls, 0);
    });

    test("an unchanged value does not rewrite or approve pending permissions", () async {
      await service.update(enabled: true);
      permissionAutoApprovalService.approvePendingCalls = 0;

      expect(await service.update(enabled: true), const YoloSettingsResponse(enabled: true));

      expect(api.writeCount, 1);
      expect(permissionAutoApprovalService.approvePendingCalls, 0);
    });
  });
}

class _FakePermissionAutoApprovalService() implements PermissionAutoApprovalService {
  int approvePendingCalls = 0;

  @override
  Future<void> approvePending() async => approvePendingCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
