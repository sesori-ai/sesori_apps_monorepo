import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/deepseek_session_repository.dart";

class const DeepSeekSessionService({
  required final DeepSeekSessionRepository repository,
  required final AcpChildSessionTracker childSessions,
  required final SemanticVersion minimumAdapterVersion,
}) {
  void validateInitializeResult(AcpInitializeResult initializeResult) {
    final adapterVersion = repository.parseInitializeAdapterVersion(initializeResult);
    if (adapterVersion == null) {
      throw const FormatException("DeepSeek adapter reported an invalid adapter version");
    }
    if (adapterVersion.compareTo(minimumAdapterVersion) < 0) {
      throw FormatException("DeepSeek requires adapter ${minimumAdapterVersion.toString()} or newer");
    }
  }

  Future<AcpScopedStopResult> stopScopedTree({
    required AcpStdioClient client,
    required AcpScopedStopTarget target,
  }) => repository.stopScopedTree(client: client, target: target);

  Future<AcpChildCancelResult> cancelChild({
    required AcpStdioClient client,
    required String sessionId,
    required String childSessionId,
  }) => repository.cancelChild(client: client, sessionId: sessionId, childSessionId: childSessionId);

  List<PluginSession> getChildSessions({
    required String sessionId,
    required String directory,
    required List<PluginSession> persistedSessions,
  }) {
    final childrenById = <String, PluginSession>{
      for (final session in persistedSessions)
        if (session.parentID == sessionId) session.id: session,
    };
    for (final session in childSessions.childSessions(sessionId: sessionId, directory: directory)) {
      childrenById.putIfAbsent(session.id, () => session);
    }
    return childrenById.values.toList(growable: false);
  }

  Future<PluginSession> rename({
    required AcpStdioClient client,
    required String sessionId,
    required String title,
    required String directory,
  }) async {
    final normalizedTitle = await repository.rename(
      client: client,
      sessionId: sessionId,
      title: title,
    );
    return PluginSession(
      id: sessionId,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: normalizedTitle,
      time: null,
    );
  }
}
