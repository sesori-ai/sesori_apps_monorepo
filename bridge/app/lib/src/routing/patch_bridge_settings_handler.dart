import "package:sesori_shared/sesori_shared.dart";

import "../services/pull_request_refresh_settings_service.dart";
import "../services/yolo_settings_service.dart";
import "request_handler.dart";

class PatchBridgeSettingsHandler({
  required final PullRequestRefreshSettingsService _pullRequestRefreshSettingsService,
  required final YoloSettingsService _yoloSettingsService,
}) extends BodyRequestHandler<BridgeSettingUpdate, BridgeSettingUpdate> {
  this
    : super(
        HttpMethod.patch,
        "/settings",
        fromJson: BridgeSettingUpdate.fromJson,
      );

  @override
  Future<BridgeSettingUpdate> handle(
    RelayRequest request, {
    required BridgeSettingUpdate body,
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
          throw buildJsonErrorResponse(
            request: request,
            status: 400,
            body: BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
              minimumIntervalSeconds: error.minimumIntervalSeconds,
              maximumIntervalSeconds: error.maximumIntervalSeconds,
            ).toJson(),
          );
        }
      case YoloSettingUpdate(:final enabled):
        final committed = await _yoloSettingsService.update(enabled: enabled);
        return BridgeSettingUpdate.yolo(enabled: committed.enabled);
      case UnknownBridgeSettingUpdate():
        throw buildJsonErrorResponse(
          request: request,
          status: 400,
          body: const BridgeSettingUpdateRejection.unknown().toJson(),
        );
    }
  }
}
