import "dart:convert";
import "dart:math";

import "models/sesori_mcp_grant.dart";

/// The in-memory map from each Sesori MCP token to the launch it was minted
/// for.
///
/// Tokens live only in this process: a restarted bridge knows none of them,
/// and it restarts its harnesses anyway. Each grant is a few bytes, so grants
/// are kept for the bridge's lifetime rather than tracked per launch.
class SesoriMcpGrantRepository({required final Random _random}) {
  static const int _tokenBytes = 32;

  final Map<String, SesoriMcpGrant> _grants = <String, SesoriMcpGrant>{};

  /// A fresh 256-bit token for one launch of [pluginId]'s harness.
  String mint({required String pluginId}) {
    final bytes = List<int>.generate(_tokenBytes, (_) => _random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll("=", "");
    _grants[token] = SesoriMcpGrantUnbound(pluginId: pluginId);
    return token;
  }

  /// Attributes [token] to [backendSessionId] of the plugin that minted it.
  void bind({required String token, required String backendSessionId}) {
    final grant = _grants[token];
    if (grant == null) throw StateError("A Sesori MCP launch was bound before it was minted.");
    _grants[token] = SesoriMcpGrantBound(pluginId: grant.pluginId, backendSessionId: backendSessionId);
  }

  SesoriMcpGrant? lookup({required String token}) => _grants[token];
}
