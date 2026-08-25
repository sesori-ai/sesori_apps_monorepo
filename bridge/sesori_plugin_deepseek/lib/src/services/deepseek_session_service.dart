import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/deepseek_session_repository.dart";

class const DeepSeekSessionService({required final DeepSeekSessionRepository repository}) {
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
