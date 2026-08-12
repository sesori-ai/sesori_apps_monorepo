import "package:sesori_shared/sesori_shared.dart";

import "../../../api/database/tables/session_table.dart";

class const SessionCatalogMapper() {
  Session map({
    required SessionDto row,
    required PullRequestInfo? pullRequest,
    required bool unseen,
  }) {
    return Session(
      // COMPATIBILITY 2026-08-02 (v1.6.1): Older bridges map the creation
      // branch to Session.branchName. Modern bridges map current_branch_name;
      // remove this comment when bridge versions before v1.6.1 are unsupported.
      branchName: row.currentBranchName,
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
