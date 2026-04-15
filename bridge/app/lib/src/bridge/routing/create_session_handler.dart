import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../metadata_service.dart";
import "../models/session_metadata.dart" as bridge_metadata;
import "../services/session_persistence_service.dart";
import "../services/worktree_service.dart";
import "prompt_part_mapper.dart";
import "request_handler.dart";

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

/// Handles `POST /session` — creates a session for a given project.
class CreateSessionHandler extends BodyRequestHandler<CreateSessionRequest, Session> {
  final BridgePlugin _plugin;
  final MetadataService _metadataService;
  final WorktreeService _worktreeService;
  final SessionPersistenceService _sessionPersistenceService;

  CreateSessionHandler({
    required BridgePlugin plugin,
    required MetadataService metadataService,
    required WorktreeService worktreeService,
    required SessionPersistenceService sessionPersistenceService,
  }) : _plugin = plugin,
       _metadataService = metadataService,
       _worktreeService = worktreeService,
       _sessionPersistenceService = sessionPersistenceService,
       super(
         HttpMethod.post,
         "/session/create",
         fromJson: CreateSessionRequest.fromJson,
       );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required CreateSessionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;
    final worktreeMode = body.worktreeMode;
    final selectedBranch = body.selectedBranch;
    const String? parentSessionId = null;

    final firstText = body.parts
        .whereType<PromptPartText>()
        .map((p) => p.text)
        .where((t) => t.trim().isNotEmpty)
        .firstOrNull;

    final bridge_metadata.SessionMetadata? metadata;
    if (firstText != null) {
      metadata = await _metadataService.generate(
        firstMessage: firstText,
      );
    } else {
      metadata = null;
    }

    final worktreeResult = await _worktreeService.prepareWorktreeForBranch(
      mode: worktreeMode,
      selectedBranch: selectedBranch,
      projectPath: projectId,
      sessionId: "",
      preferredBranchAndWorktreeName: worktreeMode == WorktreeMode.newBranch && metadata != null
          ? (branchName: metadata.branchName, worktreeName: metadata.worktreeName)
          : null,
    );

    final parts = body.parts.map((p) => p.toPlugin()).toList();
    if (worktreeResult case WorktreeSuccess(:final path, :final branchName, :final baseBranch)) {
      switch (worktreeMode) {
        case WorktreeMode.newBranch:
          parts.insert(
            0,
            PluginPromptPart.text(
              text: buildWorktreeSystemPrompt(
                branchName: branchName,
                worktreePath: path,
                baseBranch: baseBranch,
              ),
            ),
          );
        case WorktreeMode.stayOnBranch:
          parts.insert(
            0,
            PluginPromptPart.text(
              text: buildContinueBranchSystemPrompt(
                branchName: branchName,
                path: path,
                baseBranch: baseBranch,
              ),
            ),
          );
        case WorktreeMode.none:
          break;
      }
    }

    final model = switch (body.model) {
      PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
      null => null,
    };

    final directory = switch (worktreeResult) {
      WorktreeSuccess(:final path) => path,
      WorktreeFallback(:final originalPath) => originalPath,
    };

    final created = await _plugin.createSession(
      directory: directory,
      parentSessionId: parentSessionId,
      parts: parts,
      agent: body.agent,
      model: model,
    );

    var finalSession = created;
    if (metadata?.title case final title?) {
      try {
        finalSession = await _plugin.renameSession(
          sessionId: created.id,
          title: title,
        );
      } catch (e) {
        Log.w("Failed to rename session ${created.id}: $e");
      }
    }

    var isDedicated = worktreeMode == WorktreeMode.newBranch;
    String? worktreePath;
    String? branchName;
    String? baseBranch;
    String? baseCommit;
    if (worktreeResult case WorktreeSuccess(
      :final path,
      branchName: final resolvedBranchName,
      baseBranch: final resolvedBaseBranch,
      baseCommit: final resolvedBaseCommit,
      isDedicated: final resolvedIsDedicated,
    )) {
      worktreePath = path;
      branchName = resolvedBranchName;
      baseBranch = resolvedBaseBranch;
      baseCommit = resolvedBaseCommit;
      isDedicated = resolvedIsDedicated;
    } else {
      worktreePath = null;
      branchName = null;
      if (isDedicated) {
        baseBranch = null;
        baseCommit = null;
      } else {
        final baseBranchAndCommit = await _worktreeService.resolveBaseBranchAndCommit(projectPath: projectId);
        baseBranch = baseBranchAndCommit?.baseBranch;
        baseCommit = baseBranchAndCommit?.baseCommit;
      }
    }

    await _sessionPersistenceService.createSession(
      sessionId: created.id,
      projectId: projectId,
      isDedicated: isDedicated,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      worktreePath: worktreePath,
      branchName: branchName,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
    );

    final session = Session(
      id: finalSession.id,
      projectID: finalSession.projectID,
      directory: finalSession.directory,
      parentID: finalSession.parentID,
      title: finalSession.title,
      branchName: branchName,
      time: switch (finalSession.time) {
        PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
          created: created,
          updated: updated,
          archived: archived,
        ),
        null => null,
      },
      summary: switch (finalSession.summary) {
        PluginSessionSummary(:final additions, :final deletions, :final files) => SessionSummary(
          additions: additions,
          deletions: deletions,
          files: files,
        ),
        null => null,
      },
      pullRequest: null,
      hasWorktree: worktreePath != null,
    );

    return session;
  }
}
