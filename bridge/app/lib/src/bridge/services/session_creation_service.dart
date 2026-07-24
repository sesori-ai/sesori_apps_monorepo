import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../metadata_service.dart";
import "../models/session_metadata.dart" as bridge_metadata;
import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "session_mutation_dispatcher.dart";
import "worktree_service.dart";

class SessionCreationService {
  final MetadataService _metadataService;
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;
  final SessionMutationDispatcher _sessionMutationDispatcher;

  SessionCreationService({
    required MetadataService metadataService,
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
    required SessionMutationDispatcher sessionMutationDispatcher,
  }) : _metadataService = metadataService,
       _worktreeService = worktreeService,
       _sessionRepository = sessionRepository,
       _sessionMutationDispatcher = sessionMutationDispatcher;

  Future<Session> createSession({required CreateSessionRequest request}) async {
    await _sessionRepository.ensurePluginRoutable(
      pluginId: request.pluginId,
      operation: SessionOperation.createSession,
    );
    // Validate the opaque project handle before metadata generation or any
    // plugin/git side effect. The stored path is authoritative; unknown ids
    // must not be treated as directories.
    final projectDirectory = await _sessionRepository.resolveProjectDirectory(projectId: request.projectId);
    final normalizedCommand = request.command?.normalize();
    final agentModel = request.model;
    final userTexts = _extractTexts(parts: request.parts);
    final firstText = userTexts.firstOrNull;
    final userVisibleText = userTexts.isEmpty ? null : userTexts.join("\n\n");
    final metadata = await _generateMetadata(firstText: firstText);
    final worktreeResult = await _prepareWorktree(request: request, metadata: metadata);
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
    final finalSession = await _maybeRenameSession(session: created, metadata: metadata);
    // The plugin only knows the directory the session was created in, so for
    // a moved project it echoes the live path (or its own internal id) as the
    // session's projectID. Re-key the response to the stable identifier the
    // phone and the bridge key on — mirroring project-scoped session fetches.
    return _sessionRepository.enrichSession(
      session: finalSession.copyWith(projectID: request.projectId),
    );
  }

  List<String> _extractTexts({required List<PromptPart> parts}) {
    return parts
        .whereType<PromptPartText>()
        .map((part) => part.text)
        .where((text) => text.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<bridge_metadata.SessionMetadata?> _generateMetadata({required String? firstText}) async {
    if (firstText == null) {
      return null;
    }
    return _metadataService.generate(firstMessage: firstText);
  }

  Future<WorktreeResult?> _prepareWorktree({
    required CreateSessionRequest request,
    required bridge_metadata.SessionMetadata? metadata,
  }) async {
    if (!request.dedicatedWorktree) {
      return null;
    }
    return _worktreeService.prepareWorktreeForSession(
      projectId: request.projectId,
      parentSessionId: null,
      preferredBranchAndWorktreeName: metadata != null
          ? (branchName: metadata.branchName, worktreeName: metadata.worktreeName)
          : null,
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

  Future<Session> _maybeRenameSession({
    required Session session,
    required bridge_metadata.SessionMetadata? metadata,
  }) async {
    if (metadata?.title case final title?) {
      try {
        return await _sessionMutationDispatcher.renameSession(sessionId: session.id, title: title);
      } catch (e) {
        Log.w("Failed to rename session ${session.id}: $e");
      }
    }
    return session;
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
    final baseBranchAndCommit = await _worktreeService.resolveBaseBranchAndCommit(projectId: projectId);
    return (
      worktreePath: null,
      branchName: null,
      baseBranch: baseBranchAndCommit?.baseBranch,
      baseCommit: baseBranchAndCommit?.baseCommit,
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

IMPORTANT: Do NOT create new worktrees, branches, or working directories for this task — even if other instructions suggest it. One has already been created and is 100% dedicated to the work you will be doing in this session.

---
''';
  }
}
