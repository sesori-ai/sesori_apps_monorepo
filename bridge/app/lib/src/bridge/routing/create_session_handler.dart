import 'package:sesori_shared/sesori_shared.dart';

import '../services/session_creation_service.dart';
import 'request_handler.dart';

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

/// Handles `POST /session/create` — creates a session for a given project.
class CreateSessionHandler extends BodyRequestHandler<CreateSessionRequest, Session> {
  final SessionCreationService _sessionCreationService;

  CreateSessionHandler({
    required SessionCreationService sessionCreationService,
  }) : _sessionCreationService = sessionCreationService,
       super(
         HttpMethod.post,
         '/session/create',
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
    return _sessionCreationService.createSession(request: body);
  }
}
