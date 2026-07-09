import "package:freezed_annotation/freezed_annotation.dart";

part "analytics_event.freezed.dart";
part "analytics_event.g.dart";

/// JSON key freezed writes the union discriminator under. The discriminator
/// value doubles as the analytics event name: reporters pop this key out of
/// [AnalyticsEvent.toJson] and send the remaining fields as the event's
/// parameter map.
const String analyticsEventNameKey = "event_name";

/// A tracked user action. One union case per analytics event: the case's
/// [FreezedUnionValue] is the GA4 event name (snake_case,
/// letters/digits/underscores, at most 40 characters) and its fields serialize
/// into the event's parameters, so the full set of tracked actions — names,
/// parameters, and allowed values — is auditable in this one file.
///
/// Wire names are pinned by the annotations and stay stable even if code
/// identifiers are renamed.
@Freezed(unionKey: analyticsEventNameKey)
sealed class AnalyticsEvent with _$AnalyticsEvent {
  /// The onboarding "Need help?" pill was tapped, opening the support menu.
  @FreezedUnionValue("onboarding_need_help_opened")
  const factory AnalyticsEvent.needHelpMenuOpened({required OnboardingSurface surface}) =
      NeedHelpMenuOpened;

  /// A support channel inside the "Need help?" menu was tapped.
  @FreezedUnionValue("onboarding_support_link_opened")
  const factory AnalyticsEvent.supportLinkOpened({
    required SupportChannel channel,
    required OnboardingSurface surface,
  }) = SupportLinkOpened;

  /// The "Why is this needed?" explainer sheet was opened.
  @FreezedUnionValue("onboarding_why_bridge_opened")
  const factory AnalyticsEvent.whyBridgeOpened({required OnboardingSurface surface}) =
      WhyBridgeOpened;

  /// An install command was copied to the clipboard.
  @FreezedUnionValue("bridge_install_command_copied")
  const factory AnalyticsEvent.installCommandCopied({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandCopied;

  /// An install command was handed to the native share sheet.
  @FreezedUnionValue("bridge_install_command_shared")
  const factory AnalyticsEvent.installCommandShared({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandShared;

  /// The start-the-bridge command was copied to the clipboard.
  @FreezedUnionValue("bridge_run_command_copied")
  const factory AnalyticsEvent.runCommandCopied({required OnboardingSurface surface}) =
      RunCommandCopied;

  /// The start-the-bridge command was handed to the native share sheet.
  @FreezedUnionValue("bridge_run_command_shared")
  const factory AnalyticsEvent.runCommandShared({required OnboardingSurface surface}) =
      RunCommandShared;

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) => _$AnalyticsEventFromJson(json);
}

/// Which support channel an [AnalyticsEvent.supportLinkOpened] tap targeted;
/// each [JsonValue] is the wire value of the event's `channel` parameter.
enum SupportChannel {
  @JsonValue("email")
  email,
  @JsonValue("discord")
  discord,
  @JsonValue("x")
  x,
}

/// Which Projects-screen surface an event fired from, so the same action is
/// attributable to the funnel step the user was on; each [JsonValue] is the
/// wire value of the event's `surface` parameter.
///
/// The bridge-offline recovery view rides along because it reuses the same
/// command boxes as the two onboarding bodies.
enum OnboardingSurface {
  /// The connect-your-computer setup onboarding (no bridge ever registered).
  @JsonValue("connect_setup")
  connectSetup,

  /// The connected-but-no-projects checklist.
  @JsonValue("connected_empty")
  connectedEmpty,

  /// The "bridge disconnected" recovery view (a bridge exists but is off).
  @JsonValue("bridge_offline")
  bridgeOffline,
}

/// Which install method a copied/shared install command belongs to; each
/// [JsonValue] is the wire value of the event's `method` parameter.
enum BridgeInstallMethod {
  /// The macOS/Linux `curl … | bash` one-liner.
  @JsonValue("curl")
  curl,

  /// The Windows `irm … | iex` PowerShell one-liner (labelled "native" in the
  /// install box).
  @JsonValue("powershell")
  powershell,

  @JsonValue("npm")
  npm,

  @JsonValue("bun")
  bun,
}

/// Which OS group the install box was switched to when the command was
/// copied/shared; each [JsonValue] is the wire value of the event's `os`
/// parameter. Cross-platform methods (npm/bun) still carry the selected group,
/// recording the platform the user declared via the segmented control.
enum BridgeInstallOs {
  @JsonValue("unix")
  unix,

  @JsonValue("windows")
  windows,
}
