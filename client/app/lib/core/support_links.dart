/// External support/contact destinations opened from the onboarding
/// "Need help?" menu (Email / Discord / X).
///
/// Kept together so the destinations live in one place rather than being
/// scattered across widgets. Launched through the DI-registered `UrlLauncher`.
class SupportLinks {
  const SupportLinks._();
  static const String email = "mailto:hello@sesori.com";
  static const String discord = "https://discord.gg/5KBC8dV9uR";
  static const String x = "https://x.com/sesori_ai";
}
