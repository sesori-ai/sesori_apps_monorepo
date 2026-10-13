import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/projects_dao.dart";
import "../api/database/daos/session_dao.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/mcp_mapper.dart";
import "models/mcp_operation.dart";
import "models/project_not_found_exception.dart";

/// Resolves bridge-owned scopes without activating a backend or agent session.
class McpRepository({
  required final PluginRuntime _runtime,
  required final SessionDao _sessionDao,
  required final ProjectsDao _projectsDao,
}) {
  Future<McpInventoryResult> getInventory({required String pluginId, required McpScope scope}) async {
    final nativeScope = await _resolveScope(pluginId: pluginId, scope: scope);
    final result = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: McpOperation.getInventory,
      body: (plugin, _) async {
        if (plugin is! McpManagementPluginApi) {
          return McpInventoryUnavailable(
            scope: scope,
            reason: McpInventoryUnavailableReason.unsupportedHarness,
            message: "This integration does not yet expose MCP inventory.",
          );
        }
        return const McpMapper().map(
          scope: scope,
          result: await (plugin as McpManagementPluginApi).getMcpInventory(scope: nativeScope),
        );
      },
    );
    return result ??
        McpInventoryUnavailable(
          scope: scope,
          reason: McpInventoryUnavailableReason.pluginInactive,
          message: "Start the integration before reading MCP inventory.",
        );
  }

  Future<PluginMcpScope> _resolveScope({required String pluginId, required McpScope scope}) async {
    switch (scope) {
      case McpHarnessScope():
        return const PluginMcpHarnessScope();
      case McpProjectScope(:final projectId):
        final project = await _projectsDao.getProject(projectId: projectId);
        if (project == null) throw ProjectNotFoundException(projectId: projectId);
        return PluginMcpProjectScope(projectId: project.path);
      case McpSessionScope(:final sessionId):
        final session = await _sessionDao.getSession(sessionId: sessionId);
        if (session == null) {
          throw PluginOperationException.notFound(
            McpOperation.getInventory.name,
            message: "Session not found: $sessionId",
          );
        }
        if (session.pluginId != pluginId) {
          throw PluginOperationException(
            McpOperation.getInventory.name,
            message: "The session does not belong to the selected integration.",
            statusCode: 400,
          );
        }
        return PluginMcpSessionScope(sessionId: session.backendSessionId);
    }
  }
}
