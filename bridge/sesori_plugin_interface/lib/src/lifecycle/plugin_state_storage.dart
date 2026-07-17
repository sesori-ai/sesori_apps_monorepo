/// On-disk storage layouts a plugin can request from the bridge host.
enum PluginStateStorage {
  /// Private state under `<installRoot>/plugins/<pluginId>`.
  isolated,

  /// The shared `<cacheDirectory>/runtime` path used by plugins whose shipped
  /// state cannot move without breaking runtime and ownership continuity.
  legacySharedRuntime,
}
