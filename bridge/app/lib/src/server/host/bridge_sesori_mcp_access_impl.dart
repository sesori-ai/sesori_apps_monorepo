import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show SesoriMcpAccess, SesoriMcpLaunch, SesoriSkillBundle, sesoriMcpServerName;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGroupId;

import "../../repositories/sesori_mcp_grant_repository.dart";
import "../../repositories/sesori_skill_bundle_repository.dart";

/// One plugin's [SesoriMcpAccess]: mints launches for that plugin only.
class BridgeSesoriMcpAccessImpl({
  required final String _pluginId,
  required final Uri _url,
  required final SesoriMcpGrantRepository _grants,

  /// The tool groups on in bridge settings, read at each launch; none while
  /// the `agent-tools` master switch is off.
  required final Set<SesoriToolGroupId> Function() _enabledToolGroups,

  /// Kept in step with the enabled groups by `SesoriSkillBundleListener`.
  required final SesoriSkillBundleRepository _skillBundles,
}) implements SesoriMcpAccess {
  @override
  SesoriMcpLaunch? mint() {
    final groups = _enabledToolGroups();
    if (groups.isEmpty) return null;
    return SesoriMcpLaunch(
      serverName: sesoriMcpServerName,
      url: _url.toString(),
      token: _grants.mint(pluginId: _pluginId, groups: groups),
    );
  }

  @override
  void bind({required SesoriMcpLaunch launch, required String backendSessionId}) {
    _grants.bind(token: launch.token, backendSessionId: backendSessionId);
  }

  @override
  SesoriSkillBundle? get skillBundle => _skillBundles.current;
}
