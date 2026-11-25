import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show SesoriMcpAccess, SesoriMcpLaunch, SesoriSkillBundle, sesoriMcpServerName;

/// A [SesoriMcpAccess] that mints numbered tokens (`token-1`, `token-2`, ...)
/// while [enabled] and records every bind as `(token, backendSessionId)`.
/// While [enabled] it also offers [skills].
class RecordingSesoriMcpAccess({
  /// False behaves like the bridge's `agent-tools` setting turned off.
  required var bool enabled,
}) implements SesoriMcpAccess {
  static const String url = "http://127.0.0.1:4100/mcp";
  static const SesoriSkillBundle skills = SesoriSkillBundle(
    pluginRoot: "/skills/claude-plugin",
    skillsRoot: "/skills/skills",
  );

  int minted = 0;
  final List<(String, String)> binds = [];

  @override
  SesoriMcpLaunch? mint() {
    if (!enabled) return null;
    minted++;
    return SesoriMcpLaunch(serverName: sesoriMcpServerName, url: url, token: "token-$minted");
  }

  @override
  void bind({required SesoriMcpLaunch launch, required String backendSessionId}) {
    binds.add((launch.token, backendSessionId));
  }

  @override
  SesoriSkillBundle? get skillBundle => enabled ? skills : null;
}
