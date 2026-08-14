import "dart:async";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/session_metadata_repository.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "session_mutation_dispatcher.dart";
import "worktree_service.dart";

class SessionCreationService({
  required final SessionMetadataRepository _sessionMetadataRepository,
  required final WorktreeService _worktreeService,
  required final SessionRepository _sessionRepository,
  required final SessionMutationDispatcher _sessionMutationDispatcher,
}) {
  final Set<Future<void>> _lateTitleWork = <Future<void>>{};
  final Completer<void> _shutdownSignal = Completer<void>();
  bool _acceptingLateTitles = true;
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
      dedicatedWorktree: request.dedicatedWorktree,
      worktreeResult: worktreeResult,
    );
    final created = await _sessionRepository.createSession(
      pluginId: request.pluginId,
      projectId: request.projectId,
      directory: _resolveDirectory(projectDirectory: projectDirectory, worktreeResult: worktreeResult),
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
      isDedicated: request.dedicatedWorktree,
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
    _startLateTitle(session: created, firstText: firstText);
    return created;
  }

  void beginShutdown() {
    if (!_acceptingLateTitles) return;
    _acceptingLateTitles = false;
    _shutdownSignal.complete();
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

  /// The working directory the new session runs in: the dedicated worktree
  /// when one was created, otherwise the project's live directory. The
  /// request's projectId is the stable identifier — it may point where the
  /// folder used to be, so it is never used as a directory directly.
  String _resolveDirectory({
    required String projectDirectory,
    required WorktreeResult? worktreeResult,
  }) {
    return switch (worktreeResult) {
      WorktreeSuccess(:final path) => path,
      // The fallback carries the live project directory it fell back to.
      WorktreeFallback(:final originalPath) => originalPath,
      null => projectDirectory,
    };
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
    await _sessionRepository.sendCommand(
      sessionId: session.id,
      command: command,
      arguments: arguments,
      userVisibleArguments: userVisibleArguments,
      variant: variant,
      agent: agent,
      model: model,
    );
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

  Future<({String? worktreePath, String? branchName, String? baseBranch, String? baseCommit})> _resolveWorktreeState({
    required String projectId,
    required bool dedicatedWorktree,
    required WorktreeResult? worktreeResult,
  }) async {
    if (worktreeResult case WorktreeSuccess(
      :final path,
      branchName: final resolvedBranchName,
      baseBranch: final resolvedBaseBranch,
      baseCommit: final resolvedBaseCommit,
    )) {
      return (
        worktreePath: path,
        branchName: resolvedBranchName,
        baseBranch: resolvedBaseBranch,
        baseCommit: resolvedBaseCommit,
      );
    }
    if (dedicatedWorktree) {
      return (worktreePath: null, branchName: null, baseBranch: null, baseCommit: null);
    }
    final startCommit = await _worktreeService.resolveHeadCommit(projectId: projectId);
    // In-place sessions have no branch baseline. The immutable HEAD commit is
    // their exact comparison point even when local changes already exist.
    return (
      worktreePath: null,
      branchName: null,
      baseBranch: null,
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

  void _startLateTitle({required Session session, required String? firstText}) {
    if (!_acceptingLateTitles || firstText == null) return;
    late final Future<void> work;
    work = _generateAndApplyTitle(session: session, firstText: firstText).whenComplete(() {
      _lateTitleWork.remove(work);
    });
    _lateTitleWork.add(work);
  }

  Future<void> _generateAndApplyTitle({required Session session, required String firstText}) async {
    try {
      final title = await _sessionMetadataRepository.generateTitle(
        firstMessage: firstText,
        shutdownSignal: _shutdownSignal.future,
      );
      await _sessionMutationDispatcher.applyGeneratedTitle(sessionId: session.id, title: title);
    } on http.RequestAbortedException catch (error, stackTrace) {
      if (_shutdownSignal.isCompleted) return;
      Log.w("Generated-title request was aborted for session ${session.id}", error, stackTrace);
    } on Object catch (error, stackTrace) {
      Log.w("Failed to generate title for session ${session.id}", error, stackTrace);
    }
  }

  Future<void> _drain() async {
    beginShutdown();
    await Future.wait(_lateTitleWork.toList(growable: false));
  }
}
