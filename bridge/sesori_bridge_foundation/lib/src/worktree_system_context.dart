const _marker = "[SYSTEM CONTEXT — IMPORTANT]";
const _terminator = "\n---";
final _tokenPrefix = RegExp(r"^\S+ $");
final _leadingLineBreaks = RegExp(r"^[\r\n]+");

/// The bridge-owned note that opens a dedicated-worktree session's first
/// prompt or command arguments. [stripWorktreeSystemContext] hides it again
/// wherever user text surfaces, so the two stay together here.
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

/// Removes a leading [buildWorktreeSystemContext] note from [text].
///
/// The note may follow one command token and a space (a harness that renders
/// a command as `<token> <arguments>`); the token is kept. Matching is on the
/// marker and the `---` line rather than the exact wording, so notes written
/// by older bridges are hidden too. Returns [text] itself when it does not open
/// with a note, and `null` when nothing remains.
String? stripWorktreeSystemContext({required String text}) {
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
