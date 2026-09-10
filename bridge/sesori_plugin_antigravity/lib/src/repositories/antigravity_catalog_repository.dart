import "package:acp_plugin/acp_plugin.dart";

import "../models/antigravity_model_catalog.dart";
import "mappers/antigravity_protocol_mapper.dart";

/// Connection-scoped standard-ACP operations used for Antigravity catalog discovery.
class AntigravityCatalogRepository({
  required final AcpAgentApi _api,
  required final AntigravityProtocolMapper _protocolMapper,
}) {
  Future<List<AcpSessionInfo>> listSessions({required String directory}) async => (await _api.listSessionsPage(
    cwd: directory,
    cursor: null,
    timeout: AcpAgentApi.defaultRequestTimeout,
  )).sessions;

  Future<AntigravityCatalogSession> createSession({required String directory}) async => _mapSession(
    result: await _api.newSession(cwd: directory, timeout: AcpAgentApi.defaultRequestTimeout),
  );

  Future<AntigravityCatalogSession> resumeSession({required String sessionId, required String directory}) async =>
      _mapSession(
        result: await _api.resumeSession(
          sessionId: sessionId,
          cwd: directory,
          timeout: AcpAgentApi.defaultRequestTimeout,
        ),
      );

  AntigravityCatalogSession _mapSession({required AcpNewSessionResult result}) {
    final catalog = _protocolMapper.mapModelCatalog(result: result);
    if (catalog == null) throw const FormatException("Antigravity discovery returned no model selector");
    return (sessionId: result.sessionId, catalog: catalog);
  }
}
