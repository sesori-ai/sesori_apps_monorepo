/// Identity constants for the Hermes Agent harness plugin.
///
/// The plugin id is the plain string `hermes` (precedent: the pi and omp
/// plugins are not members of the legacy `Harness` enum either). Client-side
/// brand mapping for the id can follow later without a wire-format change.
abstract final class HermesIdentity() {
  static const String pluginId = "hermes";
  static const String displayName = "Hermes Agent";
  static const String providerId = "hermes";
  static const String clientName = "sesori-bridge";
  static const String clientVersion = "0.0.0";
}
