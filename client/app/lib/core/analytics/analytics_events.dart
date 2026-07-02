/// Analytics event names and parameter keys, kept in one place so the set of
/// tracked user actions is auditable at a glance and wire values stay stable
/// even if code identifiers are renamed.
///
/// Names follow the GA4 conventions: snake_case, letters/digits/underscores,
/// at most 40 characters.
class AnalyticsEvents {
  const AnalyticsEvents._();

  /// The onboarding "Need help?" pill was tapped, opening the support menu.
  static const String needHelpMenuOpened = "onboarding_need_help_opened";

  /// A support channel inside the "Need help?" menu was tapped. Carries
  /// [channelParam] with one of the channel values below.
  static const String supportLinkOpened = "onboarding_support_link_opened";

  /// Parameter key of [supportLinkOpened]: which support channel was tapped.
  static const String channelParam = "channel";

  static const String channelEmail = "email";
  static const String channelDiscord = "discord";
  static const String channelX = "x";
}
