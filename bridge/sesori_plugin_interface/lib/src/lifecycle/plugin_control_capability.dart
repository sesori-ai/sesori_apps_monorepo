/// Operations that Sesori may perform for a plugin under its current
/// configuration.
enum PluginControlCapability {
  /// Enable, disable, and restart the plugin runtime.
  lifecycle,

  /// Re-run setup inspection and reconnect when appropriate.
  setupRefresh,

  /// Configure idle timeout defaults or per-plugin overrides.
  idleTimeout,
}
