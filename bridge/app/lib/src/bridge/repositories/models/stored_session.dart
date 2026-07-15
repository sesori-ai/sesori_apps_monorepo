class StoredSession {
  final String id;
  final String projectId;
  final String? worktreePath;
  final String? branchName;
  final bool isDedicated;
  final int? archivedAt;
  final String? baseBranch;
  final String? baseCommit;

  const StoredSession({
    required this.id,
    required this.projectId,
    required this.worktreePath,
    required this.branchName,
    required this.isDedicated,
    required this.archivedAt,
    required this.baseBranch,
    required this.baseCommit,
  });
}
