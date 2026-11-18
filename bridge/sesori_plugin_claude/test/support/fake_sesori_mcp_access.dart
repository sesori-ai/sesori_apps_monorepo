import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Records every mint and bind. Mints nothing when [enabled] is false, like
/// the bridge with agent tools turned off.
final class FakeSesoriMcpAccess({final bool enabled = false}) implements SesoriMcpAccess {
  final List<SesoriMcpLaunch> minted = [];
  final List<({SesoriMcpLaunch launch, String backendSessionId})> bound = [];

  @override
  SesoriMcpLaunch? mint() {
    if (!enabled) return null;
    final launch = SesoriMcpLaunch(
      serverName: sesoriMcpServerName,
      url: "http://127.0.0.1:4242/mcp",
      token: "token-${minted.length + 1}",
    );
    minted.add(launch);
    return launch;
  }

  @override
  void bind({required SesoriMcpLaunch launch, required String backendSessionId}) {
    bound.add((launch: launch, backendSessionId: backendSessionId));
  }
}
