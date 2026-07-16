class StoredSession {
  final String id;
  final String backendSessionId;
  final String pluginId;
  final String projectId;
  final String? parentSessionId;
  final String directory;
  final String? worktreePath;
  final String? branchName;
  final bool isDedicated;
  final int? archivedAt;
  final String? baseBranch;
  final String? baseCommit;

  const StoredSession({
    required this.id,
    required this.backendSessionId,
    required this.pluginId,
    required this.projectId,
    required this.parentSessionId,
    required this.directory,
    required this.worktreePath,
    required this.branchName,
    required this.isDedicated,
    required this.archivedAt,
    required this.baseBranch,
    required this.baseCommit,
  });
}
