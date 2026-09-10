import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/grok_acp_api.dart";
import "../api/models/grok_protocol_dto.dart";

/// Maps Grok's exact child-cancel transport outcome into ACP stop policy.
class const GrokSessionControlRepository({required final GrokAcpApi api}) {
  Future<AcpChildCancelResult> cancelChild({
    required AcpStdioClient client,
    required String parentSessionId,
    required String childSessionId,
  }) async {
    try {
      final response = await api.cancelSubagent(client: client, subagentId: childSessionId);
      return switch (response.outcome.kind) {
        GrokSubagentCancelOutcomeKind.cancelled ||
        GrokSubagentCancelOutcomeKind.alreadyFinished => AcpChildCancelResult.interrupted,
        GrokSubagentCancelOutcomeKind.unknown => throw const FormatException("Unknown Grok cancellation outcome"),
      };
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          GrokAcpApi.subagentCancelMethod,
          message: "Grok child cancellation failed for child $childSessionId under parent $parentSessionId",
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
