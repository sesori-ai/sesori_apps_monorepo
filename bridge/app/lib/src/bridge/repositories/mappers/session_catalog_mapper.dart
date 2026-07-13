import "package:sesori_shared/sesori_shared.dart";

import "../../persistence/tables/session_table.dart";

class SessionCatalogMapper {
  const SessionCatalogMapper();

  Session map({
    required SessionDto row,
    required PullRequestInfo? pullRequest,
    required bool unseen,
  }) {
    return Session(
      id: row.sessionId,
      pluginId: row.pluginId,
      projectID: row.projectId,
      directory: row.directory,
      parentID: row.parentSessionId,
      title: row.title ?? row.catalogTitle,
      time: SessionTime(created: row.createdAt, updated: row.updatedAt, archived: row.archivedAt),
      summary: _summary(row),
      pullRequest: pullRequest,
      promptDefaults: row.lastAgent == null && row.lastAgentModel == null
          ? null
          : SessionPromptDefaults(agent: row.lastAgent, model: row.lastAgentModel),
      hasWorktree: row.worktreePath != null,
      unseen: unseen,
    );
  }

  SessionSummary? _summary(SessionDto row) {
    if (row.summaryAdditions == null && row.summaryDeletions == null && row.summaryFiles == null) {
      return null;
    }
    return SessionSummary(
      additions: row.summaryAdditions ?? 0,
      deletions: row.summaryDeletions ?? 0,
      files: row.summaryFiles ?? 0,
    );
  }
}
