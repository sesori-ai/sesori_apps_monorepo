class const CodexSessionRecord({
  required final String id,
  required final String rolloutPath,
  required final String? cwd,
  required final String? threadName,
  required final DateTime? createdAt,
  required final DateTime? updatedAt,
  required final String? cliVersion,
  required final String? modelProvider,
  required final String? model,

  /// The parent thread of a sub-agent rollout (`session_meta.parent_thread_id`
  /// with `thread_source: subagent`); `null` for a root rollout.
  required final String? parentId,
});
