import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show SesoriMcpAccess, SesoriMcpLaunch, sesoriMcpServerName;

import "../../repositories/sesori_mcp_grant_repository.dart";

/// One plugin's [SesoriMcpAccess]: mints launches for that plugin only.
class BridgeSesoriMcpAccessImpl({
  required final String _pluginId,
  required final Uri _url,
  required final SesoriMcpGrantRepository _grants,

  /// The `agent-tools` bridge setting, read at each launch.
  required final bool Function() _agentToolsEnabled,
}) implements SesoriMcpAccess {
  @override
  SesoriMcpLaunch? mint() {
    if (!_agentToolsEnabled()) return null;
    return SesoriMcpLaunch(
      serverName: sesoriMcpServerName,
      url: _url.toString(),
      token: _grants.mint(pluginId: _pluginId),
    );
  }

  @override
  void bind({required SesoriMcpLaunch launch, required String backendSessionId}) {
    _grants.bind(token: launch.token, backendSessionId: backendSessionId);
  }
}
