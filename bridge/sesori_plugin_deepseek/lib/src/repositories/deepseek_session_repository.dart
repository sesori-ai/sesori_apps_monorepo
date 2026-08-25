import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/deepseek_acp_api.dart";

class const DeepSeekSessionRepository({required final DeepSeekAcpApi api}) {
  Future<String> rename({
    required AcpStdioClient client,
    required String sessionId,
    required String title,
  }) async {
    try {
      final response = await api.rename(
        client: client,
        sessionId: sessionId,
        title: title,
        timeout: AcpAgentApi.defaultRequestTimeout,
      );
      return response.title;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          DeepSeekAcpApi.renameMethod,
          message: "DeepSeek session rename failed",
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
