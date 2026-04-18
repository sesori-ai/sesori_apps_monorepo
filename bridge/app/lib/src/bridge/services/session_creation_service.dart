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
    final firstText = _extractFirstText(parts: request.parts);
    final metadata = await _generateMetadata(firstText: firstText);
    final worktreeResult = await _prepareWorktree(request: request, metadata: metadata);
    final created = await _sessionRepository.createSession(
      directory: _resolveDirectory(request: request, worktreeResult: worktreeResult),
      parentSessionId: null,
      parts: _buildPromptParts(
        parts: request.parts,
        worktreeResult: worktreeResult,
        command: request.command,
      ),
      agent: request.command == null ? request.agent : null,
      model: request.command == null ? request.model : null,
    );
    final worktreeState = await _resolveWorktreeState(
      projectId: request.projectId,
      dedicatedWorktree: request.dedicatedWorktree,
      worktreeResult: worktreeResult,
    );
    await _sessionPersistenceService.createSession(
      sessionId: created.id,
      projectId: request.projectId,
      isDedicated: request.dedicatedWorktree,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      worktreePath: worktreeState.worktreePath,
      branchName: worktreeState.branchName,
      baseBranch: worktreeState.baseBranch,
      baseCommit: worktreeState.baseCommit,
    );
    await _maybeSendCommand(
      session: created,
      command: request.command,
      arguments: _buildCommandArguments(
        userArguments: firstText ?? '',
        worktreeResult: worktreeResult,
      ),
    );
    final finalSession = await _maybeRenameSession(session: created, metadata: metadata);
    return _sessionRepository.enrichSession(session: finalSession);
  }

  String? _extractFirstText({required List<PromptPart> parts}) {
    return parts
        .whereType<PromptPartText>()
        .map((part) => part.text)
        .where((text) => text.trim().isNotEmpty)
        .firstOrNull;
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
          text: buildWorktreeSystemPrompt(
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

  String _resolveDirectory({required CreateSessionRequest request, required WorktreeResult? worktreeResult}) {
    if (!request.dedicatedWorktree) {
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

  Future<void> _maybeSendCommand({
    required Session session,
    required String? command,
    required String arguments,
  }) async {
    if (command == null) {
      return;
    }
    await _sessionRepository.sendCommand(
      sessionId: session.id,
      command: command,
      arguments: arguments,
    );
  }

  String _buildCommandArguments({
    required String userArguments,
    required WorktreeResult? worktreeResult,
  }) {
    if (worktreeResult case WorktreeSuccess(:final path, :final branchName, :final baseBranch)) {
      final systemContext = buildWorktreeSystemPrompt(
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
    final baseBranchAndCommit = await _worktreeService.resolveBaseBranchAndCommit(projectPath: projectId);
    return (
      worktreePath: null,
      branchName: null,
      baseBranch: baseBranchAndCommit?.baseBranch,
      baseCommit: baseBranchAndCommit?.baseCommit,
    );
  }
}
