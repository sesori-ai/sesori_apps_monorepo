import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/hidden_projects_store.dart";
import "abort_session_handler.dart";
import "create_project_handler.dart";
import "create_session_handler.dart";
import "delete_session_handler.dart";
import "filesystem_suggestions_handler.dart";
import "get_agents_handler.dart";
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
import "reply_to_question_handler.dart";
import "request_handler.dart";
import "send_prompt_handler.dart";
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

  RequestRouter({required BridgePlugin plugin, required HiddenProjectsStore hiddenProjectsStore})
    : _handlers = _buildHandlers(plugin: plugin, hiddenProjectsStore: hiddenProjectsStore);

  static List<RequestHandler> _buildHandlers({
    required BridgePlugin plugin,
    required HiddenProjectsStore hiddenProjectsStore,
  }) {
    final hiddenStore = hiddenProjectsStore;
    return [
      HealthCheckHandler(plugin),
      GetCurrentProjectHandler(plugin),
      GetProjectsHandler(plugin, hiddenStore),
      GetSessionStatusesHandler(plugin),
      GetChildSessionsHandler(plugin),
      GetSessionMessagesHandler(plugin),
      GetSessionsHandler(plugin),
      CreateSessionHandler(plugin),
      UpdateSessionArchiveStatusHandler(plugin),
      DeleteSessionHandler(plugin),
      SendPromptHandler(plugin),
      AbortSessionHandler(plugin),
      GetProvidersHandler(plugin),
      GetAgentsHandler(plugin),
      GetSessionQuestionsHandler(plugin),
      GetProjectQuestionsHandler(plugin),
      ReplyToQuestionHandler(plugin),
      RejectQuestionHandler(plugin),
      CreateProjectHandler(plugin),
      OpenProjectHandler(plugin, hiddenStore),
      HideProjectHandler(hiddenStore),
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
