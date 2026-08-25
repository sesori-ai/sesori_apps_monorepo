import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginOperationException, PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_metadata_repository.dart";
import "../repositories/session_repository.dart";
import "session_mutation_dispatcher.dart";
import "session_prompt_service.dart";
import "worktree_service.dart";

class SessionCreationService({
  required final SessionMetadataRepository _sessionMetadataRepository,
  required final WorktreeService _worktreeService,
  required final SessionRepository _sessionRepository,
  required final SessionMutationDispatcher _sessionMutationDispatcher,
}) {
  final PendingOperations _lateMetadataWork = PendingOperations();
  bool _acceptingLateMetadata = true;
  Future<void>? _drainFuture;

  Future<Session> createSession({required CreateSessionRequest request}) async {
    // Validate the opaque project handle before any plugin/git side effect.
    // The stored path is authoritative; unknown ids are not directories.
    final projectDirectory = await _sessionRepository.resolveProjectDirectory(projectId: request.projectId);
    final normalizedCommand = request.command?.normalize();
    final agentModel = request.model;
    final userTexts = _extractTexts(parts: request.parts);
    final firstText = userTexts.firstOrNull;
    final userVisibleText = userTexts.isEmpty ? null : userTexts.join("\n\n");
    await _sessionRepository.ensurePluginRoutable(
      pluginId: request.pluginId,
      operation: SessionOperation.createSession,
    );
    final worktreeResult = await _prepareWorktree(request: request);
    final worktreeState = await _resolveWorktreeState(
      projectId: request.projectId,
      projectDirectory: projectDirectory,
      worktreeResult: worktreeResult,
    );
    final created = await _sessionRepository.createSession(
      pluginId: request.pluginId,
      projectId: request.projectId,
      directory: worktreeState.directory,
      parentSessionId: null,
      parts: _buildPromptParts(
        parts: request.parts,
        worktreeResult: worktreeResult,
        command: normalizedCommand,
      ),
      userVisibleText: normalizedCommand == null ? userVisibleText : null,
      variant: request.variant,
      agent: normalizedCommand == null || normalizedCommand.isEmpty ? request.agent : null,
      model: normalizedCommand == null || normalizedCommand.isEmpty ? request.model : null,
      isDedicated: worktreeState.isDedicated,
      worktreePath: worktreeState.worktreePath,
      branchName: worktreeState.branchName,
      baseBranch: worktreeState.baseBranch,
      baseCommit: worktreeState.baseCommit,
      lastAgent: request.agent,
      lastAgentModel: agentModel != null
          ? AgentModel(
              providerID: agentModel.providerID,
              modelID: agentModel.modelID,
              variant: request.variant?.id,
            )
          : null,
    );
    await _maybeSendCommand(
      session: created,
      command: normalizedCommand,
      arguments: _buildCommandArguments(
        userArguments: firstText ?? '',
        worktreeResult: worktreeResult,
      ),
      userVisibleArguments: firstText,
      variant: request.variant,
      agent: request.agent,
      model: request.model,
    );
    _startLateMetadata(session: created, firstText: firstText);
    return created;
  }

  void beginShutdown() {
    if (!_acceptingLateMetadata) return;
    _acceptingLateMetadata = false;
    _sessionMetadataRepository.beginShutdown();
  }

  Future<void> drain() => _drainFuture ??= _drain();

  List<String> _extractTexts({required List<PromptPart> parts}) {
    return parts
        .whereType<PromptPartText>()
        .map((part) => part.text)
        .where((text) => text.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<WorktreeResult?> _prepareWorktree({
    required CreateSessionRequest request,
  }) async {
    if (!request.dedicatedWorktree) {
      return null;
    }
    return await _worktreeService.prepareWorktreeForSession(
      projectId: request.projectId,
      parentSessionId: null,
    );
  }

  List<PromptPart> _buildPromptParts({
    required List<PromptPart> parts,
    required WorktreeResult? worktreeResult,
    required String? command,
  }) {
    if (command != null) {
      return const [];
    }
    final includeUserParts = command == null;
    if (parts.isEmpty && includeUserParts) {
      return parts;
    }
    if (worktreeResult case WorktreeSuccess(:final path, :final branchName, :final baseBranch)) {
      final promptParts = <PromptPart>[
        PromptPart.text(
          text: _buildWorktreeSystemPrompt(
            branchName: branchName,
            worktreePath: path,
            baseBranch: baseBranch,
          ),
        ),
      ];
      if (includeUserParts) {
        promptParts.addAll(parts);
      }
      return promptParts;
    }
    if (!includeUserParts) {
      return const [];
    }
    return parts;
  }

  Future<void> _maybeSendCommand({
    required Session session,
    required String? command,
    required String arguments,
    required String? userVisibleArguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    if (command == null) {
      return;
    }
    try {
      await _sessionRepository.sendCommand(
        sessionId: session.id,
        promptId: SessionPromptService.generatePromptId(),
        command: command,
        arguments: arguments,
        userVisibleArguments: userVisibleArguments,
        variant: variant,
        agent: agent,
        model: model,
      );
    } on PluginStaleOptionsException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          SessionOperation.createSession.name,
          statusCode: 400,
          message: error.message,
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  String _buildCommandArguments({
    required String userArguments,
    required WorktreeResult? worktreeResult,
  }) {
    if (worktreeResult case WorktreeSuccess(:final path, :final branchName, :final baseBranch)) {
      final systemContext = _buildWorktreeSystemPrompt(
        branchName: branchName,
        worktreePath: path,
        baseBranch: baseBranch,
      ).trimRight();
      final trimmedArguments = userArguments.trim();
      if (trimmedArguments.isEmpty) {
        return systemContext;
      }
      return "$systemContext\n\n$trimmedArguments";
    }
    return userArguments;
  }

  Future<_SessionCreationWorktreeState> _resolveWorktreeState({
    required String projectId,
    required String projectDirectory,
    required WorktreeResult? worktreeResult,
  }) async {
    final String directory;
    switch (worktreeResult) {
      case WorktreeSuccess(
        :final path,
        branchName: final resolvedBranchName,
        baseBranch: final resolvedBaseBranch,
        baseCommit: final resolvedBaseCommit,
      ):
        return _DedicatedSessionCreationWorktreeState(
          path: path,
          branchName: resolvedBranchName,
          baseBranch: resolvedBaseBranch,
          baseCommit: resolvedBaseCommit,
        );
      case WorktreeFallback(:final originalPath):
        directory = originalPath;
      case null:
        directory = projectDirectory;
    }
    final startCommit = await _worktreeService.resolveHeadCommit(projectId: projectId);
    // In-place sessions have no branch baseline. The immutable HEAD commit is
    // their exact comparison point even when local changes already exist.
    return _InPlaceSessionCreationWorktreeState(
      directory: directory,
      baseCommit: startCommit,
    );
  }

  String _buildWorktreeSystemPrompt({
    required String branchName,
    required String worktreePath,
    required String baseBranch,
  }) {
    return '''
[SYSTEM CONTEXT — IMPORTANT]
A dedicated git worktree and branch have been created for this session:
- Branch: $branchName
- Worktree path: $worktreePath
- Based on: $baseBranch

IMPORTANT: Perform all work for this task in this dedicated worktree. You may use the initial branch above, or switch branches or create additional branches here as needed. Do NOT create another worktree or working directory — even if other instructions suggest it.

---
''';
  }

  void _startLateMetadata({required Session session, required String? firstText}) {
    if (!_acceptingLateMetadata || firstText == null) return;
    unawaited(
      _lateMetadataWork.track(
        operation: _generateAndApplyMetadata(session: session, firstText: firstText),
      ),
    );
  }

  Future<void> _generateAndApplyMetadata({required Session session, required String firstText}) async {
    final GeneratedSessionMetadata metadata;
    try {
      metadata = await _sessionMetadataRepository.generateMetadata(
        firstMessage: firstText,
      );
    } on SessionMetadataRequestAbortedException catch (error) {
      if (!_acceptingLateMetadata) return;
      Log.w(
        "Generated-metadata request was aborted for session ${session.id}",
        error.innerError,
        error.innerStackTrace,
      );
      return;
    } on SessionMetadataInvalidResponseException catch (error) {
      Log.w(
        "Failed to generate metadata for session ${session.id}",
        error.innerError,
        error.innerStackTrace,
      );
      return;
    } on Object catch (error, stackTrace) {
      Log.w("Failed to generate metadata for session ${session.id}", error, stackTrace);
      return;
    }

    try {
      await _sessionMutationDispatcher.applyGeneratedTitle(
        sessionId: session.id,
        title: metadata.title,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Failed to apply generated title for session ${session.id}", error, stackTrace);
    }
    try {
      await _sessionMutationDispatcher.applyGeneratedBranchName(
        sessionId: session.id,
        branchName: metadata.branchName,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Failed to apply generated branch for session ${session.id}", error, stackTrace);
    }
  }

  Future<void> _drain() async {
    beginShutdown();
    await _lateMetadataWork.drain();
  }
}

sealed class _SessionCreationWorktreeState() {
  String get directory;
  bool get isDedicated;
  String? get worktreePath;
  String? get branchName;
  String? get baseBranch;
  String? get baseCommit;
}

class _DedicatedSessionCreationWorktreeState({
  required final String path,
  @override required final String branchName,
  @override required final String baseBranch,
  @override required final String baseCommit,
}) implements _SessionCreationWorktreeState {
  @override
  String get directory => path;

  @override
  bool get isDedicated => true;

  @override
  String get worktreePath => path;
}

class _InPlaceSessionCreationWorktreeState({
  @override required final String directory,
  @override required final String? baseCommit,
}) implements _SessionCreationWorktreeState {
  @override
  bool get isDedicated => false;

  @override
  String? get worktreePath => null;

  @override
  String? get branchName => null;

  @override
  String? get baseBranch => null;
}
