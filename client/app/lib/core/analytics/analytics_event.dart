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
  const factory AnalyticsEvent.needHelpMenuOpened() = NeedHelpMenuOpened;

  /// A support channel inside the "Need help?" menu was tapped.
  @FreezedUnionValue("onboarding_support_link_opened")
  const factory AnalyticsEvent.supportLinkOpened({required SupportChannel channel}) =
      SupportLinkOpened;

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
