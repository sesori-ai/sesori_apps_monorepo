/// What one minted Sesori MCP token stands for.
sealed class const SesoriMcpGrant({required final String pluginId});

/// Minted for a launch whose backend session id is not known yet. It may
/// connect, but its tool calls are attributed to nobody.
final class const SesoriMcpGrantUnbound({required super.pluginId}) extends SesoriMcpGrant;

/// Bound to the backend session the launch serves.
final class const SesoriMcpGrantBound({required super.pluginId, required final String backendSessionId})
    extends SesoriMcpGrant;
