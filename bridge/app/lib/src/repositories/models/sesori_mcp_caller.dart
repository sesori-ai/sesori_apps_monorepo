/// The Sesori session behind one Sesori MCP request.
///
/// Only the id: the session's project and scheduled task are read from its row
/// at each call, so nothing about it goes stale.
final class const SesoriMcpCaller({required final String sessionId});
