import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/session_launch/session_launch.dart";
import "session_launch_state.dart";

SessionLaunchState resolveSessionLaunchState({required List<SessionLaunch> launches}) => SessionLaunchState(
  launching: [
    for (final launch in launches)
      if (launch case PendingSessionLaunch(:final title) || ReleasedPendingSessionLaunch(:final title))
        LaunchingSession(
          launchId: launch.launchId,
          projectId: launch.projectId,
          pluginId: launch.pluginId,
          startedAt: launch.startedAt,
          title: title,
        ),
  ]..sort((a, b) => _newestFirst(a: a, b: b)),
  sessionIds: {
    for (final launch in launches)
      if (launch case CreatedSessionLaunch(:final session) || ReconcilingSessionLaunch(:final session))
        launch.launchId: session.id,
  },
);

/// What one surface draws for launches, carried from one update to the next.
final class const LaunchRows({
  /// The launching rows, newest first: launches still waiting for their
  /// session, and launches whose session has not reached the row's slot yet.
  required final List<LaunchingSession> placeholders,

  /// For each drawn placeholder whose launch has a session: that session, and
  /// whether it was already among the surface's sessions on an update.
  required final Map<String, ({String sessionId, bool arrived})> named,

  /// The launchId each session that took a launching row's place keeps as
  /// its row key, so the row's content changes in place.
  required final Map<String, String> rowKeys,

  /// The sessions the surface showed on its last update; null before its
  /// first, so a surface opened mid-launch shows every session it finds.
  required final Set<String>? shownSessionIds,

  /// The sessions the surface leaves out of this update.
  required final Set<String> heldSessionIds,
}) {
  static const none = LaunchRows(
    placeholders: [],
    named: {},
    rowKeys: {},
    shownSessionIds: null,
    heldSessionIds: {},
  );
}

/// Decides which [sessions] a surface leaves out while launches settle, and
/// which launching rows it keeps drawing.
///
/// A launching row stays until its session is in the row's slot
/// ([isInSlot]); its session is held meanwhile, so one launch never shows two
/// rows. If the update after the one that brought the session in still does
/// not place it there, the session goes where it belongs as an ordinary
/// change. While a project has a launch still waiting, a session that
/// surface has not shown before is held too: it may be that launch's session,
/// arriving before the reply that names it (D12).
///
/// [launching] holds only the launches this surface draws rows for, and
/// [sessionsChanged] says whether this update brings new [sessions].
LaunchRows resolveHeldLaunchSessions({
  required LaunchRows previous,
  required List<LaunchingSession> launching,
  required Map<String, String> sessionIds,
  required List<Session> sessions,
  required bool sessionsChanged,
  required bool Function({required Session session}) isInSlot,
}) {
  final present = {for (final session in sessions) session.id: session};
  final waiting = {for (final launch in launching) launch.launchId};
  final placeholders = [...launching];
  final named = <String, ({String sessionId, bool arrived})>{};
  final rowKeys = {
    for (final MapEntry(key: sessionId, value: launchId) in previous.rowKeys.entries)
      if (present.containsKey(sessionId)) sessionId: launchId,
  };
  final held = <String>{};

  for (final placeholder in previous.placeholders) {
    if (waiting.contains(placeholder.launchId)) continue;
    final latched = previous.named[placeholder.launchId];
    // No session means the creation failed, and the row goes.
    final sessionId = latched?.sessionId ?? sessionIds[placeholder.launchId];
    if (sessionId == null) continue;
    final session = present[sessionId];
    final arrived = latched?.arrived ?? false;
    if (session != null && isInSlot(session: session)) {
      rowKeys[sessionId] = placeholder.launchId;
      continue;
    }
    if (session != null && arrived && sessionsChanged) continue;
    placeholders.add(placeholder);
    named[placeholder.launchId] = (sessionId: sessionId, arrived: arrived || session != null);
    held.add(sessionId);
  }

  final shown = previous.shownSessionIds;
  if (shown != null) {
    final waitingProjects = {for (final launch in launching) launch.projectId};
    final settled = {...sessionIds.values, ...rowKeys.keys};
    for (final session in sessions) {
      if (shown.contains(session.id) || settled.contains(session.id)) continue;
      if (waitingProjects.contains(session.projectID)) held.add(session.id);
    }
  }

  return LaunchRows(
    placeholders: placeholders..sort((a, b) => _newestFirst(a: a, b: b)),
    named: named,
    rowKeys: rowKeys,
    shownSessionIds: {
      for (final id in present.keys)
        if (!held.contains(id)) id,
    },
    heldSessionIds: held,
  );
}

int _newestFirst({required LaunchingSession a, required LaunchingSession b}) {
  final byStart = b.startedAt.compareTo(a.startedAt);
  return byStart != 0 ? byStart : b.launchId.compareTo(a.launchId);
}
