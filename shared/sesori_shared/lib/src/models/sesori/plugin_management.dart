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

enum PluginStopMode { safe, force }

enum PluginLifecycleConflictReason { inFlight, busy, workStateUnknown, transitioning, notEnabled }

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
    required int revision,
    required String? defaultPluginId,
    required int defaultIdleTimeoutMins,
    required List<PluginManagementMetadata> plugins,
  }) = _PluginManagementResponse;

  factory PluginManagementResponse.fromJson(Map<String, dynamic> json) => _$PluginManagementResponseFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class PluginLifecycleCommandRequest with _$PluginLifecycleCommandRequest {
  @FreezedUnionValue("enable")
  const factory PluginLifecycleCommandRequest.enable() = PluginLifecycleEnableRequest;

  @FreezedUnionValue("disable")
  const factory PluginLifecycleCommandRequest.disable({
    required PluginStopMode mode,
  }) = PluginLifecycleDisableRequest;

  @FreezedUnionValue("restart")
  const factory PluginLifecycleCommandRequest.restart({
    required PluginStopMode mode,
  }) = PluginLifecycleRestartRequest;

  @FreezedUnionValue("refresh")
  const factory PluginLifecycleCommandRequest.refresh() = PluginLifecycleRefreshRequest;

  factory PluginLifecycleCommandRequest.fromJson(Map<String, dynamic> json) =>
      _$PluginLifecycleCommandRequestFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class PluginIdleTimeoutUpdateRequest with _$PluginIdleTimeoutUpdateRequest {
  @FreezedUnionValue("applyAll")
  const factory PluginIdleTimeoutUpdateRequest.applyAll({
    @JsonKey(fromJson: _strictIntFromJson) required int idleTimeoutMins,
  }) = PluginIdleTimeoutApplyAllRequest;

  @FreezedUnionValue("setOverride")
  const factory PluginIdleTimeoutUpdateRequest.setOverride({
    required String pluginId,
    @JsonKey(fromJson: _strictIntFromJson) required int idleTimeoutMins,
  }) = PluginIdleTimeoutSetOverrideRequest;

  @FreezedUnionValue("clearOverride")
  const factory PluginIdleTimeoutUpdateRequest.clearOverride({
    required String pluginId,
  }) = PluginIdleTimeoutClearOverrideRequest;

  factory PluginIdleTimeoutUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$PluginIdleTimeoutUpdateRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginLifecycleConflict with _$PluginLifecycleConflict {
  const factory PluginLifecycleConflict({
    required String pluginId,
    required List<PluginLifecycleConflictReason> reasons,
    required PluginManagementMetadata current,
  }) = _PluginLifecycleConflict;

  factory PluginLifecycleConflict.fromJson(Map<String, dynamic> json) => _$PluginLifecycleConflictFromJson(json);
}

int _strictIntFromJson(num value) {
  if (value is int) return value;
  throw const FormatException("Expected an integer");
}
