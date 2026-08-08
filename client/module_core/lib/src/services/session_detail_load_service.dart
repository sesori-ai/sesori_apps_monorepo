import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../repositories/plugin_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/session_repository.dart";

@lazySingleton
class SessionDetailLoadService {
  /// Messages fetched when a session opens. Large enough that most sessions
  /// arrive complete in one page, small enough that a very long one does not
  /// ship in full before anything renders.
  static const initialPageSize = 50;

  /// Messages fetched per load-older request.
  static const olderPageSize = 50;

  final SessionRepository _repository;
  final ProjectRepository _projectRepository;
  final PluginRepository _pluginRepository;
  final ConnectionService _connectionService;

  SessionDetailLoadService({
    required SessionRepository repository,
    required ProjectRepository projectRepository,
    required PluginRepository pluginRepository,
    required ConnectionService connectionService,
  }) : _repository = repository,
       _projectRepository = projectRepository,
       _pluginRepository = pluginRepository,
       _connectionService = connectionService;

  Future<SessionDetailLoadResult> load({required String sessionId, required String projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId);
  }

  Future<SessionDetailLoadResult> reload({required String sessionId, required String projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId);
  }

  /// One page of messages older than [before], for a load-older action.
  ///
  /// Returns null when the page could not be fetched, so the caller can keep
  /// the cursor and let the user retry rather than treating it as the end of
  /// the transcript.
  Future<SessionMessagePage?> loadOlderMessages({
    required String sessionId,
    required int before,
  }) async {
    final response = await _repository.getMessages(
      sessionId: sessionId,
      limit: olderPageSize,
      before: before,
    );
    return switch (response) {
      SuccessResponse(:final data) => (messages: data.messages, olderMessagesCursor: data.nextCursor),
      ErrorResponse(:final error) => () {
        logw("Failed to load older messages: ${error.toString()}");
        return null;
      }(),
    };
  }

  Future<SessionDetailLoadResult> _loadSnapshot({
    required String sessionId,
    required String projectId,
  }) async {
    if (_connectionService.currentStatus is! ConnectionConnected) {
      return const SessionDetailLoadResult.waitingForConnection();
    }

    try {
      final routeProjectId = projectId.normalize();
      // Only the newest page: a long transcript otherwise ships in full on
      // every open, reconnect, and reload. Older messages load on demand.
      final messagesFuture = _repository.getMessages(
        sessionId: sessionId,
        limit: initialPageSize,
        before: null,
      );
      final childrenFuture = _repository.getChildren(sessionId: sessionId);
      final sessionResponse = await _repository.getSession(sessionId: sessionId);
      final session = switch (sessionResponse) {
        SuccessResponse(:final data) => data,
        ErrorResponse(:final error) => () {
          logw("Failed to load session: ${error.toString()}");
          return null;
        }(),
      };
      final fallbackContext = session == null ? await _loadProjectSessionContext(sessionId: sessionId) : null;
      final effectiveProjectId = routeProjectId ?? session?.projectID.normalize() ?? fallbackContext?.projectId;
      final pluginId = session?.pluginId ?? fallbackContext?.pluginId;
      final commandsFuture = _listCommands(projectId: effectiveProjectId, pluginId: pluginId);
      final agentsFuture = _listAgents(projectId: effectiveProjectId, pluginId: pluginId);
      final providersFuture = _listProviders(projectId: effectiveProjectId, pluginId: pluginId);
      final promptAttachmentSupportFuture = _loadPromptAttachmentSupport(pluginId: pluginId);
      // Stage 4 child discovery persists legacy bindings. Pending input must
      // observe those bindings rather than race the compatibility backfill.
      final childrenResponse = await childrenFuture;
      final questionsFuture = _repository.getPendingQuestions(sessionId: sessionId);
      final permissionsFuture = _repository.getPendingPermissions(sessionId: sessionId);
      final statusesFuture = _repository.getSessionStatuses();
      final (
        messagesResponse,
        questionsResponse,
        permissionsResponse,
        statusesResponse,
      ) = await (
        messagesFuture,
        questionsFuture,
        permissionsFuture,
        statusesFuture,
      ).wait;
      final (commandsResponse, agentsResponse, providersResponse, supportsPromptAttachments) = await (
        commandsFuture,
        agentsFuture,
        providersFuture,
        promptAttachmentSupportFuture,
      ).wait;
      final promptDefaults = session?.promptDefaults;

      final (messages, olderMessagesCursor) = switch (messagesResponse) {
        SuccessResponse(:final data) => (data.messages, data.nextCursor),
        ErrorResponse(:final error) => throw error,
      };

      final pendingQuestions = switch (questionsResponse) {
        SuccessResponse(:final data) => data.data,
        ErrorResponse() => <PendingQuestion>[],
      };
      final pendingPermissions = switch (permissionsResponse) {
        SuccessResponse(:final data) => data.data,
        ErrorResponse() => <PendingPermission>[],
      };
      final childSessions = switch (childrenResponse) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => <Session>[],
      };
      final statuses = switch (statusesResponse) {
        SuccessResponse(:final data) => data.statuses,
        ErrorResponse() => <String, SessionStatus>{},
      };
      final agents = switch (agentsResponse) {
        SuccessResponse(:final data) => data.agents,
        ErrorResponse(:final error) => () {
          loge("Failed to load agents: ${error.toString()}");
          return <AgentInfo>[];
        }(),
      };
      final providerData = switch (providersResponse) {
        SuccessResponse(:final data) => data,
        ErrorResponse(:final error) => () {
          loge("Failed to load providers: ${error.toString()}");
          return null;
        }(),
      };
      final commands = switch (commandsResponse) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse(:final error) => () {
          loge("Failed to load commands: ${error.toString()}");
          return <CommandInfo>[];
        }(),
      };

      return SessionDetailLoadResult.loaded(
        snapshot: SessionDetailSnapshot(
          projectId: effectiveProjectId,
          pluginId: pluginId,
          supportsPromptAttachments: supportsPromptAttachments,
          messages: messages,
          olderMessagesCursor: olderMessagesCursor,
          pendingQuestions: pendingQuestions,
          pendingPermissions: pendingPermissions,
          childSessions: childSessions,
          statuses: statuses,
          agents: agents,
          providerData: providerData,
          commands: commands,
          canonicalSessionTitle: session?.title ?? fallbackContext?.sessionTitle,
          promptDefaults: promptDefaults,
          isRootSession: session != null ? session.parentID == null : null,
          isArchived: session?.time?.archived != null,
        ),
        isBridgeConnected: _connectionService.currentStatus is ConnectionConnected,
      );
    } on Object catch (error, stackTrace) {
      return SessionDetailLoadResult.failed(error: error, stackTrace: stackTrace);
    }
  }

  Future<ApiResponse<Agents>> _listAgents({required String? projectId, required String? pluginId}) {
    final normalizedProjectId = projectId?.normalize();
    if (normalizedProjectId == null || pluginId == null) {
      // Without any project context there is no way to scope the agent list;
      // an empty list keeps the UI consistent instead of guessing a project.
      return Future<ApiResponse<Agents>>.value(
        ApiResponse.success(const Agents(agents: <AgentInfo>[])),
      );
    }

    return _repository.listAgents(projectId: normalizedProjectId, pluginId: pluginId);
  }

  Future<ApiResponse<CommandListResponse>> _listCommands({required String? projectId, required String? pluginId}) {
    final normalizedProjectId = projectId?.normalize();
    if (normalizedProjectId == null || pluginId == null) {
      return Future<ApiResponse<CommandListResponse>>.value(
        ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
      );
    }

    return _repository.listCommands(projectId: normalizedProjectId, pluginId: pluginId);
  }

  Future<ApiResponse<ProviderListResponse>> _listProviders({required String? projectId, required String? pluginId}) {
    final normalizedProjectId = projectId?.normalize();
    if (normalizedProjectId == null || pluginId == null) {
      // Without any project context there is no project to scope providers to;
      // an empty list keeps the UI consistent instead of guessing a project.
      return Future<ApiResponse<ProviderListResponse>>.value(
        ApiResponse.success(const ProviderListResponse(items: <ProviderInfo>[], connectedOnly: false)),
      );
    }

    return _repository.listProviders(projectId: normalizedProjectId, pluginId: pluginId);
  }

  Future<bool?> _loadPromptAttachmentSupport({required String? pluginId}) async {
    if (pluginId == null) return null;

    try {
      switch (await _pluginRepository.listPlugins()) {
        case SuccessResponse(:final data):
          for (final plugin in data.plugins) {
            if (plugin.id == pluginId) return plugin.supportsPromptAttachments;
          }
          return null;
        case ErrorResponse(:final error):
          logw("Failed to load prompt attachment capability for plugin $pluginId", error);
          return null;
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to load prompt attachment capability for plugin $pluginId", error, stackTrace);
      return null;
    }
  }

  Future<ProjectSessionContext?> _loadProjectSessionContext({required String sessionId}) async {
    try {
      return await _projectRepository.findSessionContext(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      logw("Failed to load project session context: ${error.toString()}", error, stackTrace);
      return null;
    }
  }
}

class SessionDetailSnapshot {
  final String? projectId;

  /// The harness running this session, or `null` when neither the session nor
  /// the project fallback resolved it.
  final String? pluginId;

  /// Whether the session's plugin explicitly declares inline attachment
  /// support, or `null` when plugin metadata could not be resolved.
  final bool? supportsPromptAttachments;
  final List<MessageWithParts> messages;

  /// Cursor for the page before [messages], or null when the transcript is
  /// complete — either because it all fits, or because the bridge predates
  /// pagination and always sends everything.
  final int? olderMessagesCursor;
  final List<PendingQuestion> pendingQuestions;
  final List<PendingPermission> pendingPermissions;
  final List<Session> childSessions;
  final Map<String, SessionStatus> statuses;
  final List<AgentInfo?> agents;
  final ProviderListResponse? providerData;
  final List<CommandInfo> commands;
  final String? canonicalSessionTitle;
  final SessionPromptDefaults? promptDefaults;

  /// Whether this session is a root (main) session. `true` when the session
  /// metadata confirms `parentID == null`; `false` when `parentID != null`;
  /// `null` when the session metadata lookup failed, so we cannot tell.
  final bool? isRootSession;
  final bool isArchived;

  const SessionDetailSnapshot({
    required this.projectId,
    required this.pluginId,
    required this.supportsPromptAttachments,
    required this.messages,
    required this.olderMessagesCursor,
    required this.pendingQuestions,
    required this.pendingPermissions,
    required this.childSessions,
    required this.statuses,
    required this.agents,
    required this.providerData,
    required this.commands,
    required this.canonicalSessionTitle,
    required this.promptDefaults,
    required this.isRootSession,
    required this.isArchived,
  });
}

/// One page of history plus the cursor for the page before it.
typedef SessionMessagePage = ({List<MessageWithParts> messages, int? olderMessagesCursor});

sealed class SessionDetailLoadResult {
  const SessionDetailLoadResult();

  const factory SessionDetailLoadResult.loaded({
    required SessionDetailSnapshot snapshot,
    required bool isBridgeConnected,
  }) = SessionDetailLoadResultLoaded;

  const factory SessionDetailLoadResult.waitingForConnection() = SessionDetailLoadResultWaitingForConnection;

  const factory SessionDetailLoadResult.failed({
    // ignore: no_slop_linter/prefer_specific_type
    required Object error,
    required StackTrace? stackTrace,
  }) = SessionDetailLoadResultFailed;
}

final class SessionDetailLoadResultLoaded extends SessionDetailLoadResult {
  final SessionDetailSnapshot snapshot;
  final bool isBridgeConnected;

  const SessionDetailLoadResultLoaded({required this.snapshot, required this.isBridgeConnected});
}

final class SessionDetailLoadResultWaitingForConnection extends SessionDetailLoadResult {
  const SessionDetailLoadResultWaitingForConnection();
}

final class SessionDetailLoadResultFailed extends SessionDetailLoadResult {
  // ignore: no_slop_linter/prefer_specific_type
  final Object error;
  final StackTrace? stackTrace;

  const SessionDetailLoadResultFailed({required this.error, required this.stackTrace});
}
