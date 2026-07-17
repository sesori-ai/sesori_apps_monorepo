import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../acp_protocol.dart";
import "../api/acp_api.dart";

class AcpSessionLocation {
  const AcpSessionLocation({required this.info, required this.directory});

  final AcpSessionInfo info;
  final String directory;
}

/// Coordinates typed ACP operations used by session and turn services.
class AcpSessionRepository {
  const AcpSessionRepository({required AcpApi api}) : _api = api;

  final AcpApi _api;

  Future<AcpInitializeResult> initialize({
    required AcpInitializeRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) => _api.initialize(request: request, timeout: timeout);

  Future<void> authenticate({
    required String methodId,
    Duration timeout = const Duration(seconds: 60),
  }) => _api.authenticate(methodId: methodId, timeout: timeout);

  Future<AcpNewSessionResult> newSession({required String directory}) => _api.newSession(directory: directory);

  Future<AcpSessionListResult> listSessions({
    required String? directory,
    required String? cursor,
    Duration timeout = const Duration(seconds: 60),
  }) => _api.listSessions(
    directory: directory,
    cursor: cursor,
    timeout: timeout,
  );

  Future<AcpSessionLocation?> findSession({
    required String sessionId,
    required Set<String> scanDirectories,
  }) async {
    for (final directory in <String?>[null, ...scanDirectories]) {
      try {
        String? cursor;
        for (var page = 0; page < 50; page++) {
          final result = await _api.listSessions(
            directory: directory,
            cursor: cursor,
          );
          for (final info in result.sessions) {
            if (info.sessionId != sessionId) continue;
            final reportedDirectory = info.cwd;
            if (reportedDirectory != null && reportedDirectory.trim().isNotEmpty) {
              return AcpSessionLocation(info: info, directory: reportedDirectory);
            }
            if (directory != null) {
              return AcpSessionLocation(info: info, directory: directory);
            }
          }
          final nextCursor = result.nextCursor;
          if (nextCursor == null || nextCursor.isEmpty) break;
          cursor = nextCursor;
        }
      } on AcpRpcException catch (error, stackTrace) {
        if (directory == null && (error.code == -32601 || error.code == -32602)) {
          continue;
        }
        Log.w(
          "[acp] session/list warm-up failed for ${directory ?? "(all)"}",
          error,
          stackTrace,
        );
      } on Object catch (error, stackTrace) {
        Log.w(
          "[acp] session/list warm-up failed for ${directory ?? "(all)"}",
          error,
          stackTrace,
        );
      }
    }
    return null;
  }

  Future<AcpPromptResult> prompt({
    required String sessionId,
    required List<AcpContentBlock> blocks,
  }) => _api.prompt(sessionId: sessionId, blocks: blocks);

  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String directory,
    Duration timeout = const Duration(minutes: 2),
  }) => _api.loadSession(
    sessionId: sessionId,
    directory: directory,
    timeout: timeout,
  );

  Future<AcpNewSessionResult> resumeSession({
    required String sessionId,
    required String directory,
  }) => _api.resumeSession(sessionId: sessionId, directory: directory);

  Future<AcpNewSessionResult> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) => _api.setConfigOption(
    sessionId: sessionId,
    configId: configId,
    value: value,
  );

  void cancelSession({required String sessionId}) => _api.cancelSession(sessionId: sessionId);
}
