import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/tables/session_table.dart";

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
      time: SessionTime(created: row.createdAt, updated: _latestActivityAt(row), archived: row.archivedAt),
      pullRequest: pullRequest,
      promptDefaults: row.lastAgent == null && row.lastAgentModel == null
          ? null
          : SessionPromptDefaults(agent: row.lastAgent, model: row.lastAgentModel),
      hasWorktree: row.worktreePath != null,
      unseen: unseen,
      lastUserActivityAt: row.lastUserMessageAt,
    );
  }

  /// The newest instant the bridge knows about for this session.
  ///
  /// `updated_at` includes backend observations, bridge-owned metadata changes,
  /// and live turn completion (including Stop). `last_user_message_at` is
  /// written live for every plugin, so folding it in also shows fresh prompts
  /// before the turn settles, even without a backend `session.updated` event.
  /// Catalog import tracks backend history freshness separately from this
  /// displayed recency (see CatalogImportRepository).
  ///
  /// `last_activity_at` is deliberately excluded even though it covers more
  /// events: it is an unseen-formula token, not a recency one. "Mark as
  /// Unread" synthesizes it from the current clock (SessionDao.forceUnseen),
  /// which would make an untouched session claim it just changed, and
  /// SessionUnseenService coalesces it to the FIRST event of an unseen streak,
  /// so it would not follow a long response anyway.
  static int _latestActivityAt(SessionDto row) {
    if (row.lastUserMessageAt case final at? when at > row.updatedAt) return at;
    return row.updatedAt;
  }
}
