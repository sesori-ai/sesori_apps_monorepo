import "models/plugin_session.dart";

/// The capability a plugin exposes when its descriptor declares
/// `ProjectTrackingMode.bridgeDerived`: the bridge enumerates all of the
/// plugin's sessions and groups them by directory to derive the project list.
///
/// Kept off `BridgePluginApi` deliberately. Because plugins `implements` that
/// contract (rather than extending it), any member there — even one with a
/// default body — must be implemented by every plugin; putting an
/// enumerate-all-sessions method on the core contract would force backend-native
/// plugins to implement something they never use. As an optional, descriptor-
/// declared capability interface it is implemented only by derived plugins
/// (Codex and every ACP backend). The bridge reaches it only after the
/// descriptor opts in, then downcasts.
///
/// Pairs with `BridgeDerivedProjectsMixin`, which supplies the project-
/// management members the bridge never routes for a derived plugin.
abstract interface class BridgeDerivedProjectSource {
  /// Every session this plugin knows about, across all projects. The bridge
  /// groups the result by [PluginSession.directory] to build the project list,
  /// so each returned session must carry its real working directory.
  Future<List<PluginSession>> listAllSessions();

  /// The plugin's launch directory. The bridge seeds this as an opened folder so
  /// it always surfaces as a project — even with no sessions yet — matching the
  /// "there is always somewhere to start a session" behaviour derive-style
  /// backends had before the bridge owned their project list.
  String get launchDirectory;
}
