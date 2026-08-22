class const StoredSession({
  required final String id,
  required final String backendSessionId,
  required final String pluginId,
  required final String projectId,
  required final String? parentSessionId,
  required final String directory,
  required final String? worktreePath,
  required final String? branchName,
  required final bool isDedicated,
  required final int? archivedAt,
  required final String? baseBranch,
  required final String? baseCommit,
});
