import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// The desktop sidebar's Activity list, derived from existing project/session
/// owners. Sessions never leave their project; Activity is a shortcut on top.
final class DesktopSidebarSessionProjection._({required final List<DesktopSidebarActivityGroup> activityGroups}) {
  /// Activity holds what is in motion: running sessions and unseen sessions
  /// the user has not set aside. [deferredSessions] maps a session the user
  /// marked unread here to its `time.updated` at that moment; it stays out of
  /// Activity until the agent moves that stamp. [stickySessionId] keeps the
  /// Activity session the user just opened listed while it stays selected.
  factory from({
    required Iterable<ProjectSummary> projects,
    required Map<String, RecentSessionsEntry> entries,
    required Map<String, int> deferredSessions,
    required String? stickySessionId,
  }) {
    final groups = <DesktopSidebarActivityGroup>[];
    for (final project in projects) {
      final entry = entries[project.id];
      if (entry is! RecentSessionsLoaded) continue;
      final sessions = <DesktopSidebarActivitySession>[];
      for (final session in entry.visibleSessions) {
        final isRunning = entry.isRunning(session: session);
        final isUnseen = entry.isUnseen(session: session);
        final deferredAt = deferredSessions[session.id];
        final isDeferred = deferredAt != null && deferredAt == session.time?.updated;
        final inMotion = isRunning || (isUnseen && !isDeferred);
        if (!inMotion && session.id != stickySessionId) continue;
        sessions.add(
          DesktopSidebarActivitySession(
            session: session,
            isRunning: isRunning,
            isUnseen: isUnseen,
            isAwaitingInput: entry.isAwaitingInput(session: session),
          ),
        );
      }
      if (sessions.isEmpty) continue;
      groups.add(
        DesktopSidebarActivityGroup(
          project: project,
          sourceSessions: entry.sourceSessions,
          sessions: List.unmodifiable(sessions),
        ),
      );
    }
    return DesktopSidebarSessionProjection._(activityGroups: List.unmodifiable(groups));
  }
}

final class const DesktopSidebarActivityGroup({
  required final ProjectSummary project,
  required final List<Session> sourceSessions,
  required final List<DesktopSidebarActivitySession> sessions,
});

final class const DesktopSidebarActivitySession({
  required final Session session,
  required final bool isRunning,
  required final bool isUnseen,
  required final bool isAwaitingInput,
});
