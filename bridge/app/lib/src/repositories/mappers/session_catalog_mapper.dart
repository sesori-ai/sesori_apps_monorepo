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
  /// `updated_at` only advances when a backend reports a new time: a catalog
  /// import, or a plugin that emits an activity-bearing `session.updated`.
  /// Codex, ACP, and OpenCode do; Claude and Pi emit one only on rename, so a
  /// session driven entirely on the laptop kept displaying the transcript time
  /// read at the last import — "2d ago" on a session prompted minutes earlier.
  ///
  /// `last_user_message_at` is written live for every plugin, so folding it in
  /// makes the displayed recency honest for all harnesses at once. It is
  /// blended on read rather than written into `updated_at`, because catalog
  /// import's staleness detection depends on that column holding only
  /// backend-reported time (see CatalogImportRepository).
  ///
  /// `last_activity_at` is deliberately excluded even though it covers more
  /// events: it is an unseen-formula token, not a recency one. "Mark as
  /// Unread" synthesizes it from the current clock (SessionDao.forceUnseen),
  /// which would make an untouched session claim it just changed, and
  /// SessionUnseenService coalesces it to the FIRST event of an unseen streak,
  /// so it would not follow a long response anyway. The cost of leaving it out
  /// is that assistant-only work does not advance the displayed time past the
  /// prompt that started it — conservative, and self-correcting on the next
  /// user message or import.
  static int _latestActivityAt(SessionDto row) {
    if (row.lastUserMessageAt case final at? when at > row.updatedAt) return at;
    return row.updatedAt;
  }
}
