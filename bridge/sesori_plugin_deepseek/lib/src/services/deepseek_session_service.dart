import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/deepseek_session_repository.dart";

class const DeepSeekSessionService({
  required final DeepSeekSessionRepository repository,
  required final AcpChildSessionTracker childSessions,
}) {
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

  String rootSessionIdFor({
    required String sessionId,
    required List<PluginSession> persistedSessions,
  }) {
    final liveRootSessionId = childSessions.rootOf(sessionId: sessionId);
    if (liveRootSessionId != sessionId) return liveRootSessionId;
    final parentBySessionId = <String, String>{};
    for (final session in persistedSessions) {
      final parentId = session.parentID;
      if (parentId != null) parentBySessionId[session.id] = parentId;
    }
    final visited = <String>{sessionId};
    var currentSessionId = sessionId;
    while (true) {
      final parentId = parentBySessionId[currentSessionId];
      if (parentId == null) return currentSessionId;
      if (!visited.add(parentId)) return sessionId;
      currentSessionId = parentId;
    }
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
