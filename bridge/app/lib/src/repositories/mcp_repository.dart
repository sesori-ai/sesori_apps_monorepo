import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/projects_dao.dart";
import "../api/database/daos/session_dao.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/mcp_mapper.dart";
import "models/mcp_control_result.dart";
import "models/mcp_operation.dart";
import "models/project_not_found_exception.dart";

/// Resolves bridge-owned scopes without activating a backend or agent session.
class McpRepository({
  required final PluginRuntime _runtime,
  required final SessionDao _sessionDao,
  required final ProjectsDao _projectsDao,
}) {
  Future<McpInventoryResult> getInventory({required String pluginId, required McpScope scope}) async {
    final nativeScope = await _resolveScope(pluginId: pluginId, scope: scope, operation: McpOperation.getInventory);
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
        final native = await (plugin as McpManagementPluginApi).getMcpInventory(scope: nativeScope);
        if (native case PluginMcpInventoryReadFailed(:final cause, :final causeStackTrace)) {
          Log.w("MCP inventory read failed for $pluginId in $scope", cause, causeStackTrace);
        }
        return const McpMapper().map(scope: scope, result: native);
      },
    );
    return result ??
        McpInventoryUnavailable(
          scope: scope,
          reason: McpInventoryUnavailableReason.pluginInactive,
          message: "Start the integration before reading MCP inventory.",
        );
  }

  Future<McpControlResult> executeServerAction({
    required String pluginId,
    required McpServerTarget target,
    required McpServerAction action,
  }) async {
    final nativeScope = await _resolveScope(
      pluginId: pluginId,
      scope: target.scope,
      operation: McpOperation.executeAction,
    );
    final nativeAction = switch (action) {
      McpServerAction.reconnect => PluginMcpServerAction.reconnect,
      McpServerAction.enable => PluginMcpServerAction.enable,
      McpServerAction.disable => PluginMcpServerAction.disable,
      McpServerAction.unknown => throw PluginOperationException(
        McpOperation.executeAction.name,
        message: "Unsupported MCP action.",
        statusCode: 400,
      ),
    };
    final result = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: McpOperation.executeAction,
      body: (plugin, _) async {
        if (plugin is! McpManagementPluginApi) {
          return const McpControlUnavailable(reason: McpActionUnavailableReason.unsupportedHarness);
        }
        final native = await (plugin as McpManagementPluginApi).executeMcpServerAction(
          target: PluginMcpServerTarget(scope: nativeScope, serverKey: target.serverKey),
          action: nativeAction,
        );
        return switch (native) {
          PluginMcpActionCompleted() => const McpControlCompleted(),
          PluginMcpActionUnavailable(:final reason) => McpControlUnavailable(
            reason: switch (reason) {
              PluginMcpActionUnavailableReason.unsupportedScope => McpActionUnavailableReason.unsupportedScope,
              PluginMcpActionUnavailableReason.liveSessionRequired => McpActionUnavailableReason.liveSessionRequired,
              PluginMcpActionUnavailableReason.targetNotFound => McpActionUnavailableReason.targetNotFound,
            },
          ),
          PluginMcpActionFailed(:final cause, :final causeStackTrace) => _actionFailed(
            pluginId: pluginId,
            target: target,
            cause: cause,
            stackTrace: causeStackTrace,
          ),
        };
      },
    );
    return result ?? const McpControlUnavailable(reason: McpActionUnavailableReason.pluginInactive);
  }

  McpControlFailed _actionFailed({
    required String pluginId,
    required McpServerTarget target,
    required Exception cause,
    required StackTrace stackTrace,
  }) {
    Log.w("MCP action failed for $pluginId on $target", cause, stackTrace);
    return const McpControlFailed();
  }

  Future<PluginMcpScope> _resolveScope({
    required String pluginId,
    required McpScope scope,
    required McpOperation operation,
  }) async {
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
            operation.name,
            message: "Session not found: $sessionId",
          );
        }
        if (session.pluginId != pluginId) {
          throw PluginOperationException(
            operation.name,
            message: "The session does not belong to the selected integration.",
            statusCode: 400,
          );
        }
        if (operation == McpOperation.executeAction && session.archivedAt != null) {
          throw PluginOperationException(operation.name, message: "Archived sessions are read only.", statusCode: 409);
        }
        return PluginMcpSessionScope(sessionId: session.backendSessionId);
    }
  }
}
