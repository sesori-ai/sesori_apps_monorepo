import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../models/antigravity_model_catalog.dart";
import "mappers/antigravity_protocol_mapper.dart";

/// Connection-scoped standard-ACP operations used for Antigravity catalog discovery.
class AntigravityCatalogRepository({
  required final AcpAgentApi _api,
  required final AntigravityProtocolMapper _protocolMapper,
}) {
  /// Finds a stable existing session in the normalized reserved directory.
  Future<String?> findSessionId({required String directory}) async {
    final page = await _api.listSessionsPage(
      cwd: directory,
      cursor: null,
      timeout: AcpAgentApi.defaultRequestTimeout,
    );
    final matches = <String>[];
    for (final session in page.sessions) {
      final cwd = session.cwd;
      if (session.sessionId.isEmpty || cwd == null || cwd.trim().isEmpty) continue;
      if (normalizeProjectDirectory(directory: cwd) == directory) matches.add(session.sessionId);
    }
    matches.sort();
    return matches.firstOrNull;
  }

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
