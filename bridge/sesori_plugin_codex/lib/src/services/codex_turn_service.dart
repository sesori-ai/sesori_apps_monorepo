import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/codex_app_server_repository.dart";
import "../repositories/codex_message_repository.dart";
import "../repositories/models/codex_app_server_repository_models.dart";
import "../trackers/codex_command_invocation_tracker.dart";
import "../trackers/codex_context_tracker.dart";
import "../trackers/codex_thread_residency_tracker.dart";

/// Coordinates app-server intentions, turn residency, and live turn status.
class CodexTurnService {
  CodexTurnService({
    required CodexAppServerRepository repository,
    required CodexContextTracker contextTracker,
    required CodexCommandInvocationTracker commandTracker,
    required CodexThreadResidencyTracker residencyTracker,
    required CodexMessageRepository messageRepository,
    required String launchDirectory,
  }) : _repository = repository,
       _contextTracker = contextTracker,
       _commandTracker = commandTracker,
       _residencyTracker = residencyTracker,
       _messageRepository = messageRepository,
       _launchDirectory = normalizeProjectDirectory(
         directory: launchDirectory,
       );

  final CodexAppServerRepository _repository;
  final CodexContextTracker _contextTracker;
  final CodexCommandInvocationTracker _commandTracker;
  final CodexThreadResidencyTracker _residencyTracker;
  final CodexMessageRepository _messageRepository;
  final String _launchDirectory;
  final Map<String, String> _activeTurnByThread = {};
  final Map<String, PluginSessionStatus> _statuses = {};

  Map<String, PluginSessionStatus> get statuses => Map.unmodifiable(_statuses);

  bool hasActiveTurn({required String threadId}) => _activeTurnByThread.containsKey(threadId);

  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required CodexModelSelection? model,
  }) async {
    final thread = await _repository.startThread(
      directory: directory,
      model: model,
    );
    _residencyTracker.recordLoaded(threadId: thread.id);
    _contextTracker.recordFacts(thread.context);
    _statuses[thread.id] = const PluginSessionStatus.idle();
    if (parts.isNotEmpty) {
      await sendPrompt(
        sessionId: thread.id,
        parts: parts,
        variant: variant,
        model: model,
      );
    }
    final resolvedDirectory = thread.directory ?? normalizeProjectDirectory(directory: directory);
    final created = thread.createdAtSeconds;
    final updated = thread.updatedAtSeconds;
    return PluginSession(
      id: thread.id,
      projectID: resolvedDirectory,
      directory: resolvedDirectory,
      parentID: parentSessionId,
      title: thread.title,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: (created * 1000).round(),
              updated: (updated * 1000).round(),
              archived: null,
            ),
    );
  }

  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required CodexModelSelection? model,
  }) async {
    final input = parts.map(_toUserInput).whereType<CodexTurnInput>().toList(growable: false);
    if (input.isEmpty) return;
    _applyModelContext(threadId: sessionId, model: model);
    final turn = await _startTurn(
      threadId: sessionId,
      input: input,
      model: model,
      effort: variant?.id,
    );
    _activeTurnByThread[sessionId] = turn.id;
    _statuses[sessionId] = const PluginSessionStatus.busy();
  }

  Future<CodexCommandAcceptance> sendCommand({
    required String sessionId,
    required String invocationId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required CodexModelSelection? model,
  }) async {
    _commandTracker.register(
      threadId: sessionId,
      invocationId: invocationId,
      command: command,
      arguments: arguments,
    );
    final normalizedCommand = command.startsWith("/") ? command.substring(1) : command;
    final body = arguments.isEmpty ? "/$normalizedCommand" : "/$normalizedCommand $arguments";
    try {
      _applyModelContext(threadId: sessionId, model: model);
      final turn = await _startTurn(
        threadId: sessionId,
        input: [CodexTurnTextInput(text: body)],
        model: model,
        effort: variant?.id,
      );
      _activeTurnByThread[sessionId] = turn.id;
      _statuses[sessionId] = const PluginSessionStatus.busy();
      return CodexCommandAcceptance(
        dispatch: const PluginCommandDispatch(backendMessageId: null),
        invocation: _commandTracker.bindTurn(
          threadId: sessionId,
          turnId: turn.id,
        ),
      );
    } catch (_) {
      _commandTracker.reject(
        threadId: sessionId,
        invocationId: invocationId,
      );
      rethrow;
    }
  }

  Future<void> abort({required String sessionId}) async {
    final turnId = _activeTurnByThread[sessionId];
    if (turnId == null) return;
    try {
      await _repository.interrupt(threadId: sessionId, turnId: turnId);
    } on CodexTurnAlreadyStoppedException {
      // The turn is already idle, which is the requested outcome.
    } finally {
      _activeTurnByThread.remove(sessionId);
      _statuses[sessionId] = const PluginSessionStatus.idle();
    }
  }

  Future<void> renameThread({
    required String threadId,
    required String name,
  }) => _repository.setThreadName(threadId: threadId, name: name);

  Future<void> archiveThread({required String threadId}) => _repository.archiveThread(threadId: threadId);

  Future<List<CodexModelRecord>> listModels() async {
    try {
      return await _repository.listModels();
    } on Object {
      return const [];
    }
  }

  Future<void> sendKeepalive({required Duration timeout}) => _repository.sendKeepalive(timeout: timeout);

  void observe(CodexEventRecord event) {
    final threadId = event.threadId;
    switch (event) {
      case CodexThreadStartedEventRecord():
        if (threadId == null) return;
        _residencyTracker.recordLoaded(threadId: threadId);
        _statuses[threadId] = const PluginSessionStatus.idle();
      case CodexTurnStartedEventRecord():
        if (threadId == null) return;
        final turnId = event.turnId;
        if (turnId != null) _activeTurnByThread[threadId] = turnId;
        _statuses[threadId] = const PluginSessionStatus.busy();
      case CodexTurnCompletedEventRecord():
      case CodexErrorEventRecord():
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        _statuses[threadId] = const PluginSessionStatus.idle();
      case CodexThreadClosedEventRecord():
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        _statuses.remove(threadId);
        _residencyTracker.recordUnloaded(threadId: threadId);
        _commandTracker.forgetThread(threadId: threadId);
      case CodexThreadNameUpdatedEventRecord():
      case CodexThreadStatusChangedEventRecord():
      case CodexItemEventRecord():
      case CodexAgentMessageDeltaEventRecord():
      case CodexReasoningDeltaEventRecord():
      case CodexItemRemovedEventRecord():
      case CodexItemPartRemovedEventRecord():
      case CodexTurnDiffUpdatedEventRecord():
      case CodexProjectChangedEventRecord():
      case CodexIgnoredEventRecord():
        break;
    }
  }

  void forgetThread({required String threadId}) {
    _activeTurnByThread.remove(threadId);
    _statuses.remove(threadId);
    _residencyTracker.recordUnloaded(threadId: threadId);
    _commandTracker.forgetThread(threadId: threadId);
  }

  Future<CodexStartedTurn> _startTurn({
    required String threadId,
    required List<CodexTurnInput> input,
    required CodexModelSelection? model,
    required String? effort,
  }) async {
    await _ensureThreadLoaded(threadId: threadId);
    try {
      return await _repository.startTurn(
        threadId: threadId,
        input: input,
        model: model,
        effort: effort,
      );
    } on CodexThreadNotFoundException {
      _residencyTracker.recordUnloaded(threadId: threadId);
      await _resumeThread(threadId: threadId);
      return _repository.startTurn(
        threadId: threadId,
        input: input,
        model: model,
        effort: effort,
      );
    }
  }

  Future<void> _ensureThreadLoaded({required String threadId}) async {
    if (_residencyTracker.isLoaded(threadId: threadId)) return;
    await _resumeThread(threadId: threadId);
  }

  Future<void> _resumeThread({required String threadId}) async {
    final facts = await _repository.resumeThread(threadId: threadId);
    final resolvedFacts = CodexThreadContextFacts(
      threadId: threadId,
      model: facts.model,
      provider: facts.provider,
      directory:
          facts.directory ?? _contextTracker.knownDirectory(threadId: threadId) ?? _persistedDirectoryFor(threadId),
    );
    _residencyTracker.recordLoaded(threadId: threadId);
    _contextTracker.recordFacts(resolvedFacts);
  }

  String _persistedDirectoryFor(String threadId) => normalizeProjectDirectory(
    directory: _messageRepository.findPersistedDirectory(sessionId: threadId) ?? _launchDirectory,
  );

  void _applyModelContext({
    required String threadId,
    required CodexModelSelection? model,
  }) {
    if (model == null) return;
    _contextTracker.setModel(threadId: threadId, model: model.modelId);
  }

  static CodexTurnInput? _toUserInput(PluginPromptPart part) {
    return switch (part) {
      PluginPromptPartText(:final text) => CodexTurnTextInput(text: text),
      PluginPromptPartFilePath(:final path) => CodexTurnLocalImageInput(path: path),
      PluginPromptPartFileUrl(:final url) => CodexTurnImageUrlInput(url: url),
      PluginPromptPartFileData() => null,
    };
  }
}

class CodexCommandAcceptance {
  const CodexCommandAcceptance({
    required this.dispatch,
    required this.invocation,
  });

  final PluginCommandDispatch dispatch;
  final CodexCommandInvocationSnapshot? invocation;
}
