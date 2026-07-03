import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../persistence/tables/session_table.dart";
import "../session_unseen_calculator.dart";

/// Maps a [PluginSession] to the shared [Session] type used in relay responses.
extension PluginSessionMapper on PluginSession {
  Session toSharedSession() {
    return Session(
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
      promptDefaults: null,
    );
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
  required SessionUnseenCalculator unseenCalculator,
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
      // The stored row is the bridge's authoritative session→project
      // attribution (the same rule DerivedSessionBuilder scopes lists by): a
      // bridge-derived plugin reports a worktree session under its own cwd,
      // so without this rewrite its live created/updated events would carry
      // the worktree as projectID and the parent project's session list would
      // drop them as a project mismatch. The directory intentionally stays
      // the session's real cwd.
      projectID: storedSession.projectId,
      time: mergedTime,
      hasWorktree: storedSession.worktreePath != null,
      promptDefaults: _promptDefaultsFromStoredSession(storedSession),
      unseen: unseenCalculator.isUnseen(
        activity: storedSession.lastActivityAt,
        userMessage: storedSession.lastUserMessageAt,
        seen: storedSession.lastSeenAt,
      ),
    );
  }

  if (pullRequest != null) {
    result = result.copyWith(pullRequest: pullRequest);
  }

  return result;
}

SessionPromptDefaults? _promptDefaultsFromStoredSession(SessionDto storedSession) {
  if (storedSession.lastAgent == null && storedSession.lastAgentModel == null) {
    return null;
  }

  return SessionPromptDefaults(
    agent: storedSession.lastAgent,
    model: storedSession.lastAgentModel,
  );
}

List<Session> enrichSharedSessions({
  required List<Session> sessions,
  required Map<String, SessionDto> storedSessionsById,
  required Map<String, PullRequestInfo> pullRequestsBySessionId,
  required SessionUnseenCalculator unseenCalculator,
}) {
  return sessions
      .map(
        (session) => enrichSharedSession(
          session: session,
          storedSession: storedSessionsById[session.id],
          pullRequest: pullRequestsBySessionId[session.id],
          unseenCalculator: unseenCalculator,
        ),
      )
      .toList(growable: false);
}
