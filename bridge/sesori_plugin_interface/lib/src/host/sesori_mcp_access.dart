/// The MCP server name every harness sees for Sesori's own tools.
///
/// Lowercase with an underscore, so harnesses that treat `-` and `_` alike or
/// restrict names to `[A-Za-z0-9_-]` all see the same name.
const String sesoriMcpServerName = "sesori_bridge";

/// What one harness launch needs to reach Sesori's MCP server.
///
/// [token] is a per-launch secret. Hand it to the harness only through its
/// process environment or a request header, never in argv or a URL, and never
/// log it. [toString] leaves it out.
final class const SesoriMcpLaunch({
  required final String serverName,

  /// The streamable-HTTP endpoint on the loopback interface.
  required final String url,

  /// Sent as `Authorization: Bearer <token>`.
  required final String token,
}) {
  @override
  String toString() => "SesoriMcpLaunch(serverName: $serverName, url: $url)";
}

/// Per-launch access to Sesori's MCP server, offered to plugins through
/// `PluginHost.sesoriMcp`.
///
/// A plugin always does two steps: [mint] before it launches the harness, and
/// [bind] once it knows the backend session id. Calls made with an unbound
/// launch are not attributed to any session, so the tools refuse them.
abstract class SesoriMcpAccess() {
  /// A fresh launch identity, or null when the user turned agent tools off.
  /// A null result means: inject nothing.
  SesoriMcpLaunch? mint();

  /// Attributes [launch] to [backendSessionId], the id the harness uses for
  /// the session this launch serves.
  void bind({required SesoriMcpLaunch launch, required String backendSessionId});
}
