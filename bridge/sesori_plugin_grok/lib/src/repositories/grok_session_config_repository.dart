import "package:acp_plugin/acp_plugin.dart" show AcpStdioClient;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;

import "../api/grok_acp_api.dart";

/// Validates and delegates exact Grok session-local model writes.
class GrokSessionConfigRepository({required final GrokAcpApi _api}) {
  Future<void> setSelection({
    required AcpStdioClient liveClient,
    required String sessionId,
    required String modelId,
    required String? reasoningEffort,
    required Duration timeout,
  }) async {
    if (sessionId.isEmpty || modelId.isEmpty || (reasoningEffort?.isEmpty ?? false)) {
      throw const PluginOperationException(
        GrokAcpApi.sessionSetModelMethod,
        message: "Grok selection values must not be empty",
      );
    }
    try {
      await _api.setModel(
        liveClient: liveClient,
        sessionId: sessionId,
        modelId: modelId,
        reasoningEffort: reasoningEffort,
        timeout: timeout,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          GrokAcpApi.sessionSetModelMethod,
          message: "Grok rejected the requested session options",
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
