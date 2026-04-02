import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../metadata_service.dart";
import "../persistence/dao_interfaces.dart";
import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/pull_request_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../pr/gh_cli_service.dart";
import "../pr/pr_refresh_coordinator.dart";
import "../pr/pr_sync_service.dart";
import "../worktree_service.dart";
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
    required MetadataService metadataService,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    void Function(SesoriSseEvent event)? emitBridgeEvent,
    ProcessRunner processRunner = Process.run,
    PullRequestDaoLike? pullRequestDao,
    GhCliService? ghCli,
    PrSyncService? prSyncService,
    PrRefreshCoordinator? prRefreshCoordinator,
  }) : _handlers = _buildHandlers(
         plugin: plugin,
         metadataService: metadataService,
         projectsDao: projectsDao,
         sessionDao: sessionDao,
         emitBridgeEvent: emitBridgeEvent,
         processRunner: processRunner,
         pullRequestDao: pullRequestDao,
         ghCli: ghCli,
         prSyncService: prSyncService,
         prRefreshCoordinator: prRefreshCoordinator,
       );

  static List<RequestHandlerBase> _buildHandlers({
    required BridgePlugin plugin,
    required MetadataService metadataService,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required void Function(SesoriSseEvent event)? emitBridgeEvent,
    required ProcessRunner processRunner,
    required PullRequestDaoLike? pullRequestDao,
    required GhCliService? ghCli,
    required PrSyncService? prSyncService,
    required PrRefreshCoordinator? prRefreshCoordinator,
  }) {
    final hiddenStore = projectsDao;
    final prDao = pullRequestDao ?? PullRequestDao(sessionDao.attachedDatabase);
    final effectiveGhCli = ghCli ?? GhCliService();
    final effectiveEmitBridgeEvent = emitBridgeEvent ?? _noopEmitBridgeEvent;
    final effectivePrRefreshCoordinator =
        prRefreshCoordinator ??
        (() {
          late final PrRefreshCoordinator coordinator;
          final effectivePrSyncService =
              prSyncService ??
              PrSyncService(
                ghCli: effectiveGhCli,
                prDao: prDao,
                sessionDao: sessionDao,
                onPrDataChanged: (String projectId) {
                  coordinator.onPrDataChanged(projectId: projectId);
                },
              );
          coordinator = PrRefreshCoordinator(
            ghCli: effectiveGhCli,
            prSyncService: effectivePrSyncService,
            processRunner: processRunner,
            emitBridgeEvent: effectiveEmitBridgeEvent,
          );
          return coordinator;
        })();

    final worktreeService = WorktreeService(
      projectsDao: projectsDao,
      sessionDao: sessionDao,
    );
    return [
      HealthCheckHandler(plugin),
      GetCurrentProjectHandler(plugin),
      GetProjectsHandler(plugin, hiddenStore),
      GetSessionStatusesHandler(plugin),
      GetChildSessionsHandler(plugin, prDao),
      GetSessionMessagesHandler(plugin),
      GetSessionsHandler(
        plugin,
        sessionDao,
        prDao,
        onSessionListRequested: effectivePrRefreshCoordinator.onSessionListRequested,
      ),
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
      ),
      DeleteSessionHandler(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionDao: sessionDao,
      ),
      SendPromptHandler(plugin),
      AbortSessionHandler(plugin),
      GetProvidersHandler(plugin),
      GetAgentsHandler(plugin),
      GetSessionQuestionsHandler(plugin),
      GetProjectQuestionsHandler(plugin),
      ReplyToQuestionHandler(plugin),
      RejectQuestionHandler(plugin),
      RenameProjectHandler(plugin),
      CreateProjectHandler(plugin),
      OpenProjectHandler(plugin, hiddenStore),
      HideProjectHandler(hiddenStore),
      GetBaseBranchHandler(projectsDao),
      SetBaseBranchHandler(projectsDao),
      FilesystemSuggestionsHandler(),
      GetSessionDiffsHandler(sessionDao),
    ];
  }

  static void _noopEmitBridgeEvent(SesoriSseEvent event) {}

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
