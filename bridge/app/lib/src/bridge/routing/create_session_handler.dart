import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../metadata_service.dart";
import "../models/session_metadata.dart" as bridge_metadata;
import "../repositories/session_repository.dart";
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

/// Handles `POST /session` — creates a session for a given project.
class CreateSessionHandler extends BodyRequestHandler<CreateSessionRequest, Session> {
  final BridgePlugin _plugin;
  final MetadataService _metadataService;
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;
  final SessionPersistenceService _sessionPersistenceService;

  CreateSessionHandler({
    required BridgePlugin plugin,
    required MetadataService metadataService,
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
    required SessionPersistenceService sessionPersistenceService,
  }) : _plugin = plugin,
       _metadataService = metadataService,
       _worktreeService = worktreeService,
       _sessionRepository = sessionRepository,
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
    final dedicatedWorktree = body.dedicatedWorktree;
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

    final WorktreeResult? worktreeResult;
    if (dedicatedWorktree) {
      worktreeResult = await _worktreeService.prepareWorktreeForSession(
        projectId: projectId,
        parentSessionId: parentSessionId,
        preferredBranchAndWorktreeName: metadata != null
            ? (branchName: metadata.branchName, worktreeName: metadata.worktreeName)
            : null,
      );
    } else {
      worktreeResult = null;
    }

    final parts = body.parts.map((p) => p.toPlugin()).toList();
    if (worktreeResult case WorktreeSuccess(:final path, :final branchName, :final baseBranch)) {
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
    }

    final model = switch (body.model) {
      PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
      null => null,
    };

    final directory = !dedicatedWorktree
        ? projectId
        : switch (worktreeResult) {
            WorktreeSuccess(:final path) => path,
            WorktreeFallback(:final originalPath) => originalPath,
            null => projectId,
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

    String? worktreePath;
    String? branchName;
    String? baseBranch;
    String? baseCommit;
    if (worktreeResult case WorktreeSuccess(
      :final path,
      branchName: final resolvedBranchName,
      baseBranch: final resolvedBaseBranch,
      baseCommit: final resolvedBaseCommit,
    )) {
      worktreePath = path;
      branchName = resolvedBranchName;
      baseBranch = resolvedBaseBranch;
      baseCommit = resolvedBaseCommit;
    } else {
      worktreePath = null;
      branchName = null;
      if (!dedicatedWorktree) {
        final baseBranchAndCommit = await _worktreeService.resolveBaseBranchAndCommit(projectPath: projectId);
        baseBranch = baseBranchAndCommit?.baseBranch;
        baseCommit = baseBranchAndCommit?.baseCommit;
      } else {
        baseBranch = null;
        baseCommit = null;
      }
    }

    await _sessionPersistenceService.createSession(
      sessionId: created.id,
      projectId: projectId,
      isDedicated: dedicatedWorktree,
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

    return _sessionRepository.enrichSession(session: session);
  }
}
