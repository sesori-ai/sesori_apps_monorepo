import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGroupId;

/// What one minted Sesori MCP token stands for.
///
/// [groups] are the tool groups that were on when the launch was minted, so a
/// session's tool list stays the same for the whole launch.
sealed class const SesoriMcpGrant({required final String pluginId, required final Set<SesoriToolGroupId> groups});

/// Minted for a launch whose backend session id is not known yet. It may
/// connect, but its tool calls are attributed to nobody.
final class const SesoriMcpGrantUnbound({required super.pluginId, required super.groups}) extends SesoriMcpGrant;

/// Bound to the backend session the launch serves.
final class const SesoriMcpGrantBound({
  required super.pluginId,
  required super.groups,
  required final String backendSessionId,
}) extends SesoriMcpGrant;
