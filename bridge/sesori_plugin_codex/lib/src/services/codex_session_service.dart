import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../codex_metadata_repository.dart";
import "../repositories/codex_catalog_repository.dart";
import "../repositories/codex_message_repository.dart";
import "../repositories/codex_thread_repository.dart";
import "../repositories/models/codex_thread_record.dart";

/// Layer-3 coordination for the migrated Codex session operations.
class CodexSessionService {
  CodexSessionService({
    required CodexCatalogRepository catalogRepository,
    required CodexMessageRepository messageRepository,
    required CodexMetadataRepository metadataRepository,
    required String launchDirectory,
  }) : _catalogRepository = catalogRepository,
       _messageRepository = messageRepository,
       _metadataRepository = metadataRepository,
       _launchDirectory = launchDirectory;

  final CodexCatalogRepository _catalogRepository;
  final CodexMessageRepository _messageRepository;
  final CodexMetadataRepository _metadataRepository;
  final String _launchDirectory;

  CodexThreadRepository? _threadRepository;
  final Set<String> _loadedThreads = {};

  void attachThreadRepository({
    required CodexThreadRepository threadRepository,
  }) {
    _threadRepository = threadRepository;
  }

  void detachThreadRepository() {
    _threadRepository = null;
    _loadedThreads.clear();
  }

  Future<List<PluginSession>> listAllSessions() => _catalogRepository.listAllSessions();

  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) => _catalogRepository.getSessions(
    projectId: projectId,
    start: start,
    limit: limit,
  );

  List<PluginCommand> getCommands({required String? projectId}) =>
      _metadataRepository.getCommands(projectId: projectId);

  Future<CodexThreadRecord> startThread({
    required String cwd,
    required String? model,
    required String? modelProvider,
  }) async {
    final thread = await _connectedThreadRepository.startThread(
      cwd: cwd,
      model: model,
      modelProvider: modelProvider,
    );
    _loadedThreads.add(thread.id);
    return thread;
  }

  Future<CodexThreadRecord?> resumeThreadIfNeeded({
    required String threadId,
    required bool force,
  }) async {
    if (!force && _loadedThreads.contains(threadId)) return null;
    final thread = await _connectedThreadRepository.resumeThread(threadId: threadId);
    _loadedThreads.add(threadId);
    return thread;
  }

  CodexThreadRecord? decodeStartedNotificationParams({
    required Map<String, dynamic> params,
  }) => _threadRepository?.decodeStartedNotificationParams(params: params);

  PluginSession toPluginSession({
    required CodexThreadRecord thread,
    required String fallbackDirectory,
    required String? parentSessionId,
  }) => _connectedThreadRepository.toPluginSession(
    record: thread,
    fallbackDirectory: fallbackDirectory,
    parentSessionId: parentSessionId,
  );

  void markThreadUnloaded({required String threadId}) {
    _loadedThreads.remove(threadId);
  }

  String directoryForSession({required String sessionId}) {
    final record = _catalogRepository.findSessionById(sessionId: sessionId);
    return normalizeProjectDirectory(
      directory: record?.cwd ?? _launchDirectory,
    );
  }

  void deleteSession({required String sessionId}) {
    _catalogRepository.deleteSession(sessionId: sessionId);
    _loadedThreads.remove(sessionId);
  }

  Future<List<PluginMessageWithParts>> getSessionMessages({
    required String sessionId,
  }) async {
    final path = _catalogRepository.findRolloutPath(sessionId: sessionId);
    if (path == null) return const [];
    return _messageRepository.readMessages(
      rolloutPath: path,
      sessionId: sessionId,
      config: _metadataRepository.readConfigDefaults(),
    );
  }

  /// Resolves project defaults across the rollout catalog and Codex config.
  ({String? modelID, String providerID}) resolveModelDefaults({
    required String projectId,
  }) {
    final config = _metadataRepository.readConfigDefaults();
    final target = normalizeProjectDirectory(directory: projectId);
    for (final record in _catalogRepository.listSessionRecords()) {
      final directory = normalizeProjectDirectory(
        directory: record.cwd ?? _launchDirectory,
      );
      if (directory == target || p.isWithin(target, directory)) {
        return (
          modelID: record.model ?? config.model,
          providerID: record.modelProvider ?? config.modelProvider ?? "openai",
        );
      }
    }
    return (
      modelID: config.model,
      providerID: config.modelProvider ?? "openai",
    );
  }

  String? selectCatalogDefaultModel({
    required String? scopedModelID,
    required List<String> catalogModelIds,
    required String? catalogDefaultId,
  }) {
    if (scopedModelID != null && catalogModelIds.contains(scopedModelID)) {
      return scopedModelID;
    }
    if (catalogDefaultId != null) return catalogDefaultId;
    return catalogModelIds.isEmpty ? null : catalogModelIds.first;
  }

  CodexThreadRepository get _connectedThreadRepository {
    final repository = _threadRepository;
    if (repository == null) {
      throw StateError("codex app-server API is not connected");
    }
    return repository;
  }
}
