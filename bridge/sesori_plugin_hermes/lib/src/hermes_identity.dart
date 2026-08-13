/// Identity constants for the Hermes Agent harness plugin.
///
/// The plugin id is the plain string `hermes` (precedent: the pi and omp
/// plugins are not members of the legacy `Harness` enum either). Client-side
/// branding for the id is handled by `PregoBrandLogo` in module_prego (the
/// Hermes staff mark + "Hermes Agent" display name), keyed by this id.
abstract final class HermesIdentity() {
  static const String pluginId = "hermes";
  static const String displayName = "Hermes Agent";
  static const String providerId = "hermes";
  static const String clientName = "sesori-bridge";
  static const String clientVersion = "0.0.0";
}
