/// Whether an activated plugin may be suspended after confirmed idle time.
enum PluginResidencyPolicy() {
  /// Apply the bridge's configured idle timeout.
  transient,

  /// Keep the plugin adapter active until explicit or bridge shutdown.
  resident,
}
