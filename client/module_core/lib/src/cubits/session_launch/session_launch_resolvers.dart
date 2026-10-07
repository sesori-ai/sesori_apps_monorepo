import "package:collection/collection.dart";
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

  /// Every session the surface had on its last update, in list order; null
  /// before its first. Only a change here counts as a sessions update, so
  /// activity and progress emissions never settle a launching row.
  required final List<String>? listedSessionIds,

  /// The sessions the surface leaves out of this update.
  required final Set<String> heldSessionIds,
}) {
  static const none = LaunchRows(
    placeholders: [],
    named: {},
    rowKeys: {},
    shownSessionIds: null,
    listedSessionIds: null,
    heldSessionIds: {},
  );
}

/// Decides which [sessions] a surface leaves out while launches settle, and
/// which launching rows it keeps drawing.
///
/// The launching rows lead the list, so a session takes its row's place
/// without moving anything only when the rows below the ones still waiting
/// all have their sessions, at the list's head, in the rows' order. Those
/// settle together; any other launch's session is held, so one launch never
/// shows two rows. If the sessions update after the one that brought a
/// session in still does not place it, it goes where it belongs as an
/// ordinary change. While a project has a launch still waiting, a session
/// the surface has not shown before is held too: it may be that launch's
/// session, arriving before the reply that names it (D12).
///
/// [launching] holds only the launches this surface draws rows for, and
/// [sessions] is the surface's list in order.
LaunchRows resolveHeldLaunchSessions({
  required LaunchRows previous,
  required List<LaunchingSession> launching,
  required Map<String, String> sessionIds,
  required List<Session> sessions,
}) {
  final listed = [for (final session in sessions) session.id];
  final present = listed.toSet();
  final sessionsChanged = !const ListEquality<String>().equals(previous.listedSessionIds, listed);
  final waiting = {for (final launch in launching) launch.launchId};
  final rowKeys = {
    for (final MapEntry(key: sessionId, value: launchId) in previous.rowKeys.entries)
      if (present.contains(sessionId)) sessionId: launchId,
  };

  // Each drawn launch that has its session, by launchId. No session means
  // the creation failed, and the row goes.
  final resolved = <String, ({String sessionId, bool arrived})>{};
  final rows = [...launching];
  for (final placeholder in previous.placeholders) {
    if (waiting.contains(placeholder.launchId)) continue;
    final latched = previous.named[placeholder.launchId];
    final sessionId = latched?.sessionId ?? sessionIds[placeholder.launchId];
    if (sessionId == null) continue;
    resolved[placeholder.launchId] = (sessionId: sessionId, arrived: latched?.arrived ?? false);
    rows.add(placeholder);
  }
  rows.sort((a, b) => _newestFirst(a: a, b: b));

  final kept = rows.length - _inPlaceCount(rows: rows, resolved: resolved, listed: listed);
  final placeholders = <LaunchingSession>[];
  final named = <String, ({String sessionId, bool arrived})>{};
  final held = <String>{};
  for (final (index, row) in rows.indexed) {
    final launch = resolved[row.launchId];
    if (launch == null) {
      placeholders.add(row);
    } else if (index >= kept) {
      rowKeys[launch.sessionId] = row.launchId;
    } else if (!(present.contains(launch.sessionId) && launch.arrived && sessionsChanged)) {
      placeholders.add(row);
      named[row.launchId] = (
        sessionId: launch.sessionId,
        arrived: launch.arrived || present.contains(launch.sessionId),
      );
      held.add(launch.sessionId);
    }
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
    placeholders: placeholders,
    named: named,
    rowKeys: rowKeys,
    shownSessionIds: {
      for (final id in listed)
        if (!held.contains(id)) id,
    },
    listedSessionIds: listed,
    heldSessionIds: held,
  );
}

/// How many of the last [rows] can give way to their sessions in place: the
/// longest tail whose sessions open [listed] in the rows' order.
int _inPlaceCount({
  required List<LaunchingSession> rows,
  required Map<String, ({String sessionId, bool arrived})> resolved,
  required List<String> listed,
}) {
  for (var count = rows.length; count > 0; count--) {
    final tail = rows.sublist(rows.length - count);
    var matches = true;
    for (var index = 0; index < count && matches; index++) {
      matches = resolved[tail[index].launchId]?.sessionId == listed.elementAtOrNull(index);
    }
    if (matches) return count;
  }
  return 0;
}

int _newestFirst({required LaunchingSession a, required LaunchingSession b}) {
  final byStart = b.startedAt.compareTo(a.startedAt);
  return byStart != 0 ? byStart : b.launchId.compareTo(a.launchId);
}
