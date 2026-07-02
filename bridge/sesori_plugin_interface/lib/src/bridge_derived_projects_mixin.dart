import "models/plugin_project.dart";

/// Satisfies the three project-management members of `BridgePluginApi` that the
/// bridge never routes to a plugin declaring `ProjectTrackingMode.bridgeDerived`.
///
/// For such a plugin the bridge derives the project list from
/// `listAllSessions()` (grouping by `PluginSession.directory`) and persists
/// opened folders and rename overrides itself, so the plugin implements only
/// `listAllSessions()` plus its own `getSessions()` filter and mixes this in to
/// fulfil the rest of the contract.
///
/// `getProjects()` returns empty — it is never consulted for a derived plugin,
/// but an empty list keeps any incidental caller harmless. `getProject()` and
/// `renameProject()` throw, because reaching either means a caller bypassed the
/// bridge-derived path (a wiring bug worth surfacing loudly rather than
/// silently fabricating a project).
///
/// It is a plain mixin (no `on` constraint) because plugins `implements`
/// `BridgePluginApi` rather than extending it; the mixed-in members count
/// toward satisfying that interface.
mixin BridgeDerivedProjectsMixin {
  Future<List<PluginProject>> getProjects() async => const [];

  Future<PluginProject> getProject(String projectId) async => throw UnsupportedError(
    "Bridge-derived plugin: projects are derived by the bridge, not the plugin",
  );

  Future<PluginProject> renameProject({
    required String projectId,
    required String name,
  }) async => throw UnsupportedError(
    "Bridge-derived plugin: project renames are persisted by the bridge, not the plugin",
  );
}
