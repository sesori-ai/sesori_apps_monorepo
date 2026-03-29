import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
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
  final List<RequestHandler> _handlers;

  RequestRouter({
    required BridgePlugin plugin,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
  }) : _handlers = _buildHandlers(
         plugin: plugin,
         projectsDao: projectsDao,
         sessionDao: sessionDao,
       );

  static List<RequestHandler> _buildHandlers({
    required BridgePlugin plugin,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
  }) {
    final hiddenStore = projectsDao;
    final worktreeService = WorktreeService(
      projectsDao: projectsDao,
      sessionDao: sessionDao,
    );
    return [
      HealthCheckHandler(plugin),
      GetCurrentProjectHandler(plugin),
      GetProjectsHandler(plugin, hiddenStore),
      GetSessionStatusesHandler(plugin),
      GetChildSessionsHandler(plugin),
      GetSessionMessagesHandler(plugin),
      GetSessionsHandler(plugin, sessionDao),
      CreateSessionHandler(
        plugin: plugin,
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
    ];
  }

  /// Routes [request] to the first matching handler and returns its response.
  Future<RelayResponse> route(RelayRequest request) async {
    try {
      for (final handler in _handlers) {
        if (handler.canHandle(request)) {
          final (:pathParams, :queryParams, :fragment) = handler.extractParams(request);
          return await handler.handle(
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
