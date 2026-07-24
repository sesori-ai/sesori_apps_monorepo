import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../codex_metadata_repository.dart";
import "../models/codex_collaboration_mode.dart";
import "../repositories/codex_catalog_repository.dart";
import "../repositories/codex_message_repository.dart";
import "../repositories/codex_skill_repository.dart";
import "../repositories/codex_thread_repository.dart";
import "../repositories/models/codex_thread_record.dart";

/// Layer-3 coordination for the migrated Codex session operations.
class CodexSessionService {
  static const String compactionCommandName = "compact";

  static const PluginCommand _compactionCommand = PluginCommand(
    name: compactionCommandName,
    description: "Summarize the conversation so far to free up the context window",
    provider: null,
    source: PluginCommandSource.command,
  );

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
  CodexSkillRepository? _skillRepository;
  final Set<String> _loadedThreads = {};
  final Map<String, String> _threadModels = {};

  void attachAppServerRepositories({
    required CodexThreadRepository threadRepository,
    required CodexSkillRepository skillRepository,
  }) {
    _threadRepository = threadRepository;
    _skillRepository = skillRepository;
  }

  void detachAppServerRepositories() {
    _threadRepository = null;
    _skillRepository = null;
    _loadedThreads.clear();
    _threadModels.clear();
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

  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    final target = normalizeProjectDirectory(directory: projectId ?? _launchDirectory);
    final List<PluginCommand> commands;
    try {
      commands = await _connectedSkillRepository.listCommands(cwd: target);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] skill discovery failed; exposing compact only",
        error,
        stackTrace,
      );
      return const [_compactionCommand];
    }
    if (commands.any((command) => command.name == compactionCommandName)) {
      return commands;
    }
    return [...commands, _compactionCommand];
  }

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
    _rememberThreadModel(threadId: thread.id, model: thread.model ?? model);
    return thread;
  }

  Future<CodexThreadRecord?> resumeThreadIfNeeded({
    required String threadId,
    required bool force,
  }) async {
    if (!force && _loadedThreads.contains(threadId)) return null;
    final thread = await _connectedThreadRepository.resumeThread(threadId: threadId);
    _loadedThreads.add(threadId);
    _rememberThreadModel(threadId: threadId, model: thread.model);
    return thread;
  }

  Future<({CodexThreadRecord? resumedThread, String? resolvedModel, bool started})> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    var resumed = await resumeThreadIfNeeded(threadId: threadId, force: false);
    var turnModel = _resolveTurnModel(
      threadId: threadId,
      requestedModel: model,
      collaborationMode: collaborationMode,
    );
    final turnEffort = effort ?? collaborationMode?.defaultReasoningEffort;
    try {
      final started = await _connectedThreadRepository.startTurn(
        threadId: threadId,
        parts: parts,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: collaborationMode,
      );
      if (started) {
        _rememberThreadModel(threadId: threadId, model: turnModel);
      }
      return (
        resumedThread: resumed,
        resolvedModel: turnModel,
        started: started,
      );
    } on CodexThreadNotFoundException {
      resumed = await resumeThreadIfNeeded(threadId: threadId, force: true);
      turnModel = _resolveTurnModel(
        threadId: threadId,
        requestedModel: model,
        collaborationMode: collaborationMode,
      );
      final started = await _connectedThreadRepository.startTurn(
        threadId: threadId,
        parts: parts,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: collaborationMode,
      );
      if (started) {
        _rememberThreadModel(threadId: threadId, model: turnModel);
      }
      return (
        resumedThread: resumed,
        resolvedModel: turnModel,
        started: started,
      );
    }
  }

  Future<({CodexThreadRecord? resumedThread, String? resolvedModel})> sendCommand({
    required String threadId,
    required String command,
    required String arguments,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    var resumed = await resumeThreadIfNeeded(threadId: threadId, force: false);
    var turnModel = _resolveTurnModel(
      threadId: threadId,
      requestedModel: model,
      collaborationMode: collaborationMode,
    );
    final turnEffort = effort ?? collaborationMode?.defaultReasoningEffort;
    try {
      await _dispatchCommand(
        threadId: threadId,
        command: command,
        arguments: arguments,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: collaborationMode,
      );
    } on CodexThreadNotFoundException {
      resumed = await resumeThreadIfNeeded(threadId: threadId, force: true);
      turnModel = _resolveTurnModel(
        threadId: threadId,
        requestedModel: model,
        collaborationMode: collaborationMode,
      );
      await _dispatchCommand(
        threadId: threadId,
        command: command,
        arguments: arguments,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: collaborationMode,
      );
    }
    if (command != compactionCommandName) {
      _rememberThreadModel(threadId: threadId, model: turnModel);
    }
    return (
      resumedThread: resumed,
      resolvedModel: command == compactionCommandName ? null : turnModel,
    );
  }

  Future<void> _dispatchCommand({
    required String threadId,
    required String command,
    required String arguments,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    if (command == compactionCommandName) {
      await _connectedThreadRepository.compactThread(threadId: threadId);
      return;
    }
    final invocation = arguments.isEmpty ? "\$$command" : "\$$command $arguments";
    await _connectedThreadRepository.startTurn(
      threadId: threadId,
      parts: [PluginPromptPart.text(text: invocation)],
      model: model,
      effort: effort,
      collaborationMode: collaborationMode,
    );
  }

  String? _resolveTurnModel({
    required String threadId,
    required String? requestedModel,
    required CodexCollaborationMode? collaborationMode,
  }) {
    if (requestedModel != null && requestedModel.isNotEmpty) {
      return requestedModel;
    }
    if (collaborationMode == null) return null;
    return _threadModels[threadId] ??
        _catalogRepository.findSessionById(sessionId: threadId)?.model ??
        _metadataRepository.readConfigDefaults().model;
  }

  void _rememberThreadModel({
    required String threadId,
    required String? model,
  }) {
    if (model != null && model.isNotEmpty) {
      _threadModels[threadId] = model;
    }
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
    _threadModels.remove(sessionId);
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

  CodexSkillRepository get _connectedSkillRepository {
    final repository = _skillRepository;
    if (repository == null) {
      throw StateError("codex app-server API is not connected");
    }
    return repository;
  }
}
