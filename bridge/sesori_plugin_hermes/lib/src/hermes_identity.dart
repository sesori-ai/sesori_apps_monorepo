/// Identity constants for the Hermes Agent harness plugin.
///
/// The plugin id is the plain string `hermes` (precedent: the pi and omp
/// plugins are not members of the legacy `Harness` enum either). Client-side
/// branding uses this stable id for its logo and display-name mapping.
abstract final class HermesPluginIdentity() {
  static const String id = "hermes";
  static const String displayName = "Hermes Agent";
}
