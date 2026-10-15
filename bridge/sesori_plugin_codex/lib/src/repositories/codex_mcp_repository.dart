import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_app_server_api.dart";
import "../api/models/codex_mcp_status_dto.dart";
import "mappers/codex_mcp_mapper.dart";

/// Retains unexpected decoder errors as typed native-read diagnostics.
final class const CodexMcpInventoryReadException({required final Object innerError}) implements Exception {
  @override
  String toString() => "Codex MCP inventory read failed: $innerError";
}

/// A complete read over the current transport, without starting agent work.
class CodexMcpRepository({required final CodexAppServerApi _appServerApi, required final CodexMcpMapper _mapper}) {
  Future<PluginMcpInventoryResult> read({required PluginMcpScope scope}) async {
    final String? threadId;
    switch (scope) {
      case PluginMcpProjectScope():
        return const PluginMcpInventoryUnavailable(
          reason: PluginMcpInventoryUnavailableReason.unsupportedScope,
          message: "Codex MCP inventory supports harness and existing thread scopes, not projects.",
        );
      case PluginMcpSessionScope(:final sessionId):
        threadId = sessionId;
      case PluginMcpHarnessScope():
        threadId = null;
    }
    try {
      final servers = <CodexMcpServerStatusDto>[];
      String? cursor;
      do {
        final page = await _appServerApi.listMcpServersPage(threadId: threadId, cursor: cursor);
        servers.addAll(page.data);
        cursor = page.nextCursor;
      } while (cursor != null);
      return _mapper.map(servers: servers, scope: scope);
    } on Object catch (error, stackTrace) {
      return PluginMcpInventoryReadFailed(
        cause: error is Exception ? error : CodexMcpInventoryReadException(innerError: error),
        causeStackTrace: stackTrace,
      );
    }
  }
}
