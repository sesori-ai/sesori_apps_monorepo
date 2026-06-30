import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../server/services/bridge_restart_service.dart";
import "../repositories/agent_repository.dart";
import "../repositories/filesystem_repository.dart";
import "../repositories/health_repository.dart";
import "../repositories/permission_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/provider_repository.dart";
import "../repositories/question_repository.dart";
import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "../services/project_initialization_service.dart";
import "../services/session_archive_service.dart";
import "../services/session_creation_service.dart";
import "../services/session_persistence_service.dart";
import "../services/worktree_service.dart";
import "abort_session_handler.dart";
import "create_project_handler.dart";
import "create_session_handler.dart";
import "delete_session_handler.dart";
import "filesystem_suggestions_handler.dart";
import "get_agents_handler.dart";
import "get_base_branch_handler.dart";
import "get_child_sessions_handler.dart";
import "get_commands_handler.dart";
import "get_current_project_handler.dart";
import "get_project_questions_handler.dart";
import "get_projects_handler.dart";
import "get_providers_handler.dart";
import "get_session_diffs_handler.dart";
import "get_session_handler.dart";
import "get_session_messages_handler.dart";
import "get_session_permissions_handler.dart";
import "get_session_questions_handler.dart";
import "get_session_statuses_handler.dart";
import "get_sessions_handler.dart";
import "health_check_handler.dart";
import "hide_project_handler.dart";
import "open_project_handler.dart";
import "post_agents_handler.dart";
import "reject_question_handler.dart";
import "rename_project_handler.dart";
import "rename_session_handler.dart";
import "reply_to_permission_handler.dart";
import "reply_to_question_handler.dart";
import "request_handler.dart";
import "restart_bridge_handler.dart";
import "send_prompt_handler.dart";
import "set_base_branch_handler.dart";
import "update_session_archive_status_handler.dart";

/// Routes incoming [RelayRequest]s to the first matching [RequestHandler].
///
/// Handlers are checked in registration order. The first matching handler wins.
///
/// Error handling is centralised here: any exception thrown by a handler is
/// converted to a `502` response so callers never have to deal with routing
/// failures.
class RequestRouter {
  final List<RequestHandlerBase> _handlers;

  RequestRouter({
    required BridgePluginApi plugin,
    required GetCommandsHandler getCommandsHandler,
    required SessionRepository sessionRepository,
    required AbortSessionHandler abortSessionHandler,
    required SessionCreationService sessionCreationService,
    required SessionArchiveService sessionArchiveService,
    required SendPromptHandler sendPromptHandler,
    required PrSyncService prSyncService,
    required ProjectRepository projectRepository,
    required FilesystemRepository filesystemRepository,
    required ProjectInitializationService projectInitializationService,
    required HealthRepository healthRepository,
    required ProviderRepository providerRepository,
    required AgentRepository agentRepository,
    required PermissionRepository permissionRepository,
    required QuestionRepository questionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required GetSessionDiffsHandler sessionDiffsHandler,
    required BridgeRestartService restartService,
  }) : _handlers = _buildHandlers(
         plugin: plugin,
         getCommandsHandler: getCommandsHandler,
         sessionRepository: sessionRepository,
         abortSessionHandler: abortSessionHandler,
         sessionCreationService: sessionCreationService,
         sessionArchiveService: sessionArchiveService,
         sendPromptHandler: sendPromptHandler,
         prSyncService: prSyncService,
         projectRepository: projectRepository,
         filesystemRepository: filesystemRepository,
         projectInitializationService: projectInitializationService,
         healthRepository: healthRepository,
         providerRepository: providerRepository,
         agentRepository: agentRepository,
         permissionRepository: permissionRepository,
         questionRepository: questionRepository,
         sessionPersistenceService: sessionPersistenceService,
         worktreeService: worktreeService,
         sessionDiffsHandler: sessionDiffsHandler,
         restartService: restartService,
       );

  static List<RequestHandlerBase> _buildHandlers({
    required BridgePluginApi plugin,
    required GetCommandsHandler getCommandsHandler,
    required SessionRepository sessionRepository,
    required AbortSessionHandler abortSessionHandler,
    required SessionCreationService sessionCreationService,
    required SessionArchiveService sessionArchiveService,
    required SendPromptHandler sendPromptHandler,
    required PrSyncService prSyncService,
    required ProjectRepository projectRepository,
    required FilesystemRepository filesystemRepository,
    required ProjectInitializationService projectInitializationService,
    required HealthRepository healthRepository,
    required ProviderRepository providerRepository,
    required AgentRepository agentRepository,
    required PermissionRepository permissionRepository,
    required QuestionRepository questionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required GetSessionDiffsHandler sessionDiffsHandler,
    required BridgeRestartService restartService,
  }) {
    return [
      HealthCheckHandler(healthRepository: healthRepository),
      RestartBridgeHandler(restartService: restartService),
      GetCurrentProjectHandler(plugin),
      GetProjectsHandler(projectRepository: projectRepository),
      getCommandsHandler,
      GetSessionStatusesHandler(plugin),
      GetChildSessionsHandler(sessionRepository: sessionRepository),
      GetSessionHandler(sessionRepository),
      GetSessionMessagesHandler(plugin),
      GetSessionsHandler(
        sessionRepository: sessionRepository,
        prSyncService: prSyncService,
        sessionPersistenceService: sessionPersistenceService,
      ),
      CreateSessionHandler(sessionCreationService: sessionCreationService),
      RenameSessionHandler(sessionRepository: sessionRepository),
      UpdateSessionArchiveStatusHandler(sessionArchiveService: sessionArchiveService),
      DeleteSessionHandler(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionPersistenceService: sessionPersistenceService,
      ),
      sendPromptHandler,
      abortSessionHandler,
      GetProvidersHandler(providerRepository),
      GetAgentsHandler(agentRepository),
      PostAgentsHandler(agentRepository),
      GetSessionQuestionsHandler(questionRepository: questionRepository),
      GetProjectQuestionsHandler(questionRepository: questionRepository),
      GetSessionPermissionsHandler(permissionRepository: permissionRepository),
      ReplyToQuestionHandler(questionRepository: questionRepository),
      RejectQuestionHandler(questionRepository: questionRepository),
      ReplyToPermissionHandler(permissionRepository: permissionRepository),
      RenameProjectHandler(projectRepository),
      CreateProjectHandler(
        projectInitializationService: projectInitializationService,
        projectRepository: projectRepository,
      ),
      OpenProjectHandler(
        filesystemRepository: filesystemRepository,
        projectRepository: projectRepository,
      ),
      HideProjectHandler(projectRepository: projectRepository),
      GetBaseBranchHandler(projectRepository: projectRepository),
      SetBaseBranchHandler(projectRepository: projectRepository),
      FilesystemSuggestionsHandler(filesystemRepository: filesystemRepository),
      sessionDiffsHandler,
    ];
  }

  /// Routes [request] to the first matching handler and returns its response.
  Future<RelayResponse> route(RelayRequest request) async {
    try {
      for (final handler in _handlers) {
        if (handler.canHandle(request)) {
          final (:pathParams, :queryParams, :fragment) = handler.extractParams(request);
          return await handler.handleInternal(
            request,
            pathParams: pathParams,
            queryParams: queryParams,
            fragment: fragment,
          );
        }
      }
      return RelayResponse(
        id: request.id,
        status: 404,
        headers: {},
        body: "no handler found for ${request.method} ${request.path}",
      );
    } on PluginOperationException catch (e) {
      Log.w("upstream error: $e");
      return RelayResponse(
        id: request.id,
        status: e.statusCode ?? 502,
        headers: {},
        body: e.toString(),
      );
    } catch (e) {
      return RelayResponse(
        id: request.id,
        status: 502,
        headers: {},
        body: "request failed: $e",
      );
    }
  }
}
