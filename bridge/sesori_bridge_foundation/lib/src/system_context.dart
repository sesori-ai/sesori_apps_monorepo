import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show sesoriMcpServerName;

const _marker = "[SYSTEM CONTEXT — IMPORTANT]";
const _terminator = "\n---";
final _tokenPrefix = RegExp(r"^\S+ $");
final _leadingLineBreaks = RegExp(r"^[\r\n]+");

/// The bridge-owned note that opens a dedicated-worktree session's first
/// prompt or command arguments. [stripSystemContext] hides it again wherever
/// user text surfaces, so the notes and the strip stay together here.
String buildWorktreeSystemContext({required String worktreePath, required String baseBranch}) {
  return '''
$_marker
A dedicated git worktree has been created for this session:
- Worktree path: $worktreePath
- Based on: $baseBranch

This worktree is on a detached HEAD at the latest commit of $baseBranch. Before your first commit, create a branch for this task, named as this repository's instructions say, or after the work.

IMPORTANT: Perform all work for this task in this dedicated worktree. You may switch branches or create additional branches here as needed. Do NOT create another worktree or working directory — even if other instructions suggest it.

---
''';
}

/// The bridge-owned note that opens a scheduled run's text prompt when the
/// run's session gets Sesori's own tools, asking the agent to propose
/// improvements to its task through them.
String buildScheduledRunContext({required String taskName, required String taskId}) {
  return '''
$_marker
This message is a scheduled run of the Sesori task "$taskName" (id $taskId). It repeats on a schedule, usually while nobody is watching.

Do the task below. If you learn something that would make future runs better, such as a clearer instruction, a step that keeps failing or a schedule that no longer fits, propose a change to this task with the update_task tool from the $sesoriMcpServerName server, leaving out every field you are not changing. The user approves each change on their phone, so propose at most one focused change per run. get_task and list_task_runs show the current task and how recent runs went.

---
''';
}

/// Removes every leading bridge note ([buildWorktreeSystemContext],
/// [buildScheduledRunContext]) from [text], so a first prompt that carries
/// both is fully hidden.
///
/// The notes may follow one command token and a space (a harness that renders
/// a command as `<token> <arguments>`); the token is kept. Matching is on the
/// marker and the `---` line rather than the exact wording, so notes written
/// by older bridges are hidden too. Returns [text] itself when it does not open
/// with a note, and `null` when nothing remains.
String? stripSystemContext({required String text}) {
  var current = text;
  while (true) {
    final stripped = _stripOneNote(text: current);
    if (stripped == null || identical(stripped, current)) return stripped;
    current = stripped;
  }
}

String? _stripOneNote({required String text}) {
  final markerIndex = text.indexOf(_marker);
  if (markerIndex < 0) return text;
  final prefix = text.substring(0, markerIndex);
  if (prefix.isNotEmpty && !_tokenPrefix.hasMatch(prefix)) return text;
  final terminatorIndex = text.indexOf(_terminator, markerIndex);
  if (terminatorIndex < 0) return text;
  final rest = text.substring(terminatorIndex + _terminator.length).replaceFirst(_leadingLineBreaks, "");
  final token = prefix.trimRight();
  if (rest.trim().isEmpty) return token.isEmpty ? null : token;
  return token.isEmpty ? rest : "$token $rest";
}
