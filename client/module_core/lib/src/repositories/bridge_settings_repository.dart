import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/bridge_settings_api.dart";
import "models/bridge_settings_result.dart";

@lazySingleton
class BridgeSettingsRepository({required final BridgeSettingsApi _bridgeSettingsApi}) {
  Future<BridgeSettingsLoadResult> load() async {
    return switch (await _bridgeSettingsApi.getBridgeSettings()) {
      SuccessResponse(:final data) => BridgeSettingsLoadSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const BridgeSettingsLoadUnsupported(),
      ErrorResponse(:final error) => BridgeSettingsLoadFailure(error: error),
    };
  }

  Future<YoloSettingsMutationResult> updateYolo({required bool enabled}) async {
    return switch (await _bridgeSettingsApi.update(update: BridgeSettingUpdate.yolo(enabled: enabled))) {
      BridgeSettingUpdateApiCommitted(update: YoloSettingUpdate(:final enabled)) => YoloSettingsMutationCommitted(
        response: YoloSettingsResponse(enabled: enabled),
      ),
      BridgeSettingUpdateApiCommitted() => const YoloSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(error: NonSuccessCodeError(errorCode: 404)) =>
        const YoloSettingsMutationUnsupported(),
      BridgeSettingUpdateApiFailure(isCommitUncertain: true) => const YoloSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(:final error) => YoloSettingsMutationFailure(error: error),
    };
  }

  Future<PluginWarmupSettingsMutationResult> updatePluginWarmup({required bool enabled}) async {
    return switch (await _bridgeSettingsApi.update(
      update: BridgeSettingUpdate.warmUpPluginsOnSessionOpen(enabled: enabled),
    )) {
      BridgeSettingUpdateApiCommitted(
        update: WarmUpPluginsOnSessionOpenSettingUpdate(:final enabled),
      ) =>
        PluginWarmupSettingsMutationCommitted(enabled: enabled),
      BridgeSettingUpdateApiCommitted() => const PluginWarmupSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(error: NonSuccessCodeError(errorCode: 404)) =>
        const PluginWarmupSettingsMutationUnsupported(),
      BridgeSettingUpdateApiFailure(isCommitUncertain: true) => const PluginWarmupSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(:final error) => PluginWarmupSettingsMutationFailure(error: error),
    };
  }
}
