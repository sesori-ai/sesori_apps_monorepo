import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../repositories/project_repository.dart";
import "../repositories/session_repository.dart";

@lazySingleton
class SessionDetailLoadService {
  final SessionRepository _repository;
  final ProjectRepository _projectRepository;
  final ConnectionService _connectionService;

  SessionDetailLoadService({
    required SessionRepository repository,
    required ProjectRepository projectRepository,
    required ConnectionService connectionService,
  }) : _repository = repository,
       _projectRepository = projectRepository,
       _connectionService = connectionService;

  Future<SessionDetailLoadResult> load({required String sessionId, required String projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId);
  }

  Future<SessionDetailLoadResult> reload({required String sessionId, required String projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId);
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
      final projectContextFuture = _loadProjectSessionContext(sessionId: sessionId);
      final messagesFuture = _repository.getMessages(sessionId: sessionId);
      final questionsFuture = _repository.getPendingQuestions(sessionId: sessionId);
      final permissionsFuture = _repository.getPendingPermissions(sessionId: sessionId);
      final childrenFuture = _repository.getChildren(sessionId: sessionId);
      final statusesFuture = _repository.getSessionStatuses();
      final sessionResponse = await _repository.getSession(sessionId: sessionId);
      final projectContext = await projectContextFuture;
      final effectiveProjectId = routeProjectId ?? projectContext?.projectId;
      final session = switch (sessionResponse) {
        SuccessResponse(:final data) => data,
        ErrorResponse(:final error) => () {
          logw("Failed to load session: ${error.toString()}");
          return null;
        }(),
      };
      // COMPATIBILITY 2026-07-13 (v1.5.0): A failed legacy session lookup has no plugin identity. Remove this fallback when every load path supplies concrete identity.
      final pluginId = session?.pluginId ?? legacyMissingPluginId;
      final commandsFuture = _listCommands(projectId: effectiveProjectId, pluginId: pluginId);
      final agentsFuture = _listAgents(projectId: effectiveProjectId, pluginId: pluginId);
      final providersFuture = _listProviders(projectId: effectiveProjectId, pluginId: pluginId);
      final (
        messagesResponse,
        questionsResponse,
        permissionsResponse,
        childrenResponse,
        statusesResponse,
      ) = await (
        messagesFuture,
        questionsFuture,
        permissionsFuture,
        childrenFuture,
        statusesFuture,
      ).wait;
      final (commandsResponse, agentsResponse, providersResponse) = await (
        commandsFuture,
        agentsFuture,
        providersFuture,
      ).wait;
      final promptDefaults = session?.promptDefaults;

      final messages = switch (messagesResponse) {
        SuccessResponse(:final data) => data.messages,
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
          messages: messages,
          pendingQuestions: pendingQuestions,
          pendingPermissions: pendingPermissions,
          childSessions: childSessions,
          statuses: statuses,
          agents: agents,
          providerData: providerData,
          commands: commands,
          canonicalSessionTitle: projectContext?.sessionTitle,
          promptDefaults: promptDefaults,
          isRootSession: session != null ? session.parentID == null : null,
        ),
        isBridgeConnected: _connectionService.currentStatus is ConnectionConnected,
      );
    } on Object catch (error, stackTrace) {
      return SessionDetailLoadResult.failed(error: error, stackTrace: stackTrace);
    }
  }

  Future<ApiResponse<Agents>> _listAgents({required String? projectId, required String pluginId}) {
    final normalizedProjectId = projectId?.normalize();
    if (normalizedProjectId == null) {
      // Without any project context there is no way to scope the agent list;
      // an empty list keeps the UI consistent instead of guessing a project.
      return Future<ApiResponse<Agents>>.value(
        ApiResponse.success(const Agents(agents: <AgentInfo>[])),
      );
    }

    return _repository.listAgents(projectId: normalizedProjectId, pluginId: pluginId);
  }

  Future<ApiResponse<CommandListResponse>> _listCommands({required String? projectId, required String pluginId}) {
    final normalizedProjectId = projectId?.normalize();
    if (normalizedProjectId == null) {
      return Future<ApiResponse<CommandListResponse>>.value(
        ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
      );
    }

    return _repository.listCommands(projectId: normalizedProjectId, pluginId: pluginId);
  }

  Future<ApiResponse<ProviderListResponse>> _listProviders({required String? projectId, required String pluginId}) {
    final normalizedProjectId = projectId?.normalize();
    if (normalizedProjectId == null) {
      // Without any project context there is no project to scope providers to;
      // an empty list keeps the UI consistent instead of guessing a project.
      return Future<ApiResponse<ProviderListResponse>>.value(
        ApiResponse.success(const ProviderListResponse(items: <ProviderInfo>[], connectedOnly: false)),
      );
    }

    return _repository.listProviders(projectId: normalizedProjectId, pluginId: pluginId);
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
  final List<MessageWithParts> messages;
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

  const SessionDetailSnapshot({
    required this.projectId,
    required this.messages,
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
  });
}

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
