import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/recent_sessions_entry.dart";
import "recent_sessions_resolvers.dart";

/// Activity: the sessions in motion, derived from existing project/session
/// owners for every surface. Sessions never leave their project; Activity is a
/// shortcut on top.
final class SessionActivityProjection._({required final List<SessionActivityGroup> activityGroups}) {
  /// The phone's Activity: sessions waiting on the user first, then running
  /// ones, each in project order. Finished unseen sessions stay in their lists.
  List<({ProjectSummary project, SessionActivityEntry entry})> get waitingFirst {
    final waiting = <({ProjectSummary project, SessionActivityEntry entry})>[];
    final running = <({ProjectSummary project, SessionActivityEntry entry})>[];
    for (final group in activityGroups) {
      for (final entry in group.sessions) {
        if (entry.isAwaitingInput) {
          waiting.add((project: group.project, entry: entry));
        } else if (entry.isRunning) {
          running.add((project: group.project, entry: entry));
        }
      }
    }
    return [...waiting, ...running];
  }

  /// Activity holds what is in motion: running sessions, sessions waiting on
  /// the user, and unseen sessions the user has not set aside. [deferredSessions] maps a session the user
  /// marked unread here to its `time.updated` at that moment; it stays out of
  /// Activity until the agent moves that stamp. [stickySessionId] keeps the
  /// Activity session the user just opened listed while it stays selected. A
  /// surface without either passes an empty map and null.
  factory from({
    required Iterable<ProjectSummary> projects,
    required Map<String, RecentSessionsEntry> entries,
    required Map<String, int> deferredSessions,
    required String? stickySessionId,

    /// Sessions being archived, hidden while they still read as unarchived.
    required Set<String> hiddenSessionIds,
  }) {
    final groups = <SessionActivityGroup>[];
    for (final project in projects) {
      final entry = entries[project.id];
      if (entry is! RecentSessionsLoaded) continue;
      final sessions = <SessionActivityEntry>[];
      for (final session in entry.visibleSessions) {
        if (hiddenSessionIds.contains(session.id)) continue;
        final isRunning = entry.isRunning(session: session);
        final isUnseen = entry.isUnseen(session: session);
        final deferredAt = deferredSessions[session.id];
        final isSetAside = isUnseen && deferredAt != null && deferredAt == session.time?.updated;
        final isAwaitingInput = entry.isAwaitingInput(session: session);
        // A pending question need not keep the agent running, and still needs the
        // user until they set it aside.
        final inMotion = isRunning || ((isAwaitingInput || isUnseen) && !isSetAside);
        // Setting a session aside is explicit, so it beats the sticky selection too.
        final isSticky = session.id == stickySessionId && !isSetAside;
        if (!inMotion && !isSticky) continue;
        sessions.add(
          SessionActivityEntry(
            session: session,
            isRunning: isRunning,
            isUnseen: isUnseen,
            isAwaitingInput: isAwaitingInput,
          ),
        );
      }
      if (sessions.isEmpty) continue;
      groups.add(
        SessionActivityGroup(
          project: project,
          sourceSessions: entry.sourceSessions,
          sessions: List.unmodifiable(sessions),
        ),
      );
    }
    return SessionActivityProjection._(activityGroups: List.unmodifiable(groups));
  }
}

final class const SessionActivityGroup({
  required final ProjectSummary project,
  required final List<Session> sourceSessions,
  required final List<SessionActivityEntry> sessions,
});

final class const SessionActivityEntry({
  required final Session session,
  required final bool isRunning,
  required final bool isUnseen,
  required final bool isAwaitingInput,
});
