import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolCaller;

import "../repositories/models/sesori_mcp_grant.dart";
import "../repositories/sesori_mcp_grant_repository.dart";
import "../repositories/session_repository.dart";

/// Tells who is behind a Sesori MCP token.
class SesoriMcpAccessService({
  required final SesoriMcpGrantRepository _grants,
  required final SessionRepository _sessions,
}) {
  /// Whether this bridge minted [token]. Any other token is refused outright.
  bool isMinted({required String token}) => _grants.lookup(token: token) != null;

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
