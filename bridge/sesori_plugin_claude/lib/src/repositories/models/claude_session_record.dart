/// One transcript reduced to the facts the catalog needs.
///
/// Hand-written and dependency-free because it crosses an isolate boundary and
/// is internal to the plugin; nothing outside this package sees it.
class const ClaudeSessionRecord({
  /// The transcript filename minus `.jsonl`: a UUID for a root session, or
  /// `agent-<agentId>` for a sub-agent transcript under the root's `subagents/`.
  required final String id,
  required final String transcriptPath,

  /// The root session a sub-agent transcript belongs to; null for a root.
  required final String? parentId,

  /// The directory the session ran in.
  required final String cwd,

  /// From the CLI's own `ai-title` record, or a sub-agent's meta description.
  /// Null when neither exists.
  required final String? title,
  required final DateTime? createdAt,

  /// Transcript mtime: for an append-only file, the session's last activity.
  required final DateTime? updatedAt,
  required final String? gitBranch,

  /// The CLI version that wrote the transcript.
  required final String? cliVersion,
});
