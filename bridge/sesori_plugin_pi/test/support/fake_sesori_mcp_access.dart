import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Records Sesori MCP mints and binds; [enabled] false models `agent-tools off`.
final class FakeSesoriMcpAccess({required final bool enabled}) implements SesoriMcpAccess {
  final List<SesoriMcpLaunch> minted = [];
  final List<({SesoriMcpLaunch launch, String backendSessionId})> bound = [];

  @override
  SesoriMcpLaunch? mint() {
    if (!enabled) return null;
    final launch = SesoriMcpLaunch(
      serverName: sesoriMcpServerName,
      url: "http://127.0.0.1:4711/mcp",
      token: "token-${minted.length + 1}",
    );
    minted.add(launch);
    return launch;
  }

  @override
  void bind({required SesoriMcpLaunch launch, required String backendSessionId}) =>
      bound.add((launch: launch, backendSessionId: backendSessionId));

  @override
  SesoriSkillBundle? get skillBundle => null;
}
