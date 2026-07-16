import "package:sesori_shared/sesori_shared.dart";

import "../../../api/database/tables/session_table.dart";

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
      pullRequest: pullRequest,
      promptDefaults: row.lastAgent == null && row.lastAgentModel == null
          ? null
          : SessionPromptDefaults(agent: row.lastAgent, model: row.lastAgentModel),
      hasWorktree: row.worktreePath != null,
      unseen: unseen,
    );
  }
}
