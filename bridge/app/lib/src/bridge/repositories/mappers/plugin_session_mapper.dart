import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../persistence/tables/session_table.dart";

/// Maps a [PluginSession] to the shared [Session] type used in relay responses.
extension PluginSessionMapper on PluginSession {
  Session toSharedSession({
    bool? hasWorktree,
  }) {
    var session = Session(
      id: id,
      projectID: projectID,
      directory: directory,
      parentID: parentID,
      title: title,
      time: switch (time) {
        PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
          created: created,
          updated: updated,
          archived: archived,
        ),
        null => null,
      },
      summary: switch (summary) {
        PluginSessionSummary(:final additions, :final deletions, :final files) => SessionSummary(
          additions: additions,
          deletions: deletions,
          files: files,
        ),
        null => null,
      },
      pullRequest: null,
    );
    if (hasWorktree != null) {
      session = session.copyWith(hasWorktree: hasWorktree);
    }
    return session;
  }
}

extension PluginSessionsMapper on Iterable<PluginSession> {
  List<Session> toSharedSessions() {
    return map((session) => session.toSharedSession()).toList(growable: false);
  }
}

Session enrichSharedSession({
  required Session session,
  required SessionDto? storedSession,
  required PullRequestInfo? pullRequest,
}) {
  var result = session;

  if (storedSession != null) {
    final currentTime = session.time;
    final mergedTime = currentTime != null
        ? currentTime.copyWith(archived: storedSession.archivedAt)
        : SessionTime(
            created: storedSession.createdAt,
            updated: storedSession.createdAt,
            archived: storedSession.archivedAt,
          );
    result = result.copyWith(
      time: mergedTime,
      hasWorktree: storedSession.worktreePath != null,
    );
  }

  if (pullRequest != null) {
    result = result.copyWith(pullRequest: pullRequest);
  }

  return result;
}

List<Session> enrichSharedSessions({
  required List<Session> sessions,
  required Map<String, SessionDto> storedSessionsById,
  required Map<String, PullRequestInfo> pullRequestsBySessionId,
}) {
  return sessions
      .map(
        (session) => enrichSharedSession(
          session: session,
          storedSession: storedSessionsById[session.id],
          pullRequest: pullRequestsBySessionId[session.id],
        ),
      )
      .toList(growable: false);
}
