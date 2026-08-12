import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/pull_request_refresh_settings_service.dart";
import "../services/yolo_settings_service.dart";

class PatchBridgeSettingsHandler({
    required PullRequestRefreshSettingsService pullRequestRefreshSettingsService,
    required YoloSettingsService yoloSettingsService,
  }) extends BodyRequestHandler<BridgeSettingUpdate, BridgeSettingUpdate> {
  this : _pullRequestRefreshSettingsService = pullRequestRefreshSettingsService,
       _yoloSettingsService = yoloSettingsService,
       super(
         HttpMethod.patch,
         "/settings",
         fromJson: BridgeSettingUpdate.fromJson,
       );

  final PullRequestRefreshSettingsService _pullRequestRefreshSettingsService;
  final YoloSettingsService _yoloSettingsService;

  @override
  Future<BridgeSettingUpdate> handle(
    RelayRequest request, {
    required BridgeSettingUpdate body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    switch (body) {
      case PullRequestRefreshIntervalSettingUpdate(:final intervalSeconds):
        try {
          final committed = await _pullRequestRefreshSettingsService.update(
            intervalSeconds: intervalSeconds,
          );
          return BridgeSettingUpdate.pullRequestRefreshInterval(
            intervalSeconds: committed.intervalSeconds,
          );
        } on PullRequestRefreshIntervalOutOfRangeException catch (error) {
          throw RelayResponse(
            id: request.id,
            status: 400,
            headers: const {"content-type": "application/json"},
            body: jsonEncode(
              BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
                minimumIntervalSeconds: error.minimumIntervalSeconds,
                maximumIntervalSeconds: error.maximumIntervalSeconds,
              ).toJson(),
            ),
          );
        }
      case YoloSettingUpdate(:final enabled):
        final committed = await _yoloSettingsService.update(enabled: enabled);
        return BridgeSettingUpdate.yolo(enabled: committed.enabled);
      case UnknownBridgeSettingUpdate():
        throw RelayResponse(
          id: request.id,
          status: 400,
          headers: const {"content-type": "application/json"},
          body: jsonEncode(const BridgeSettingUpdateRejection.unknown().toJson()),
        );
    }
  }
}
