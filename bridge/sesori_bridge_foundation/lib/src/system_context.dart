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

/// The bridge-owned note that opens a scheduled run's prompt when its task
/// ran [command] in [workingDirectory] first; [result] is the block that
/// reports how it went. Every line of both is indented, so a line of output
/// that starts with `---` cannot end the note early.
String buildScheduledCommandContext({
  required String command,
  required String workingDirectory,
  required String result,
}) {
  String indented(String text) => text.split("\n").map((line) => "  $line").join("\n");
  return '''
$_marker
Before this run, Sesori ran the task's command in $workingDirectory:
${indented(command)}

Its result:
${indented(result)}

---
''';
}

/// Removes every leading bridge note ([buildWorktreeSystemContext],
/// [buildScheduledRunContext], [buildScheduledCommandContext]) from [text], so
/// a first prompt that carries several is fully hidden.
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

const _noticeStart = "[SESORI NOTICE]\n";
const _noticeAgentPart = "\n[FOR THE AGENT]\n";
const _noticeEnd = "\n[END SESORI NOTICE]";
const _noticePageReference = "[SESORI PAGE] ";
final _pageRequestIdPattern = RegExp(r"^\S+$");

/// A message Sesori sends into a session on its own behalf: [summary] is the
/// line the user sees, addressed to them, and [guidance] tells the agent what
/// to do about it. [pageRequestId] names the page the notice settles, on the
/// first line of the agent's part. [parseSessionNotice] reads the [summary]
/// and the page back wherever the message surfaces.
String buildSessionNotice({required String summary, required String guidance, required String? pageRequestId}) {
  return "$_noticeStart$summary$_noticeAgentPart"
      "${pageRequestId == null ? "" : "$_noticePageReference$pageRequestId\n"}"
      "Sesori wrote this message, not the user. The user sees only the line above,\n"
      "addressed to them.\n"
      "$guidance$_noticeEnd";
}

/// The summary and page reference of the notice [buildSessionNotice] wrote,
/// when [text] is exactly one notice apart from surrounding whitespace,
/// otherwise null.
///
/// The reference counts only on the first line of the agent's part, where
/// [buildSessionNotice] writes it: the guidance can quote the user's own
/// words, so a reference line anywhere else is never one.
({String summary, String? pageRequestId})? parseSessionNotice({required String text}) {
  final notice = text.trim();
  if (!notice.startsWith(_noticeStart) || !notice.endsWith(_noticeEnd)) return null;
  // Another frame inside means several messages were joined into one.
  final isOneNotice =
      notice.indexOf(_noticeStart, 1) < 0 && notice.indexOf(_noticeEnd) == notice.length - _noticeEnd.length;
  final agentPartIndex = notice.indexOf(_noticeAgentPart, _noticeStart.length);
  if (!isOneNotice || agentPartIndex < 0) return null;
  final agentPart = notice.substring(agentPartIndex + _noticeAgentPart.length);
  final firstLine = agentPart.split("\n").first;
  final reference = firstLine.startsWith(_noticePageReference)
      ? firstLine.substring(_noticePageReference.length)
      : null;
  return (
    summary: notice.substring(_noticeStart.length, agentPartIndex),
    pageRequestId: reference != null && _pageRequestIdPattern.hasMatch(reference) ? reference : null,
  );
}
