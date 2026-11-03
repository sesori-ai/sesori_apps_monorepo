import "package:freezed_annotation/freezed_annotation.dart";

part "control_message.freezed.dart";
part "control_message.g.dart";

/// The GUI-hosted loopback control-channel wire protocol: a single sealed union
/// carrying every message exchanged between the desktop GUI and the supervised
/// bridge helper, in both directions. (`RelayMessage` is the analogous union for
/// the relay protocol.)
///
/// Pure wire types only — senders and handlers live in the bridge and the
/// desktop GUI. The GUI only talks to the helper it spawned from its own bundle
/// (authenticated by a per-spawn secret; release builds refuse a helper whose
/// version/build identity differs), so both ends change in lockstep.
@Freezed(unionKey: "type", unionValueCase: FreezedUnionCase.snake, fromJson: true, toJson: true)
sealed class ControlMessage with _$ControlMessage {
  /// helper → GUI: request a fresh access token. [id] correlates the
  /// [ControlTokenResponse]; [forceRefresh] asks the GUI to mint a new one.
  @FreezedUnionValue("token_request")
  const factory tokenRequest({
    required String id,
    @Default(false) bool forceRefresh,
  }) = ControlTokenRequest;

  /// GUI → helper: reply to a [ControlTokenRequest]. A null [accessToken] means
  /// the GUI could not supply one (mid-login / signed out); the helper treats
  /// it as a typed failure.
  @FreezedUnionValue("token_response")
  const factory tokenResponse({
    required String id,
    required String? accessToken,
  }) = ControlTokenResponse;

  /// GUI → helper: the signed-in session temporarily cannot supply a token.
  @FreezedUnionValue("token_retry_later")
  const factory tokenRetryLater({required String id}) = ControlTokenRetryLater;

  /// helper → GUI (push): startup, relay/plugin health and active sessions.
  /// [unhealthyPlugins] lists the eligible plugins that are degraded or
  /// failed, in the bridge's plugin order; empty when all are healthy.
  @FreezedUnionValue("status")
  const factory status({
    required ControlStartupState startup,
    @JsonKey(unknownEnumValue: ControlRelayConnectionState.unknown) required ControlRelayConnectionState relay,
    required List<ControlUnhealthyPlugin> unhealthyPlugins,
    @Default(0) int activeSessionCount,
  }) = ControlStatus;

  /// helper → GUI: surface a user prompt (e.g. replace-bridge, login-needed).
  /// [id] correlates the [ControlPromptResponse].
  @FreezedUnionValue("prompt_request")
  const factory promptRequest({
    required String id,
    @JsonKey(unknownEnumValue: ControlPromptKind.unknown) required ControlPromptKind kind,
    required String? message,
  }) = ControlPromptRequest;

  /// GUI → helper: the user's answer to a [ControlPromptRequest].
  @FreezedUnionValue("prompt_response")
  const factory promptResponse({
    required String id,
    required bool accepted,
  }) = ControlPromptResponse;

  /// GUI → helper: gracefully stop the supervised bridge and exit 0 without
  /// unregistering it. This is the normal desktop On → Off lifecycle command.
  @FreezedUnionValue("shutdown")
  const factory shutdown() = ControlShutdown;

  /// GUI → helper: unregister this bridge with the current token, then exit 0
  /// (logout ordering).
  @FreezedUnionValue("unregister_and_exit")
  const factory unregisterAndExit() = ControlUnregisterAndExit;

  /// helper → GUI: registration succeeded; carries [bridgeId] so the GUI can
  /// persist a readable copy for an offline-unregister fallback (logout when the
  /// helper is unreachable).
  @FreezedUnionValue("registered")
  const factory registered({
    required String bridgeId,
  }) = ControlRegistered;

  factory fromJson(Map<String, dynamic> json) => _$ControlMessageFromJson(json);
}

/// Relay connection state reported in a [ControlStatus]. [unknown] is the
/// forward-compat fallback for values a newer helper might add.
enum ControlRelayConnectionState() {
  @JsonValue("connected")
  connected,
  @JsonValue("connecting")
  connecting,
  @JsonValue("disconnected")
  disconnected,

  /// Another bridge for this account took the single relay slot; this bridge
  /// is displaced and reconnecting only on a long backoff. The GUI surfaces a
  /// "take over" affordance (a plain helper respawn).
  @JsonValue("taken_over")
  takenOver,
  @JsonValue("unknown")
  unknown,
}

/// A degraded or failed plugin (backend) reported in a [ControlStatus].
@Freezed(fromJson: true, toJson: true)
sealed class ControlUnhealthyPlugin with _$ControlUnhealthyPlugin {
  const factory({
    required String displayName,
    required ControlUnhealthyPluginState state,

    /// What the user can do about it, when the bridge has a hint.
    required String? actionHint,
  }) = _ControlUnhealthyPlugin;

  factory fromJson(Map<String, dynamic> json) => _$ControlUnhealthyPluginFromJson(json);
}

/// How a [ControlUnhealthyPlugin] is impaired. The GUI only talks to the
/// helper it bundles, so this closed set needs no unknown fallback.
enum ControlUnhealthyPluginState() {
  /// Running but impaired; it may recover or need the user to act.
  degraded,

  /// Stopped after a terminal failure; the bridge and other plugins keep
  /// running without it.
  failed,
}

/// The kind of prompt a [ControlPromptRequest] surfaces. [unknown] is the
/// forward-compat fallback.
enum ControlPromptKind() {
  @JsonValue("replace_bridge")
  replaceBridge,
  @JsonValue("login_needed")
  loginNeeded,
  @JsonValue("unknown")
  unknown,
}

/// Startup readiness is separate from the helper process and relay socket.
enum ControlStartupState() {
  unknown,
  starting,
  @JsonValue("waiting_for_server")
  waitingForServer,
  @JsonValue("waiting_for_authentication")
  waitingForAuthentication,
  ready,
}
