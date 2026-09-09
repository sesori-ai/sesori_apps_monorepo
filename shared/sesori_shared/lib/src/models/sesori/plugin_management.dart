import "package:freezed_annotation/freezed_annotation.dart";

import "../../converters/strict_int_json_converter.dart";
import "plugin_setup_response.dart";

part "plugin_management.freezed.dart";
part "plugin_management.g.dart";

enum PluginRuntimeState() {
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

enum PluginManagementWorkState() { idle, busy, unknown }

enum PluginManagementCapability() { lifecycle, setupRefresh, idleTimeout, install, authentication, unknown }

enum PluginAuthenticationState() { idle, inProgress, unknown }

enum PluginStopMode() { safe, force }

/// Phase of a phone-triggered managed runtime install, streamed via the
/// `plugin.install.progress` SSE event. `completed` and `failed` are terminal.
enum PluginInstallPhase() { downloading, verifying, extracting, finalizing, completed, failed, unknown }

enum PluginLifecycleConflictReason() { inFlight, busy, workStateUnknown, transitioning, notEnabled, unsupported, unknown }

enum PluginAuthenticationConflictReason() {
  inFlight,
  setupNotRequired,
  unsupported,
  noActive,
  wrongKind,
  alreadySubmitted,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginManagementMetadata with _$PluginManagementMetadata {
  const factory({
    required PluginSetupMetadata setup,
    @JsonKey(unknownEnumValue: PluginRuntimeState.unknown) required PluginRuntimeState runtimeState,
    @JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) required PluginManagementWorkState workState,
    // COMPATIBILITY 2026-08-12 (v1.8.0): Older bridge payloads omit
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

  factory fromJson(Map<String, dynamic> json) => _$PluginManagementMetadataFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
  copyWith: false,
  equal: false,
  toStringOverride: false,
)
sealed class PluginAuthenticationChallengeResponse with _$PluginAuthenticationChallengeResponse {
  @FreezedUnionValue("deviceCode")
  const factory deviceCode({
    required String verificationUrl,
    required String userCode,
  }) = PluginAuthenticationDeviceCodeChallengeResponse;

  @FreezedUnionValue("browser")
  const factory browser({
    required String authorizationUrl,
    required String expectedCallbackUrl,
  }) = PluginAuthenticationBrowserChallengeResponse;

  const factory unknown() = PluginAuthenticationUnknownChallengeResponse;

  factory fromJson(Map<String, dynamic> json) {
    if (json["type"] is! String) {
      throw const FormatException("Plugin authentication challenge type is required");
    }
    return _$PluginAuthenticationChallengeResponseFromJson(json);
  }
}

@Freezed(fromJson: true, toJson: true, copyWith: false, equal: false, toStringOverride: false)
sealed class PluginAuthenticationRedirectRequest with _$PluginAuthenticationRedirectRequest {
  static const maxRedirectUrlLength = 4096;

  const factory({required String redirectUrl}) = _PluginAuthenticationRedirectRequest;

  factory fromJson(Map<String, dynamic> json) => _$PluginAuthenticationRedirectRequestFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
  copyWith: false,
)
sealed class PluginAuthenticationProgress with _$PluginAuthenticationProgress {
  @FreezedUnionValue("completed")
  const factory completed() = PluginAuthenticationCompletedProgress;

  @FreezedUnionValue("failed")
  const factory failed({
    required String message,
  }) = PluginAuthenticationFailedProgress;

  @FreezedUnionValue("cancelled")
  const factory cancelled() = PluginAuthenticationCancelledProgress;

  const factory unknown() = PluginAuthenticationUnknownProgress;

  factory fromJson(Map<String, dynamic> json) =>
      _$PluginAuthenticationProgressFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginManagementResponse with _$PluginManagementResponse {
  const factory({
    required String snapshotToken,
    required String bridgeId,
    required String? defaultPluginId,
    required int defaultIdleTimeoutMins,
    required List<PluginManagementMetadata> plugins,
  }) = _PluginManagementResponse;

  factory fromJson(Map<String, dynamic> json) => _$PluginManagementResponseFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class PluginLifecycleCommandRequest with _$PluginLifecycleCommandRequest {
  @FreezedUnionValue("enable")
  const factory enable() = PluginLifecycleEnableRequest;

  @FreezedUnionValue("disable")
  const factory disable({
    required PluginStopMode mode,
  }) = PluginLifecycleDisableRequest;

  @FreezedUnionValue("restart")
  const factory restart({
    required PluginStopMode mode,
  }) = PluginLifecycleRestartRequest;

  @FreezedUnionValue("refresh")
  const factory refresh() = PluginLifecycleRefreshRequest;

  /// Installs the plugin's pinned managed runtime, then enables, re-inspects,
  /// and starts the plugin when ready. Accepted immediately; progress streams
  /// via `plugin.install.progress` SSE and the terminal outcome invalidates
  /// the management snapshot. Only valid for plugins advertising
  /// [PluginManagementCapability.install].
  @FreezedUnionValue("install")
  const factory install() = PluginLifecycleInstallRequest;

  factory fromJson(Map<String, dynamic> json) =>
      _$PluginLifecycleCommandRequestFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class PluginIdleTimeoutUpdateRequest with _$PluginIdleTimeoutUpdateRequest {
  @FreezedUnionValue("applyAll")
  const factory applyAll({
    @strictIntJsonConverter required int idleTimeoutMins,
  }) = PluginIdleTimeoutApplyAllRequest;

  @FreezedUnionValue("setOverride")
  const factory setOverride({
    required String pluginId,
    @strictIntJsonConverter required int idleTimeoutMins,
  }) = PluginIdleTimeoutSetOverrideRequest;

  @FreezedUnionValue("clearOverride")
  const factory clearOverride({
    required String pluginId,
  }) = PluginIdleTimeoutClearOverrideRequest;

  factory fromJson(Map<String, dynamic> json) =>
      _$PluginIdleTimeoutUpdateRequestFromJson(json);
}


@Freezed(fromJson: true, toJson: true)
sealed class PluginLifecycleConflict with _$PluginLifecycleConflict {
  const factory({
    required String pluginId,
    @JsonKey(unknownEnumValue: PluginLifecycleConflictReason.unknown)
    required List<PluginLifecycleConflictReason> reasons,
    required PluginManagementMetadata current,
  }) = _PluginLifecycleConflict;

  factory fromJson(Map<String, dynamic> json) => _$PluginLifecycleConflictFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginAuthenticationConflict with _$PluginAuthenticationConflict {
  const factory({
    required String pluginId,
    @JsonKey(unknownEnumValue: PluginAuthenticationConflictReason.unknown)
    required List<PluginAuthenticationConflictReason> reasons,
    required PluginManagementMetadata current,
  }) = _PluginAuthenticationConflict;

  factory fromJson(Map<String, dynamic> json) =>
      _$PluginAuthenticationConflictFromJson(json);
}
