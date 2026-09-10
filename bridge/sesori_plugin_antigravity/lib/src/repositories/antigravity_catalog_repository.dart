import "package:acp_plugin/acp_plugin.dart";

/// Connection-scoped standard-ACP operations used for Antigravity catalog discovery.
class AntigravityCatalogRepository({required AcpAgentApi api}) {
  final AcpAgentApi _api = api;

  Future<List<AcpSessionInfo>> listSessions({required String directory}) async => (await _api.listSessionsPage(
    cwd: directory,
    cursor: null,
    timeout: AcpAgentApi.defaultRequestTimeout,
  )).sessions;

  Future<AcpNewSessionResult> createSession({required String directory}) => _api.newSession(
    cwd: directory,
    timeout: AcpAgentApi.defaultRequestTimeout,
  );

  Future<AcpNewSessionResult> resumeSession({required String sessionId, required String directory}) =>
      _api.resumeSession(
        sessionId: sessionId,
        cwd: directory,
        timeout: AcpAgentApi.defaultRequestTimeout,
      );
}
