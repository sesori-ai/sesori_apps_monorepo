import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/daos/session_options_cache_dao.dart";
import "../../api/database/database.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/plugin_agent_mapper.dart";
import "mappers/plugin_command_mapper.dart";
import "mappers/plugin_provider_mapper.dart";
import "models/session_options_cache_key.dart";

enum SessionOptionsCaptureActivation { mayActivate, activeOnly }

enum SessionOptionsRuntimeOperation { capture, commit }

class SessionOptionsCacheEntry {
  const SessionOptionsCacheEntry({
    required this.key,
    required this.revision,
    required this.capturedAt,
    required this.completeness,
    required this.response,
  });

  final SessionOptionsCacheKey key;
  final int revision;
  final DateTime capturedAt;
  final PluginSessionOptionsCompleteness completeness;
  final SessionOptionsResponse response;
}

sealed class SessionOptionsCaptureResult {
  const SessionOptionsCaptureResult();
}

final class SessionOptionsCaptureObserved extends SessionOptionsCaptureResult {
  const SessionOptionsCaptureObserved({
    required this.response,
    required this.completeness,
    required this.generation,
  });

  final SessionOptionsResponse response;
  final PluginSessionOptionsCompleteness completeness;
  final int generation;
}

final class SessionOptionsCaptureFailed extends SessionOptionsCaptureResult {
  const SessionOptionsCaptureFailed();
}

final class SessionOptionsCaptureInactive extends SessionOptionsCaptureResult {
  const SessionOptionsCaptureInactive();
}

final class SessionOptionsCacheDecodingException implements Exception {
  const SessionOptionsCacheDecodingException({
    required this.cause,
    required this.causeStackTrace,
  });

  final Object cause;
  final StackTrace causeStackTrace;

  @override
  String toString() => "SessionOptionsCacheDecodingException: invalid persisted session options cache";
}

class SessionOptionsRepository {
  SessionOptionsRepository({
    required PluginRuntime runtime,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionOptionsCacheDao cacheDao,
  }) : _runtime = runtime,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _cacheDao = cacheDao;

  final PluginRuntime _runtime;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final SessionOptionsCacheDao _cacheDao;

  Future<String?> resolveProjectPath({required String projectId}) {
    return _projectsDao.getResolvedPath(projectId: projectId);
  }

  Future<String?> resolveProjectIdForBackendSession({
    required String pluginId,
    required String backendSessionId,
  }) async {
    final session = await _sessionDao.getSessionByBinding(
      pluginId: pluginId,
      backendSessionId: backendSessionId,
    );
    return session?.projectId;
  }

  bool isPluginActive({required String pluginId}) => _runtime.activePluginIds.contains(pluginId);

  bool isCurrentGeneration({required String pluginId, required int generation}) {
    return _runtime.isCurrentGeneration(pluginId: pluginId, generation: generation);
  }

  Future<SessionOptionsCacheEntry?> read({required SessionOptionsCacheKey key}) async {
    final row = await _cacheDao.getRow(
      pluginId: key.pluginId,
      scope: key.scope,
      ownerId: key.ownerId,
    );
    if (row == null) return null;

    try {
      return _entryFromRow(row);
    } on Object catch (error, stackTrace) {
      throw SessionOptionsCacheDecodingException(cause: error, causeStackTrace: stackTrace);
    }
  }

  Future<void> delete({required SessionOptionsCacheKey key}) {
    return _cacheDao.deleteRow(
      pluginId: key.pluginId,
      scope: key.scope,
      ownerId: key.ownerId,
    );
  }

  Future<SessionOptionsCaptureResult> capture({
    required SessionOptionsCacheKey key,
    required String projectPath,
    required SessionOptionsCaptureActivation activation,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
    required int? expectedGeneration,
  }) async {
    if (key is ProjectSessionOptionsCacheKey && key.projectPath != projectPath) {
      throw ArgumentError.value(projectPath, "projectPath", "must match the project cache key path");
    }
    switch (activation) {
      case SessionOptionsCaptureActivation.mayActivate:
        final captured = await _runtime.useWithGeneration(
          pluginId: key.pluginId,
          operation: SessionOptionsRuntimeOperation.capture,
          body: (plugin) => plugin.getSessionOptions(
            projectId: projectPath,
            discoveryMode: discoveryMode,
          ),
        );
        return _mapCapture(result: captured.value, generation: captured.generation);
      case SessionOptionsCaptureActivation.activeOnly:
        final captured = await _runtime.useIfActive<_ActiveCapture>(
          pluginId: key.pluginId,
          operation: SessionOptionsRuntimeOperation.capture,
          body: (plugin, generation) async {
            if (expectedGeneration != null && generation != expectedGeneration) {
              return const _ActiveCaptureInactive();
            }
            final result = await plugin.getSessionOptions(
              projectId: projectPath,
              discoveryMode: discoveryMode,
            );
            return _ActiveCaptureResult(result: result, generation: generation);
          },
        );
        return switch (captured) {
          null || _ActiveCaptureInactive() => const SessionOptionsCaptureInactive(),
          _ActiveCaptureResult(:final result, :final generation) => _mapCapture(
            result: result,
            generation: generation,
          ),
        };
    }
  }

  Future<bool> commit({
    required SessionOptionsCacheEntry candidate,
    required int? expectedRevision,
    required int generation,
  }) {
    return _runtime.commitCurrentGeneration(
      pluginId: candidate.key.pluginId,
      generation: generation,
      operation: SessionOptionsRuntimeOperation.commit,
      commit: () => _cacheDao.compareAndSet(
        row: _rowFromEntry(candidate),
        expectedRevision: expectedRevision,
      ),
    );
  }

  SessionOptionsCaptureResult _mapCapture({
    required PluginSessionOptionsDiscoveryResult result,
    required int generation,
  }) {
    return switch (result) {
      PluginSessionOptionsDiscoveryFailed() => const SessionOptionsCaptureFailed(),
      PluginSessionOptionsDiscoveryObserved(:final options) => SessionOptionsCaptureObserved(
        response: SessionOptionsResponse(
          agents: Agents(
            agents: options.agents.map((agent) => agent.toAgentInfo()).toList(growable: false),
          ),
          providers: ProviderListResponse(
            items: options.providers.providers
                .map((provider) => provider.toSharedProviderInfo())
                .toList(growable: false),
            connectedOnly: true,
          ),
          commands: CommandListResponse(
            items: options.commands.map((command) => command.toSharedCommandInfo()).toList(growable: false),
          ),
        ),
        completeness: options.completeness,
        generation: generation,
      ),
    };
  }

  SessionOptionsCacheEntry _entryFromRow(SessionOptionsCacheTableData row) {
    final key = switch (row.scope) {
      PluginSessionOptionsScope.plugin
          when row.ownerId == row.pluginId && row.projectId == null && row.capturedProjectPath == null =>
        SessionOptionsCacheKey.plugin(pluginId: row.pluginId),
      PluginSessionOptionsScope.project
          when row.projectId != null &&
              row.ownerId == row.projectId &&
              row.capturedProjectPath != null &&
              row.capturedProjectPath!.isNotEmpty =>
        SessionOptionsCacheKey.project(
          pluginId: row.pluginId,
          projectId: row.projectId!,
          projectPath: row.capturedProjectPath!,
        ),
      _ => throw const FormatException("invalid session options cache identity"),
    };
    return SessionOptionsCacheEntry(
      key: key,
      revision: row.revision,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(row.capturedAt, isUtc: true),
      completeness: row.completeness,
      response: SessionOptionsResponse(
        agents: Agents.fromJson(jsonDecodeMap(row.agentsJson)),
        providers: ProviderListResponse.fromJson(jsonDecodeMap(row.providersJson)),
        commands: CommandListResponse.fromJson(jsonDecodeMap(row.commandsJson)),
      ),
    );
  }

  SessionOptionsCacheTableData _rowFromEntry(SessionOptionsCacheEntry entry) {
    final (projectId, capturedProjectPath) = switch (entry.key) {
      PluginSessionOptionsCacheKey() => (null, null),
      ProjectSessionOptionsCacheKey(:final projectId, :final projectPath) => (projectId, projectPath),
    };
    return SessionOptionsCacheTableData(
      pluginId: entry.key.pluginId,
      scope: entry.key.scope,
      ownerId: entry.key.ownerId,
      projectId: projectId,
      capturedProjectPath: capturedProjectPath,
      revision: entry.revision,
      capturedAt: entry.capturedAt.millisecondsSinceEpoch,
      completeness: entry.completeness,
      agentsJson: jsonEncode(entry.response.agents.toJson()),
      providersJson: jsonEncode(entry.response.providers.toJson()),
      commandsJson: jsonEncode(entry.response.commands.toJson()),
    );
  }
}

sealed class _ActiveCapture {
  const _ActiveCapture();
}

final class _ActiveCaptureResult extends _ActiveCapture {
  const _ActiveCaptureResult({required this.result, required this.generation});

  final PluginSessionOptionsDiscoveryResult result;
  final int generation;
}

final class _ActiveCaptureInactive extends _ActiveCapture {
  const _ActiveCaptureInactive();
}
