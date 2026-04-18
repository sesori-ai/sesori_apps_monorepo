import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/permission_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/provider_repository.dart";
import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
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
import "get_current_project_handler.dart";
import "get_project_questions_handler.dart";
import "get_projects_handler.dart";
import "get_providers_handler.dart";
import "get_session_diffs_handler.dart";
import "get_session_messages_handler.dart";
import "get_session_questions_handler.dart";
import "get_session_statuses_handler.dart";
import "get_sessions_handler.dart";
import "health_check_handler.dart";
import "hide_project_handler.dart";
import "open_project_handler.dart";
import "reject_question_handler.dart";
import "rename_project_handler.dart";
import "rename_session_handler.dart";
import "reply_to_permission_handler.dart";
import "reply_to_question_handler.dart";
import "request_handler.dart";
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
    required BridgePlugin plugin,
    required SessionRepository sessionRepository,
    required AbortSessionHandler abortSessionHandler,
    required SessionCreationService sessionCreationService,
    required SessionArchiveService sessionArchiveService,
    required PrSyncService prSyncService,
    required ProjectRepository projectRepository,
    required ProviderRepository providerRepository,
    required PermissionRepository permissionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required GetSessionDiffsHandler sessionDiffsHandler,
  }) : _handlers = _buildHandlers(
         plugin: plugin,
         sessionRepository: sessionRepository,
         abortSessionHandler: abortSessionHandler,
         sessionCreationService: sessionCreationService,
         sessionArchiveService: sessionArchiveService,
         prSyncService: prSyncService,
         projectRepository: projectRepository,
         providerRepository: providerRepository,
         permissionRepository: permissionRepository,
         sessionPersistenceService: sessionPersistenceService,
         worktreeService: worktreeService,
         sessionDiffsHandler: sessionDiffsHandler,
       );

  static List<RequestHandlerBase> _buildHandlers({
    required BridgePlugin plugin,
    required SessionRepository sessionRepository,
    required AbortSessionHandler abortSessionHandler,
    required SessionCreationService sessionCreationService,
    required SessionArchiveService sessionArchiveService,
    required PrSyncService prSyncService,
    required ProjectRepository projectRepository,
    required ProviderRepository providerRepository,
    required PermissionRepository permissionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required GetSessionDiffsHandler sessionDiffsHandler,
  }) {
    return [
      HealthCheckHandler(plugin),
      GetCurrentProjectHandler(plugin),
      GetProjectsHandler(projectRepository: projectRepository),
      GetSessionStatusesHandler(plugin),
      GetChildSessionsHandler(sessionRepository: sessionRepository),
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
      SendPromptHandler(plugin),
      abortSessionHandler,
      GetProvidersHandler(providerRepository),
      GetAgentsHandler(plugin),
      GetSessionQuestionsHandler(plugin),
      GetProjectQuestionsHandler(plugin),
      ReplyToQuestionHandler(plugin),
      RejectQuestionHandler(plugin),
      ReplyToPermissionHandler(permissionRepository: permissionRepository),
      RenameProjectHandler(plugin),
      CreateProjectHandler(plugin),
      OpenProjectHandler(projectRepository: projectRepository),
      HideProjectHandler(projectRepository: projectRepository),
      GetBaseBranchHandler(projectRepository: projectRepository),
      SetBaseBranchHandler(projectRepository: projectRepository),
      FilesystemSuggestionsHandler(),
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
    } on PluginApiException catch (e) {
      Log.w("upstream error: $e");
      return RelayResponse(
        id: request.id,
        status: e.statusCode,
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
