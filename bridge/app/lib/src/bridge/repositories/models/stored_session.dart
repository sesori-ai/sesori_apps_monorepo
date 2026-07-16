class StoredSession {
  final String id;
  final String projectId;
  final String? parentSessionId;
  final String? worktreePath;
  final String? branchName;
  final bool isDedicated;
  final int? archivedAt;
  final String? baseBranch;
  final String? baseCommit;
  final int? lastUserInteractionAt;

  const StoredSession({
    required this.id,
    required this.projectId,
    required this.parentSessionId,
    required this.worktreePath,
    required this.branchName,
    required this.isDedicated,
    required this.archivedAt,
    required this.baseBranch,
    required this.baseCommit,
    required this.lastUserInteractionAt,
  });
}
