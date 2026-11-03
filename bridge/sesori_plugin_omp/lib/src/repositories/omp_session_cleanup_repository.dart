import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart" show AcpStopReason;

import "../api/omp_acp_api.dart";

class const OmpCleanupSession({required final String sessionId, required final String? cwd});

class OmpCleanupPage({required List<OmpCleanupSession> sessions, required final String? nextCursor}) {
  final List<OmpCleanupSession> sessions = List.unmodifiable(sessions);
}

/// Layer-2 ACP operations used by OMP persisted-session cleanup.
class OmpSessionCleanupRepository({required final OmpAcpApi _api}) {
  Directory? _scratchDirectory;

  Future<void> open({required String cwd, required Duration timeout}) async {
    final result = await _api.open(cwd: cwd, timeout: timeout);
    final capabilities = result.agentCapabilities;
    if (!capabilities.listSessions || !capabilities.resumeSession || !capabilities.closeSession) {
      throw StateError("OMP persisted cleanup requires list, resume, and close support");
    }
  }

  Future<OmpCleanupPage> listPage({
    required String? cursor,
    required Duration timeout,
  }) async {
    final result = await _api.listSessionsPage(cwd: null, cursor: cursor, timeout: timeout);
    return OmpCleanupPage(
      sessions: [
        for (final session in result.sessions) OmpCleanupSession(sessionId: session.sessionId, cwd: session.cwd),
      ],
      nextCursor: result.nextCursor,
    );
  }

  Future<void> resume({
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) async {
    final result = await _api.resumeSession(sessionId: sessionId, cwd: cwd, timeout: timeout);
    // OMP 18.15.0 answers `session/resume` with only `configOptions` and
    // `modes`, fails with "ACP session not found" for an unknown id, and runs
    // the following `/session delete` on the session registered under the
    // requested id. A missing echo therefore means the requested session; only
    // an echoed different id stops cleanup.
    final echoedSessionId = result.raw["sessionId"];
    if (echoedSessionId != null && echoedSessionId != sessionId) {
      throw StateError("OMP resumed a different session");
    }
  }

  Future<void> delete({required String sessionId, required Duration timeout}) async {
    final result = await _api.prompt(sessionId: sessionId, text: "/session delete", timeout: timeout);
    if (result.stopReason != AcpStopReason.endTurn) {
      throw StateError("OMP did not complete persisted session deletion");
    }
  }

  Future<void> close({required String sessionId, required Duration timeout}) =>
      _api.closeSession(sessionId: sessionId, timeout: timeout);

  Future<String> createScratchDirectory() async {
    final directory = await _api.createScratchDirectory(prefix: "omp-cleanup-");
    _scratchDirectory = directory;
    return directory.path;
  }

  Future<void> deleteScratchDirectory() async {
    final directory = _scratchDirectory;
    _scratchDirectory = null;
    if (directory != null) await _api.deleteScratchDirectory(directory: directory);
  }

  Future<void> settle() => _api.settle();
  Future<void> dispose() => _api.dispose();
}
