import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../metadata_service.dart";
import "../models/session_metadata.dart" as bridge_metadata;
import "../repositories/session_repository.dart";
import "session_persistence_service.dart";
import "worktree_service.dart";

String buildWorktreeSystemPrompt({
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

String buildContinueBranchSystemPrompt({
  required String branchName,
  required String path,
  required String? baseBranch,
}) {
  return '''
[SYSTEM CONTEXT — IMPORTANT]
A dedicated git worktree has been set up for this session. You are continuing work on an existing branch: `$branchName`. The worktree is at `$path`.${baseBranch != null ? ' Based on: $baseBranch.' : ''}

IMPORTANT: Do NOT create new branches or worktrees — the branch already exists and is checked out in the worktree above.

---
''';
}

class SessionCreationService {
  final MetadataService _metadataService;
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;
  final SessionPersistenceService _sessionPersistenceService;

  SessionCreationService({
    required MetadataService metadataService,
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
    required SessionPersistenceService sessionPersistenceService,
  }) : _metadataService = metadataService,
       _worktreeService = worktreeService,
       _sessionRepository = sessionRepository,
       _sessionPersistenceService = sessionPersistenceService;

  Future<Session> createSession({required CreateSessionRequest request}) async {
    final metadata = await _generateMetadata(parts: request.parts);
    final worktreeResult = await _prepareWorktree(request: request, metadata: metadata);
    final created = await _sessionRepository.createSession(
      directory: _resolveDirectory(request: request, worktreeResult: worktreeResult),
      parentSessionId: null,
      parts: _buildPromptParts(
        parts: request.parts,
        worktreeMode: request.worktreeMode,
        worktreeResult: worktreeResult,
      ),
      agent: request.agent,
      model: request.model,
    );
    final finalSession = await _maybeRenameSession(session: created, metadata: metadata);
    final worktreeState = await _resolveWorktreeState(
      projectId: request.projectId,
      worktreeMode: request.worktreeMode,
      worktreeResult: worktreeResult,
    );
    await _sessionPersistenceService.createSession(
      sessionId: created.id,
      projectId: request.projectId,
      isDedicated: worktreeState.isDedicated,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      worktreePath: worktreeState.worktreePath,
      branchName: worktreeState.branchName,
      baseBranch: worktreeState.baseBranch,
      baseCommit: worktreeState.baseCommit,
    );
    return _sessionRepository.enrichSession(session: finalSession);
  }

  Future<bridge_metadata.SessionMetadata?> _generateMetadata({required List<PromptPart> parts}) async {
    final firstText = parts
        .whereType<PromptPartText>()
        .map((part) => part.text)
        .where((text) => text.trim().isNotEmpty)
        .firstOrNull;
    if (firstText == null) {
      return null;
    }
    return _metadataService.generate(firstMessage: firstText);
  }

  Future<WorktreeResult?> _prepareWorktree({
    required CreateSessionRequest request,
    required bridge_metadata.SessionMetadata? metadata,
  }) async {
    if (request.worktreeMode == WorktreeMode.none) {
      return null;
    }
    return _worktreeService.prepareWorktreeForBranch(
      mode: request.worktreeMode,
      selectedBranch: request.selectedBranch,
      projectPath: request.projectId,
      sessionId: "",
      preferredBranchAndWorktreeName: metadata != null
          ? (branchName: metadata.branchName, worktreeName: metadata.worktreeName)
          : null,
    );
  }

  List<PromptPart> _buildPromptParts({
    required List<PromptPart> parts,
    required WorktreeMode worktreeMode,
    required WorktreeResult? worktreeResult,
  }) {
    if (worktreeResult case WorktreeSuccess(:final path, :final branchName, :final baseBranch)) {
      return [
        PromptPart.text(
          text: worktreeMode == WorktreeMode.stayOnBranch
              ? buildContinueBranchSystemPrompt(
                  branchName: branchName,
                  path: path,
                  baseBranch: baseBranch,
                )
              : buildWorktreeSystemPrompt(
                  branchName: branchName,
                  worktreePath: path,
                  baseBranch: baseBranch,
                ),
        ),
        ...parts,
      ];
    }
    return parts;
  }

  String _resolveDirectory({required CreateSessionRequest request, required WorktreeResult? worktreeResult}) {
    if (request.worktreeMode == WorktreeMode.none) {
      return request.projectId;
    }
    return switch (worktreeResult) {
      WorktreeSuccess(:final path) => path,
      WorktreeFallback(:final originalPath) => originalPath,
      null => request.projectId,
    };
  }

  Future<Session> _maybeRenameSession({
    required Session session,
    required bridge_metadata.SessionMetadata? metadata,
  }) async {
    if (metadata?.title case final title?) {
      try {
        return await _sessionRepository.renameSession(sessionId: session.id, title: title);
      } catch (e) {
        Log.w("Failed to rename session ${session.id}: $e");
      }
    }
    return session;
  }

  Future<({bool isDedicated, String? worktreePath, String? branchName, String? baseBranch, String? baseCommit})>
  _resolveWorktreeState({
    required String projectId,
    required WorktreeMode worktreeMode,
    required WorktreeResult? worktreeResult,
  }) async {
    if (worktreeResult case WorktreeSuccess(
      :final path,
      branchName: final resolvedBranchName,
      baseBranch: final resolvedBaseBranch,
      baseCommit: final resolvedBaseCommit,
      isDedicated: final resolvedIsDedicated,
    )) {
      return (
        isDedicated: resolvedIsDedicated,
        worktreePath: resolvedIsDedicated ? path : null,
        branchName: resolvedBranchName,
        baseBranch: resolvedBaseBranch,
        baseCommit: resolvedBaseCommit,
      );
    }
    if (worktreeResult case WorktreeFallback()) {
      return (isDedicated: true, worktreePath: null, branchName: null, baseBranch: null, baseCommit: null);
    }
    if (worktreeMode != WorktreeMode.none) {
      return (isDedicated: false, worktreePath: null, branchName: null, baseBranch: null, baseCommit: null);
    }
    final baseBranchAndCommit = await _worktreeService.resolveBaseBranchAndCommit(projectPath: projectId);
    return (
      isDedicated: false,
      worktreePath: null,
      branchName: null,
      baseBranch: baseBranchAndCommit?.baseBranch,
      baseCommit: baseBranchAndCommit?.baseCommit,
    );
  }
}
