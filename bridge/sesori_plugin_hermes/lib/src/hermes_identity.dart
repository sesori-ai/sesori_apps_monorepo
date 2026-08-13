/// Identity constants for the Hermes Agent harness plugin.
///
/// The plugin id is the plain string `hermes` (precedent: the pi and omp
/// plugins are not members of the legacy `Harness` enum either). The client
/// brands the id through `PregoBrandLogo` in module_prego (Hermes staff mark
/// + "Hermes Agent" display name).
abstract final class HermesPluginIdentity() {
  static const String pluginId = "hermes";
  static const String displayName = "Hermes Agent";
  static const String clientName = "sesori-bridge";
  static const String clientVersion = "0.0.0";
}
