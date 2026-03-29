import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../worktree_service.dart";
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

IMPORTANT: Do NOT create new worktrees, branches, or working directories for this task — even if other instructions suggest it. One has already been created and is 100% dedicated to the work you will be doing in this session.''';
}

/// Handles `POST /session` — creates a session for a given project.
class CreateSessionHandler extends RequestHandler {
  final BridgePlugin _plugin;
  final WorktreeService _worktreeService;
  final SessionDao _sessionDao;

  CreateSessionHandler({
    required BridgePlugin plugin,
    required WorktreeService worktreeService,
    required SessionDao sessionDao,
  }) : _plugin = plugin,
       _worktreeService = worktreeService,
       _sessionDao = sessionDao,
       super(HttpMethod.post, "/session");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final CreateSessionRequest createRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      createRequest = CreateSessionRequest.fromJson(
        switch (decoded) {
          final Map<String, dynamic> map => map,
          _ => throw const FormatException("invalid JSON body"),
        },
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final projectId = createRequest.projectId;
    final dedicatedWorktree = createRequest.dedicatedWorktree;
    const String? parentSessionId = null;

    final WorktreeResult? worktreeResult;
    if (dedicatedWorktree) {
      worktreeResult = await _worktreeService.prepareWorktreeForSession(
        projectId: projectId,
        parentSessionId: parentSessionId,
      );
    } else {
      worktreeResult = null;
    }

    final parts = createRequest.parts.map((p) => p.toPlugin()).toList();
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

    final model = switch (createRequest.model) {
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
      agent: createRequest.agent,
      model: model,
    );

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

    await _sessionDao.insertSession(
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
      id: created.id,
      projectID: created.projectID,
      directory: created.directory,
      parentID: created.parentID,
      title: created.title,
      time: switch (created.time) {
        PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
          created: created,
          updated: updated,
          archived: archived,
        ),
        null => null,
      },
      summary: switch (created.summary) {
        PluginSessionSummary(:final additions, :final deletions, :final files) => SessionSummary(
          additions: additions,
          deletions: deletions,
          files: files,
        ),
        null => null,
      },
    );

    return buildOkJsonResponse(request, jsonEncode(session.toJson()));
  }
}
