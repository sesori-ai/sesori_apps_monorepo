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

  Future<SessionDetailLoadResult> load({required String sessionId, String? projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId);
  }

  Future<SessionDetailLoadResult> reload({required String sessionId, String? projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId);
  }

  Future<SessionDetailLoadResult> _loadSnapshot({required String sessionId, String? projectId}) async {
    if (_connectionService.currentStatus is! ConnectionConnected) {
      return const SessionDetailLoadResult.waitingForConnection();
    }

    try {
      final routeProjectId = _normalizeOptionalText(projectId);
      final projectContextFuture = _loadProjectSessionContext(sessionId: sessionId);
      final commandsFuture = routeProjectId == null
          ? null
          : _listCommands(projectId: routeProjectId);
      final (
        messagesResponse,
        questionsResponse,
        permissionsResponse,
        childrenResponse,
        statusesResponse,
        agentsResponse,
        providersResponse,
      ) = await (
        _repository.getMessages(sessionId: sessionId),
        _repository.getPendingQuestions(sessionId: sessionId),
        _repository.getPendingPermissions(),
        _repository.getChildren(sessionId: sessionId),
        _repository.getSessionStatuses(),
        _repository.listAgents(),
        _repository.listProviders(),
      ).wait;
      final projectContext = await projectContextFuture;
      final effectiveProjectId = routeProjectId ?? projectContext?.projectId;
      final commandsResponse = await (commandsFuture ?? _listCommands(projectId: effectiveProjectId));

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
        ),
        isBridgeConnected: _connectionService.currentStatus is ConnectionConnected,
      );
    } on Object catch (error, stackTrace) {
      return SessionDetailLoadResult.failed(error: error, stackTrace: stackTrace);
    }
  }

  Future<ApiResponse<CommandListResponse>> _listCommands({required String? projectId}) {
    final normalizedProjectId = _normalizeOptionalText(projectId);
    if (normalizedProjectId == null) {
      return Future<ApiResponse<CommandListResponse>>.value(
        ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
      );
    }

    return _repository.listCommands(projectId: normalizedProjectId);
  }

  Future<ProjectSessionContext?> _loadProjectSessionContext({required String sessionId}) async {
    try {
      return await _projectRepository.findSessionContext(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      logw("Failed to load project session context: ${error.toString()}", error, stackTrace);
      return null;
    }
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
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
  final Object error;
  final StackTrace? stackTrace;

  const SessionDetailLoadResultFailed({required this.error, required this.stackTrace});
}
