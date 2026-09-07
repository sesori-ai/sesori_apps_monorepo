import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/deepseek_acp_api.dart";
import "../api/models/deepseek_protocol_dto.dart";

class const DeepSeekSessionRepository({required final DeepSeekAcpApi api}) {
  Future<AcpScopedStopResult> stopScopedTree({
    required AcpStdioClient client,
    required AcpScopedStopTarget target,
  }) async {
    final request = switch (target) {
      AcpScopedStopSessionTarget(:final sessionId) => DeepSeekSessionStopSessionRequestDto(sessionId: sessionId),
      AcpScopedStopChildTarget(:final parentSessionId, :final childSessionId) => DeepSeekSessionStopChildRequestDto(
        sessionId: parentSessionId,
        childSessionId: childSessionId,
      ),
    };
    try {
      final response = await api.stopSession(client: client, request: request);
      return AcpScopedStopResult(workKept: response.workKept);
    } on Object catch (error, stackTrace) {
      final targetContext = switch (target) {
        AcpScopedStopSessionTarget(:final sessionId) => "session $sessionId",
        AcpScopedStopChildTarget(:final parentSessionId, :final childSessionId) =>
          "child $childSessionId under parent $parentSessionId",
      };
      Error.throwWithStackTrace(
        PluginOperationException(
          DeepSeekAcpApi.sessionStopMethod,
          message: "DeepSeek scoped stop failed for $targetContext",
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Future<AcpChildCancelResult> cancelChild({
    required AcpStdioClient client,
    required String sessionId,
    required String childSessionId,
  }) async => switch (await api.interruptSubagent(
    client: client,
    sessionId: sessionId,
    childSessionId: childSessionId,
  )) {
    DeepSeekSubagentInterruptResult.interrupted => AcpChildCancelResult.interrupted,
    DeepSeekSubagentInterruptResult.notCancellable => AcpChildCancelResult.notCancellable,
    DeepSeekSubagentInterruptResult.unknownChild => AcpChildCancelResult.unknownChild,
    DeepSeekSubagentInterruptResult.unknown => throw const FormatException("Unknown DeepSeek interrupt outcome"),
  };

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
