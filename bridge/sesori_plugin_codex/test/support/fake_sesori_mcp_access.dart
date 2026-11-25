import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Mints fresh launches (or none, as when the user turned agent tools off) and
/// records each binding.
class FakeSesoriMcpAccess({required final bool _enabled}) implements SesoriMcpAccess {
  final List<SesoriMcpLaunch> minted = [];
  final List<({SesoriMcpLaunch launch, String backendSessionId})> bound = [];

  @override
  SesoriSkillBundle? skillBundle;

  @override
  SesoriMcpLaunch? mint() {
    if (!_enabled) return null;
    final launch = SesoriMcpLaunch(
      serverName: sesoriMcpServerName,
      url: "http://127.0.0.1:4100/mcp",
      token: "token-${minted.length + 1}",
    );
    minted.add(launch);
    return launch;
  }

  @override
  void bind({required SesoriMcpLaunch launch, required String backendSessionId}) =>
      bound.add((launch: launch, backendSessionId: backendSessionId));
}
