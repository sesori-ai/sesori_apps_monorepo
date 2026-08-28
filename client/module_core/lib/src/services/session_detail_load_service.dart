import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/session_options/session_options_request_mode.dart";
import "../logging/logging.dart";
import "../repositories/models/session_options_repository_result.dart";
import "../repositories/plugin_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/session_repository.dart";

@lazySingleton
class SessionDetailLoadService({
  required final SessionRepository _repository,
  required final ProjectRepository _projectRepository,
  required final PluginRepository _pluginRepository,
  required final ConnectionService _connectionService,
}) {
  /// Messages fetched when a session opens. Large enough that most sessions
  /// arrive complete in one page, small enough that a very long one does not
  /// ship in full before anything renders.
  static const initialPageSize = 50;

  /// Messages fetched per load-older request.
  static const olderPageSize = 50;

  Future<SessionDetailLoadResult> load({required String sessionId, required String projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId, requireCompleteOptions: false);
  }

  Future<SessionDetailLoadResult> reload({required String sessionId, required String projectId}) {
    return _loadSnapshot(sessionId: sessionId, projectId: projectId, requireCompleteOptions: true);
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
    required bool requireCompleteOptions,
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
      final isArchived = session?.time?.archived != null;
      final optionsFuture = isArchived
          ? Future<_SessionDetailOptionsResult>.value(
              const _SessionDetailOptionsAvailable(
                options: (
                  agents: <AgentInfo>[],
                  providerData: null,
                  commands: <CommandInfo>[],
                ),
              ),
            )
          : _loadSessionOptions(
              projectId: effectiveProjectId,
              pluginId: pluginId,
              requireComplete: requireCompleteOptions,
            );
      final promptAttachmentSupportFuture = isArchived
          ? Future<bool?>.value(null)
          : _loadPromptAttachmentSupport(pluginId: pluginId);
      // Stage 4 child discovery persists legacy bindings. Pending input must
      // observe those bindings rather than race the compatibility backfill.
      final childrenResponse = await childrenFuture;
      final questionsFuture = _repository.getPendingQuestions(sessionId: sessionId);
      final permissionsFuture = _repository.getPendingPermissions(sessionId: sessionId);
      final statusesFuture = _repository.getSessionStatuses();
      final queuedPromptsFuture = _repository.getQueuedPrompts(sessionId: sessionId);
      final (
        messagesResponse,
        questionsResponse,
        permissionsResponse,
        statusesResponse,
        queuedPromptsResponse,
      ) = await (
        messagesFuture,
        questionsFuture,
        permissionsFuture,
        statusesFuture,
        queuedPromptsFuture,
      ).wait;
      final (optionsResult, supportsPromptAttachments) = await (
        optionsFuture,
        promptAttachmentSupportFuture,
      ).wait;
      final options = switch (optionsResult) {
        _SessionDetailOptionsAvailable(:final options) => options,
        _SessionDetailOptionsFailure(:final error, :final stackTrace) => Error.throwWithStackTrace(error, stackTrace),
      };
      final (messages, olderMessagesCursor, replayedPromptDefaults) = switch (messagesResponse) {
        SuccessResponse(:final data) => (data.messages, data.nextCursor, data.replayedPromptDefaults),
        ErrorResponse(:final error) => throw error,
      };
      final promptDefaults = replayedPromptDefaults ?? session?.promptDefaults;

      final pendingQuestions = switch (questionsResponse) {
        SuccessResponse(:final data) => data.data,
        ErrorResponse(:final error) => () {
          logw("Failed to load pending questions; treating the session as having none", error);
          return <PendingQuestion>[];
        }(),
      };
      final pendingPermissions = switch (permissionsResponse) {
        SuccessResponse(:final data) => data.data,
        ErrorResponse(:final error) => () {
          logw("Failed to load pending permissions; treating the session as having none", error);
          return <PendingPermission>[];
        }(),
      };
      // An error is also the old-bridge (unknown route) path: no queue info.
      final bridgeQueuedPrompts = switch (queuedPromptsResponse) {
        SuccessResponse(:final data) => data.data,
        ErrorResponse() => <QueuedSessionPrompt>[],
      };
      final childSessions = switch (childrenResponse) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse(:final error) => () {
          logw("Failed to load child sessions; treating the session as having none", error);
          return <Session>[];
        }(),
      };
      final statuses = switch (statusesResponse) {
        SuccessResponse(:final data) => data.statuses,
        ErrorResponse(:final error) => () {
          logw("Failed to load session statuses; falling back to none", error);
          return <String, SessionStatus>{};
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
          bridgeQueuedPrompts: bridgeQueuedPrompts,
          childSessions: childSessions,
          statuses: statuses,
          agents: options.agents,
          providerData: options.providerData,
          commands: options.commands,
          canonicalSessionTitle: session?.title ?? fallbackContext?.sessionTitle,
          promptDefaults: promptDefaults,
          isRootSession: session != null ? session.parentID == null : null,
          isArchived: isArchived,
        ),
      );
    } on Object catch (error, stackTrace) {
      return SessionDetailLoadResult.failed(error: error, stackTrace: stackTrace);
    }
  }

  Future<_SessionDetailOptionsResult> _loadSessionOptions({
    required String? projectId,
    required String? pluginId,
    required bool requireComplete,
  }) async {
    final normalizedProjectId = projectId?.normalize();
    if (normalizedProjectId == null || pluginId == null) {
      return const _SessionDetailOptionsAvailable(
        options: (
          agents: <AgentInfo>[],
          providerData: ProviderListResponse(items: <ProviderInfo>[], connectedOnly: false),
          commands: <CommandInfo>[],
        ),
      );
    }

    _SessionDetailOptionsResult fromCatalog(SessionOptionsCatalog catalog) => _SessionDetailOptionsAvailable(
      options: (
        agents: catalog.agents,
        providerData: ProviderListResponse(
          items: catalog.providers,
          connectedOnly: catalog.providersConnectedOnly,
        ),
        commands: catalog.commands,
      ),
    );
    const unavailable = _SessionDetailOptionsAvailable(
      options: (
        agents: <AgentInfo>[],
        providerData: null,
        commands: <CommandInfo>[],
      ),
    );

    final result = await _repository.loadSessionOptions(
      projectId: normalizedProjectId,
      pluginId: pluginId,
      mode: SessionOptionsRequestMode.dynamic,
    );
    switch (result) {
      case SessionOptionsRepositoryAvailable(:final catalog):
        return fromCatalog(catalog);
      case SessionOptionsRepositoryUnsupported():
        // COMPATIBILITY 2026-08-09 (v1.8.0): Published older bridges do not
        // expose /session/options. Remove this fallback with support for them.
        switch (await _repository.loadLegacySessionOptions(projectId: normalizedProjectId, pluginId: pluginId)) {
          case LegacySessionOptionsRepositoryAvailable(:final catalog):
            return fromCatalog(catalog);
          case LegacySessionOptionsRepositoryPartial(:final catalog, :final errors):
            if (requireComplete) {
              return _SessionDetailOptionsFailure(
                error: _LegacySessionOptionsLoadError(errors: errors),
                stackTrace: StackTrace.current,
              );
            }
            for (final failure in errors) {
              loge("Failed to load legacy ${failure.source.name}", failure.error);
            }
            return fromCatalog(catalog);
          case LegacySessionOptionsRepositoryFailure(:final errors):
            if (requireComplete) {
              return _SessionDetailOptionsFailure(
                error: _LegacySessionOptionsLoadError(errors: errors),
                stackTrace: StackTrace.current,
              );
            }
            for (final failure in errors) {
              loge("Failed to load legacy ${failure.source.name}", failure.error);
            }
            return unavailable;
        }
      case SessionOptionsRepositoryProjectNotFound(:final error) || SessionOptionsRepositoryFailure(:final error):
        if (requireComplete) return _SessionDetailOptionsFailure(error: error, stackTrace: StackTrace.current);
        loge("Failed to load session options", error);
        return unavailable;
      case SessionOptionsRepositoryCacheUnavailable():
        if (requireComplete) {
          return _SessionDetailOptionsFailure(
            error: StateError("Session options cache is unavailable"),
            stackTrace: StackTrace.current,
          );
        }
        return unavailable;
      case SessionOptionsRepositoryRefreshFailedRetained():
        if (requireComplete) {
          return _SessionDetailOptionsFailure(
            error: StateError("Session options refresh failed"),
            stackTrace: StackTrace.current,
          );
        }
        logw("Failed to refresh session options; cached options were retained");
        return unavailable;
      case SessionOptionsRepositoryRefreshFailedUnavailable():
        if (requireComplete) {
          return _SessionDetailOptionsFailure(
            error: StateError("Session options refresh failed with no cached options"),
            stackTrace: StackTrace.current,
          );
        }
        logw("Failed to refresh session options and no cached options are available");
        return unavailable;
    }
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

class const SessionDetailSnapshot({
  required final String? projectId,

  /// The harness running this session, or `null` when neither the session nor
  /// the project fallback resolved it.
  required final String? pluginId,

  /// Whether the session's plugin explicitly declares inline attachment
  /// support, or `null` when plugin metadata could not be resolved.
  required final bool? supportsPromptAttachments,
  required final List<MessageWithParts> messages,

  /// Cursor for the page before [messages], or null when the transcript is
  /// complete — either because it all fits, or because the bridge predates
  /// pagination and always sends everything.
  required final int? olderMessagesCursor,
  required final List<PendingQuestion> pendingQuestions,
  required final List<QueuedSessionPrompt> bridgeQueuedPrompts,
  required final List<PendingPermission> pendingPermissions,
  required final List<Session> childSessions,
  required final Map<String, SessionStatus> statuses,
  required final List<AgentInfo> agents,
  required final ProviderListResponse? providerData,
  required final List<CommandInfo> commands,
  required final String? canonicalSessionTitle,
  required final SessionPromptDefaults? promptDefaults,

  /// Whether this session is a root (main) session. `true` when the session
  /// metadata confirms `parentID == null`; `false` when `parentID != null`;
  /// `null` when the session metadata lookup failed, so we cannot tell.
  required final bool? isRootSession,
  required final bool isArchived,
});

/// One page of history plus the cursor for the page before it.
typedef SessionMessagePage = ({List<MessageWithParts> messages, int? olderMessagesCursor});

typedef _SessionDetailOptions = ({
  List<AgentInfo> agents,
  ProviderListResponse? providerData,
  List<CommandInfo> commands,
});

sealed class const _SessionDetailOptionsResult();

final class const _SessionDetailOptionsAvailable({required final _SessionDetailOptions options})
    extends _SessionDetailOptionsResult;

final class const _SessionDetailOptionsFailure({required final Object error, required final StackTrace stackTrace})
    extends _SessionDetailOptionsResult;

final class _LegacySessionOptionsLoadError({required List<LegacySessionOptionError> errors}) implements Exception {
  final List<LegacySessionOptionError> errors = List.unmodifiable(errors);

  @override
  String toString() => errors.map((failure) => "${failure.source.name}: ${failure.error.toString()}").join("; ");
}

sealed class const SessionDetailLoadResult() {
  const factory loaded({
    required SessionDetailSnapshot snapshot,
  }) = SessionDetailLoadResultLoaded;

  const factory waitingForConnection() = SessionDetailLoadResultWaitingForConnection;

  const factory failed({
    // ignore: no_slop_linter/prefer_specific_type
    required Object error,
    required StackTrace? stackTrace,
  }) = SessionDetailLoadResultFailed;
}

final class const SessionDetailLoadResultLoaded({
  required final SessionDetailSnapshot snapshot,
}) extends SessionDetailLoadResult;

final class const SessionDetailLoadResultWaitingForConnection() extends SessionDetailLoadResult;

final class const SessionDetailLoadResultFailed({required final Object error, required final StackTrace? stackTrace})
    extends SessionDetailLoadResult {
  // ignore: no_slop_linter/prefer_specific_type
}
