import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/recent_sessions_entry.dart";

/// Every listed session of [projects], newest first, without the ones
/// [hiddenSessionIds] suppresses (archived, or waiting out an Undo).
List<({ProjectSummary project, Session session})> sessionsByRecency({
  required List<ProjectSummary> projects,
  required Map<String, RecentSessionsEntry> entries,
  required Set<String> hiddenSessionIds,
}) => [
  for (final project in projects)
    if (entries[project.id] case RecentSessionsLoaded(:final visibleSessions))
      for (final session in visibleSessions)
        if (!hiddenSessionIds.contains(session.id)) (project: project, session: session),
]..sort((a, b) => (b.session.time?.updated ?? 0).compareTo(a.session.time?.updated ?? 0));
