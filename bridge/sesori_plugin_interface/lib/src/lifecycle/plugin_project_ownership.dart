/// How a plugin represents projects before a live plugin API exists.
enum PluginProjectOwnership {
  /// The backend exposes stable project records through
  /// `NativeProjectsPluginApi`.
  native,

  /// The bridge derives projects from session directories through
  /// `BridgeDerivedProjectsPluginApi`.
  bridgeDerived,
}
