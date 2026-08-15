/// Identity constants for the Hermes Agent harness plugin.
///
/// The plugin id is the plain string `hermes` (precedent: the pi and omp
/// plugins are not members of the legacy `Harness` enum either). Client-side
/// brand mapping for the id can follow without a wire-format change.
abstract final class HermesPluginIdentity() {
  static const String id = "hermes";
  static const String displayName = "Hermes Agent";
}
