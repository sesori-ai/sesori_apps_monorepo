import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolCaller, SesoriToolGroupId;

import "../repositories/models/sesori_mcp_grant.dart";
import "../repositories/sesori_mcp_grant_repository.dart";
import "../repositories/session_repository.dart";

/// Tells who is behind a Sesori MCP token.
class SesoriMcpAccessService({
  required final SesoriMcpGrantRepository _grants,
  required final SessionRepository _sessions,
}) {
  /// The tool groups [token] was minted with, or null when this bridge did
  /// not mint it. Any other token is refused outright.
  Set<SesoriToolGroupId>? grantedGroups({required String token}) => _grants.lookup(token: token)?.groups;

  /// The Sesori session [token] was bound to, or null while the launch is not
  /// bound yet or its backend session has no Sesori session.
  Future<SesoriToolCaller?> resolve({required String token}) async {
    if (_grants.lookup(token: token) case SesoriMcpGrantBound(:final pluginId, :final backendSessionId)) {
      final stored = await _sessions.getStoredSessionByBackendId(
        pluginId: pluginId,
        backendSessionId: backendSessionId,
      );
      return stored == null ? null : SesoriToolCaller(sessionId: stored.id);
    }
    return null;
  }
}
