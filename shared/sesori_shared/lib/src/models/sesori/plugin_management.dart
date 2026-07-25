import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_setup_response.dart";

part "plugin_management.freezed.dart";
part "plugin_management.g.dart";

enum PluginRuntimeState {
  disabled,
  blocked,
  dormant,
  starting,
  active,
  degraded,
  stopping,
  failed,
  unknown;

  bool get isEnabled => switch (this) {
    PluginRuntimeState.blocked ||
    PluginRuntimeState.dormant ||
    PluginRuntimeState.starting ||
    PluginRuntimeState.active ||
    PluginRuntimeState.degraded ||
    PluginRuntimeState.stopping ||
    PluginRuntimeState.failed => true,
    PluginRuntimeState.disabled || PluginRuntimeState.unknown => false,
  };

  bool get isRoutable => switch (this) {
    PluginRuntimeState.dormant ||
    PluginRuntimeState.starting ||
    PluginRuntimeState.active ||
    PluginRuntimeState.degraded => true,
    PluginRuntimeState.disabled ||
    PluginRuntimeState.blocked ||
    PluginRuntimeState.stopping ||
    PluginRuntimeState.failed ||
    PluginRuntimeState.unknown => false,
  };
}

enum PluginManagementWorkState { idle, busy, unknown }

@Freezed(fromJson: true, toJson: true)
sealed class PluginManagementMetadata with _$PluginManagementMetadata {
  const factory PluginManagementMetadata({
    required PluginSetupMetadata setup,
    @JsonKey(unknownEnumValue: PluginRuntimeState.unknown) required PluginRuntimeState runtimeState,
    @JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) required PluginManagementWorkState workState,
    required int idleTimeoutMins,
    required bool hasIdleTimeoutOverride,
    required String? actionHint,
  }) = _PluginManagementMetadata;

  factory PluginManagementMetadata.fromJson(Map<String, dynamic> json) => _$PluginManagementMetadataFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginManagementResponse with _$PluginManagementResponse {
  const factory PluginManagementResponse({
    required String? defaultPluginId,
    required int defaultIdleTimeoutMins,
    required List<PluginManagementMetadata> plugins,
  }) = _PluginManagementResponse;

  factory PluginManagementResponse.fromJson(Map<String, dynamic> json) => _$PluginManagementResponseFromJson(json);
}
