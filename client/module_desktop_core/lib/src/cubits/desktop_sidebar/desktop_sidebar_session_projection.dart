import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Immutable desktop-sidebar placement derived from existing project/session owners.
final class DesktopSidebarSessionProjection._({
  required final List<DesktopSidebarActivityGroup> activityGroups,
  required final Map<String, Set<String>> _activitySessionIdsByProject,
}) {
  factory from({
    required Iterable<ProjectSummary> projects,
    required Map<String, RecentSessionsEntry> entries,
  }) {
    final groups = <DesktopSidebarActivityGroup>[];
    final activitySessionIdsByProject = <String, Set<String>>{};
    for (final project in projects) {
      final entry = entries[project.id];
      if (entry is! RecentSessionsLoaded) continue;
      final activityIds = <String>{};
      final sessions = <DesktopSidebarActivitySession>[];
      for (final session in entry.visibleSessions) {
        final isRunning = entry.isRunning(session: session);
        final isUnseen = entry.isUnseen(session: session);
        if ((!isRunning && !isUnseen) || !activityIds.add(session.id)) continue;
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
      activitySessionIdsByProject[project.id] = Set.unmodifiable(activityIds);
      groups.add(
        DesktopSidebarActivityGroup(
          project: project,
          sourceSessions: entry.sourceSessions,
          sessions: List.unmodifiable(sessions),
        ),
      );
    }
    return DesktopSidebarSessionProjection._(
      activityGroups: List.unmodifiable(groups),
      activitySessionIdsByProject: Map.unmodifiable(activitySessionIdsByProject),
    );
  }

  List<Session> ordinaryRows({
    required String projectId,
    required RecentSessionsLoaded loaded,
    required String? selectedSessionId,
  }) => List.unmodifiable(
    loaded.rows(
      selectedSessionId: selectedSessionId,
      excludingSessionIds: _activitySessionIdsByProject[projectId] ?? const {},
    ),
  );
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
