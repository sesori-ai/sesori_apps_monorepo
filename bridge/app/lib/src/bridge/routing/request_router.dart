import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/process_runner.dart";
import "../metadata_service.dart";
import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../repositories/permission_repository.dart";
import "../repositories/provider_repository.dart";
import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "../worktree_service.dart";
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
import "send_command_handler.dart";
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
    required MetadataService metadataService,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
  }) : _handlers = _buildHandlers(
         plugin: plugin,
         metadataService: metadataService,
         projectsDao: projectsDao,
         sessionDao: sessionDao,
         sessionRepository: sessionRepository,
         prSyncService: prSyncService,
       );

  static List<RequestHandlerBase> _buildHandlers({
    required BridgePlugin plugin,
    required MetadataService metadataService,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
  }) {
    final hiddenStore = projectsDao;
    final permissionRepository = PermissionRepository(plugin: plugin);

    final worktreeService = WorktreeService(
      projectsDao: projectsDao,
      sessionDao: sessionDao,
      processRunner: ProcessRunner(),
      gitPathExists: ({required String gitPath}) => FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound,
    );
    return [
      HealthCheckHandler(plugin),
      GetCurrentProjectHandler(plugin),
      GetProjectsHandler(plugin, hiddenStore),
      GetCommandsHandler(plugin),
      GetSessionStatusesHandler(plugin),
      GetChildSessionsHandler(sessionRepository: sessionRepository),
      GetSessionMessagesHandler(plugin),
      GetSessionsHandler(sessionRepository: sessionRepository, prSyncService: prSyncService),
      CreateSessionHandler(
        plugin: plugin,
        metadataService: metadataService,
        worktreeService: worktreeService,
        sessionDao: sessionDao,
      ),
      RenameSessionHandler(plugin),
      UpdateSessionArchiveStatusHandler(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionDao: sessionDao,
        sessionRepository: sessionRepository,
      ),
      DeleteSessionHandler(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionDao: sessionDao,
        sessionRepository: sessionRepository,
      ),
      SendPromptHandler(plugin),
      SendCommandHandler(plugin),
      AbortSessionHandler(plugin),
      GetProvidersHandler(ProviderRepository(plugin: plugin)),
      GetAgentsHandler(plugin),
      GetSessionQuestionsHandler(plugin),
      GetProjectQuestionsHandler(plugin),
      ReplyToQuestionHandler(plugin),
      RejectQuestionHandler(plugin),
      ReplyToPermissionHandler(permissionRepository: permissionRepository),
      RenameProjectHandler(plugin),
      CreateProjectHandler(plugin),
      OpenProjectHandler(plugin, hiddenStore),
      HideProjectHandler(hiddenStore),
      GetBaseBranchHandler(projectsDao),
      SetBaseBranchHandler(projectsDao),
      FilesystemSuggestionsHandler(),
      GetSessionDiffsHandler(sessionDao, processRunner: ProcessRunner()),
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
