import "package:freezed_annotation/freezed_annotation.dart";

import "control_provision_progress.dart";

part "control_message.freezed.dart";
part "control_message.g.dart";

/// The GUI-hosted loopback control-channel wire protocol (ADR A5): a single
/// sealed union carrying every message exchanged between the desktop GUI and
/// the supervised bridge helper, in both directions. The relay-bound
/// `RelayMessage` is the precedent for this shape.
///
/// PR 1.2 defines only the wire types; senders/handlers land in later Phase-1
/// PRs (1.3-1.13) and Phase-2 GUI PRs. New optional fields added by those PRs
/// use `@Default` so older/newer peers stay wire-compatible.
@Freezed(unionKey: "type", unionValueCase: FreezedUnionCase.snake, fromJson: true, toJson: true)
sealed class ControlMessage with _$ControlMessage {
  /// helper → GUI: request a fresh access token. [id] correlates the
  /// [ControlTokenResponse]; [forceRefresh] asks the GUI to mint a new one.
  @FreezedUnionValue("token_request")
  const factory ControlMessage.tokenRequest({
    required String id,
    @Default(false) bool forceRefresh,
  }) = ControlTokenRequest;

  /// GUI → helper: reply to a [ControlTokenRequest]. A null [accessToken] means
  /// the GUI could not supply one (mid-login / signed out); the helper treats
  /// it as a typed failure.
  @FreezedUnionValue("token_response")
  const factory ControlMessage.tokenResponse({
    required String id,
    required String? accessToken,
  }) = ControlTokenResponse;

  /// GUI → helper (push): a refreshed access token to adopt without a request.
  @FreezedUnionValue("token_update")
  const factory ControlMessage.tokenUpdate({
    required String accessToken,
  }) = ControlTokenUpdate;

  /// helper → GUI (push): current relay/plugin health + active-session summary.
  @FreezedUnionValue("status")
  const factory ControlMessage.status({
    @JsonKey(unknownEnumValue: ControlRelayConnectionState.unknown)
    required ControlRelayConnectionState relay,
    @JsonKey(unknownEnumValue: ControlPluginHealthState.unknown)
    required ControlPluginHealthState plugin,
    @Default(0) int activeSessionCount,
  }) = ControlStatus;

  /// helper → GUI: surface a user prompt (e.g. replace-bridge, login-needed).
  /// [id] correlates the [ControlPromptResponse].
  @FreezedUnionValue("prompt_request")
  const factory ControlMessage.promptRequest({
    required String id,
    @JsonKey(unknownEnumValue: ControlPromptKind.unknown) required ControlPromptKind kind,
    required String? message,
  }) = ControlPromptRequest;

  /// GUI → helper: the user's answer to a [ControlPromptRequest].
  @FreezedUnionValue("prompt_response")
  const factory ControlMessage.promptResponse({
    required String id,
    required bool accepted,
  }) = ControlPromptResponse;

  /// helper → GUI: heads-up that this exit is an intentional restart (exit 86),
  /// so the GUI respawns instead of treating it as a crash (PR 1.7).
  @FreezedUnionValue("restart")
  const factory ControlMessage.restart() = ControlRestart;

  /// GUI → helper: unregister this bridge with the current token, then exit 0
  /// (logout ordering, PR 1.11).
  @FreezedUnionValue("unregister_and_exit")
  const factory ControlMessage.unregisterAndExit() = ControlUnregisterAndExit;

  /// helper → GUI: registration succeeded; carries [bridgeId] so the GUI can
  /// persist a readable copy for the offline-unregister fallback (ADR A13).
  @FreezedUnionValue("registered")
  const factory ControlMessage.registered({
    required String bridgeId,
  }) = ControlRegistered;

  /// helper → GUI: a runtime-provisioning progress event (first-run download /
  /// install), teed from the bridge's provisioning stream (PR 1.13).
  @FreezedUnionValue("provision_progress")
  const factory ControlMessage.provisionProgress({
    required ControlProvisionProgress progress,
  }) = ControlProvisionProgressMessage;

  factory ControlMessage.fromJson(Map<String, dynamic> json) => _$ControlMessageFromJson(json);
}

/// Relay connection state reported in a [ControlStatus]. [unknown] is the
/// forward-compat fallback for values a newer helper might add.
enum ControlRelayConnectionState {
  @JsonValue("connected")
  connected,
  @JsonValue("connecting")
  connecting,
  @JsonValue("disconnected")
  disconnected,
  @JsonValue("unknown")
  unknown,
}

/// Plugin (backend) health reported in a [ControlStatus]. [unknown] is the
/// forward-compat fallback.
enum ControlPluginHealthState {
  @JsonValue("healthy")
  healthy,
  @JsonValue("degraded")
  degraded,
  @JsonValue("unavailable")
  unavailable,
  @JsonValue("unknown")
  unknown,
}

/// The kind of prompt a [ControlPromptRequest] surfaces. [unknown] is the
/// forward-compat fallback.
enum ControlPromptKind {
  @JsonValue("replace_bridge")
  replaceBridge,
  @JsonValue("login_needed")
  loginNeeded,
  @JsonValue("unknown")
  unknown,
}
