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

  /// Turns Sesori's tools on or off as a whole.
  Future<AgentToolsSettingsMutationResult> updateAgentTools({required bool enabled}) async {
    return switch (await _bridgeSettingsApi.update(update: BridgeSettingUpdate.agentTools(enabled: enabled))) {
      BridgeSettingUpdateApiCommitted(update: AgentToolsSettingUpdate(:final enabled)) =>
        AgentToolsSettingsMutationCommitted(enabled: enabled),
      final uncommitted => _agentToolsUncommitted(result: uncommitted),
    };
  }

  /// Turns the tool group [id] on or off. Its switch keeps its state while
  /// Sesori's tools are off as a whole.
  Future<AgentToolsSettingsMutationResult> updateToolGroup({required String id, required bool enabled}) async {
    return switch (await _bridgeSettingsApi.update(
      update: BridgeSettingUpdate.toolGroup(id: id, enabled: enabled),
    )) {
      BridgeSettingUpdateApiCommitted(update: ToolGroupSettingUpdate(id: final committedId, :final enabled))
          when committedId == id =>
        AgentToolsSettingsMutationCommitted(enabled: enabled),
      final uncommitted => _agentToolsUncommitted(result: uncommitted),
    };
  }

  /// The app offers these switches only to bridges that send the master
  /// switch, which all take both updates, so any refusal is a plain failure.
  AgentToolsSettingsMutationResult _agentToolsUncommitted({required BridgeSettingUpdateApiResult result}) {
    return switch (result) {
      BridgeSettingUpdateApiCommitted() => const AgentToolsSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(isCommitUncertain: true) => const AgentToolsSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(:final error) => AgentToolsSettingsMutationFailure(error: error),
    };
  }
}
