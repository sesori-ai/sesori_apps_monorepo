/// Declares who owns a plugin's projects — the plugin's backend natively, or
/// the bridge by deriving them from the plugin's sessions.
///
/// This is a parse-time capability read off `BridgePluginDescriptor`. It drives
/// the single fork in the bridge's project repository between the
/// backend-native path (call the plugin's `getProjects()` and trust it) and the
/// bridge-derived path (group the plugin's sessions by directory and persist
/// opened folders / rename overrides bridge-side). It is purely a bridge wiring
/// decision and never crosses into the relay protocol, `sesori_shared`, or the
/// client.
enum ProjectTrackingMode {
  /// The backend owns projects natively (e.g. OpenCode's `/project` API). The
  /// bridge calls `getProjects()` and treats the result as authoritative.
  nativeBackend,

  /// The backend has no project concept; the bridge derives projects from the
  /// plugin's sessions (grouped by directory) and owns opened-folder and
  /// rename-override persistence. Such a plugin only reports its sessions via
  /// `listAllSessions()` (Codex and every ACP backend).
  bridgeDerived,
}
