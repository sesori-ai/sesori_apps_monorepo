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

enum PluginManagementCapability { lifecycle, setupRefresh, idleTimeout, install, authentication, unknown }

enum PluginAuthenticationState { idle, inProgress, unknown }

enum PluginStopMode { safe, force }

/// Phase of a phone-triggered managed runtime install, streamed via the
/// `plugin.install.progress` SSE event. `completed` and `failed` are terminal.
enum PluginInstallPhase { downloading, verifying, extracting, finalizing, completed, failed, unknown }

enum PluginLifecycleConflictReason { inFlight, busy, workStateUnknown, transitioning, notEnabled, unsupported, unknown }

enum PluginAuthenticationConflictReason { inFlight, setupNotRequired, unsupported, unknown }

enum PluginAuthenticationChallengeType { deviceCode }

@Freezed(fromJson: true, toJson: true)
sealed class PluginManagementMetadata with _$PluginManagementMetadata {
  const factory PluginManagementMetadata({
    required PluginSetupMetadata setup,
    @JsonKey(unknownEnumValue: PluginRuntimeState.unknown) required PluginRuntimeState runtimeState,
    @JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) required PluginManagementWorkState workState,
    // COMPATIBILITY 2026-08-12 (v1.9.0): Older bridge payloads omit
    // authenticationState, which honestly means no authentication operation
    // was active. Remove @Default after the minimum supported bridge sends it.
    @JsonKey(unknownEnumValue: PluginAuthenticationState.unknown)
    @Default(PluginAuthenticationState.idle)
    PluginAuthenticationState authenticationState,
    required int idleTimeoutMins,
    required bool hasIdleTimeoutOverride,
    @JsonKey(unknownEnumValue: PluginManagementCapability.unknown)
    required Set<PluginManagementCapability> managementCapabilities,
    required String? actionHint,
  }) = _PluginManagementMetadata;

  factory PluginManagementMetadata.fromJson(Map<String, dynamic> json) => _$PluginManagementMetadataFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class PluginAuthenticationChallengeResponse with _$PluginAuthenticationChallengeResponse {
  @FreezedUnionValue("deviceCode")
  const factory PluginAuthenticationChallengeResponse.deviceCode({
    @Default(PluginAuthenticationChallengeType.deviceCode) PluginAuthenticationChallengeType type,
    required String verificationUrl,
    required String userCode,
  }) = PluginAuthenticationDeviceCodeChallengeResponse;

  factory PluginAuthenticationChallengeResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    if (json["type"] != "deviceCode") {
      throw const FormatException("Unsupported plugin authentication challenge type");
    }
    return _$PluginAuthenticationChallengeResponseFromJson(json);
  }
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class PluginAuthenticationProgress with _$PluginAuthenticationProgress {
  @FreezedUnionValue("completed")
  const factory PluginAuthenticationProgress.completed() = PluginAuthenticationCompletedProgress;

  @FreezedUnionValue("failed")
  const factory PluginAuthenticationProgress.failed({
    required String message,
  }) = PluginAuthenticationFailedProgress;

  @FreezedUnionValue("cancelled")
  const factory PluginAuthenticationProgress.cancelled() = PluginAuthenticationCancelledProgress;

  factory PluginAuthenticationProgress.fromJson(Map<String, dynamic> json) =>
      _$PluginAuthenticationProgressFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginManagementResponse with _$PluginManagementResponse {
  const factory PluginManagementResponse({
    // COMPATIBILITY 2026-07-25 (v1.6.1): Stage 12-P02 and older bridge payloads
    // omit snapshotToken; null means that peer cannot identify snapshot changes.
    // Make non-null when those bridge versions are unsupported.
    required String? snapshotToken,
    // COMPATIBILITY 2026-07-27 (v1.7.0): Stage 12 bridge payloads omit the
    // bridge identity; null means the peer cannot scope management snapshots
    // to a bridge. Make non-null when those bridge versions are unsupported.
    required String? bridgeId,
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

  /// Installs the plugin's pinned managed runtime, then enables, re-inspects,
  /// and starts the plugin when ready. Accepted immediately; progress streams
  /// via `plugin.install.progress` SSE and the terminal outcome invalidates
  /// the management snapshot. Only valid for plugins advertising
  /// [PluginManagementCapability.install].
  @FreezedUnionValue("install")
  const factory PluginLifecycleCommandRequest.install() = PluginLifecycleInstallRequest;

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

int _strictIntFromJson(num value) {
  if (value is int) return value;
  throw const FormatException("Expected an integer");
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginLifecycleConflict with _$PluginLifecycleConflict {
  const factory PluginLifecycleConflict({
    required String pluginId,
    @JsonKey(unknownEnumValue: PluginLifecycleConflictReason.unknown)
    required List<PluginLifecycleConflictReason> reasons,
    required PluginManagementMetadata current,
  }) = _PluginLifecycleConflict;

  factory PluginLifecycleConflict.fromJson(Map<String, dynamic> json) => _$PluginLifecycleConflictFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginAuthenticationConflict with _$PluginAuthenticationConflict {
  const factory PluginAuthenticationConflict({
    required String pluginId,
    @JsonKey(unknownEnumValue: PluginAuthenticationConflictReason.unknown)
    required List<PluginAuthenticationConflictReason> reasons,
    required PluginManagementMetadata current,
  }) = _PluginAuthenticationConflict;

  factory PluginAuthenticationConflict.fromJson(Map<String, dynamic> json) =>
      _$PluginAuthenticationConflictFromJson(json);
}
