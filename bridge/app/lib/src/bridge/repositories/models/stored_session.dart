import "package:sesori_shared/sesori_shared.dart" show AgentModel;

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
  final String? lastAgent;
  final AgentModel? lastAgentModel;
  final int createdAt;
  final int updatedAt;
  final int projectionUpdatedAt;
  final int? lastActivityAt;
  final int? lastSeenAt;
  final int? lastUserMessageAt;
  final String? title;
  final String? catalogTitle;

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
    required this.lastAgent,
    required this.lastAgentModel,
    required this.createdAt,
    required this.updatedAt,
    required this.projectionUpdatedAt,
    required this.lastActivityAt,
    required this.lastSeenAt,
    required this.lastUserMessageAt,
    required this.title,
    required this.catalogTitle,
  });
}
