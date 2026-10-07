import "package:collection/collection.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/session_launch/session_launch.dart";
import "../../services/models/recent_sessions_entry.dart";
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
  /// first, where a surface opened mid-launch holds its project's newest
  /// sessions instead, one for each launch still waiting.
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
/// shows two rows. A newer launch whose session is in place but for older
/// launches below it still waiting keeps its row until those settle or fail,
/// then takes its place. If the sessions update after the one that brought
/// any other session in still does not place it, it goes where it belongs as
/// an ordinary change. While a project has a launch still waiting, a session
/// the surface has not shown before is held too: it may be that launch's
/// session, arriving before the reply that names it (D12).
///
/// [launching] holds only the launches this surface draws rows for, and
/// [sessions] is the surface's list in order. [slot] is the rows the
/// launching rows lead, in order: a session takes its row's place only at
/// the head of these. A launch whose session is among [placedSessionIds],
/// shown outside the slot where it needs no further update to settle (it waits
/// on the user), gives way at once.
LaunchRows resolveHeldLaunchSessions({
  required LaunchRows previous,
  required List<LaunchingSession> launching,
  required Map<String, String> sessionIds,
  required List<Session> sessions,
  required List<Session> slot,
  required Set<String> placedSessionIds,
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

  final slotIds = [for (final session in slot) session.id];
  final kept = rows.length - _inPlaceCount(rows: rows, resolved: resolved, slot: slotIds);
  // The rows that would take their places were the rows whose sessions have
  // not reached the slot yet gone: still waiting (bounded by the create
  // timeout), or named with the session still on its way. They wait those out.
  final inSlot = slotIds.toSet();
  final slotRows = [
    for (final row in rows)
      if (resolved[row.launchId] case final launch? when inSlot.contains(launch.sessionId)) row,
  ];
  final inPlaceOnceSettled = {
    for (final row in slotRows.skip(slotRows.length - _inPlaceCount(rows: slotRows, resolved: resolved, slot: slotIds)))
      row.launchId,
  };
  final placeholders = <LaunchingSession>[];
  final named = <String, ({String sessionId, bool arrived})>{};
  final held = <String>{};
  for (final (index, row) in rows.indexed) {
    final launch = resolved[row.launchId];
    if (launch == null) {
      placeholders.add(row);
    } else if (index >= kept) {
      rowKeys[launch.sessionId] = row.launchId;
    } else if (!placedSessionIds.contains(launch.sessionId) &&
        (inPlaceOnceSettled.contains(row.launchId) ||
            !(present.contains(launch.sessionId) && launch.arrived && sessionsChanged))) {
      placeholders.add(row);
      named[row.launchId] = (
        sessionId: launch.sessionId,
        arrived: launch.arrived || present.contains(launch.sessionId),
      );
      held.add(launch.sessionId);
    }
  }

  // The first update has shown nothing before it, so there it holds as many
  // of a project's newest unnamed sessions as the project has launches
  // waiting. An older session hidden until the launch resolves costs a
  // moment; a launch's session shown beside its own row shows it twice.
  final waitingPerProject = <String, int>{};
  for (final launch in launching) {
    waitingPerProject.update(launch.projectId, (count) => count + 1, ifAbsent: () => 1);
  }
  final shown = previous.shownSessionIds;
  final settled = {...sessionIds.values, ...rowKeys.keys, ...held};
  final unnamed = [
    for (final session in sessions)
      if (waitingPerProject.containsKey(session.projectID) && !settled.contains(session.id)) session,
  ];
  if (shown == null) {
    final newestFirst = unnamed.sorted((a, b) => (b.time?.created ?? 0).compareTo(a.time?.created ?? 0));
    for (final session in newestFirst) {
      final left = waitingPerProject[session.projectID] ?? 0;
      if (left == 0) continue;
      waitingPerProject[session.projectID] = left - 1;
      held.add(session.id);
    }
  } else {
    held.addAll([
      for (final session in unnamed)
        if (!shown.contains(session.id)) session.id,
    ]);
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

/// Keeps a surface's launching rows and the sessions their launches name
/// while it shows no active list (loading, failed or another filter), so a
/// launch that resolves meanwhile still has its row and its session when the
/// list returns. What the surface last showed stays as it was. A launch that
/// left without naming a session failed, and its row goes.
LaunchRows latchLaunchSessions({
  required LaunchRows previous,
  required List<LaunchingSession> launching,
  required Map<String, String> sessionIds,
}) {
  final rows = {
    for (final row in previous.placeholders)
      if (previous.named.containsKey(row.launchId) || sessionIds.containsKey(row.launchId)) row.launchId: row,
    for (final row in launching) row.launchId: row,
  };
  return LaunchRows(
    placeholders: rows.values.toList()..sort((a, b) => _newestFirst(a: a, b: b)),
    named: {
      for (final launchId in rows.keys)
        if (previous.named[launchId] case final latched?)
          launchId: latched
        else if (sessionIds[launchId] case final sessionId?)
          launchId: (sessionId: sessionId, arrived: false),
    },
    rowKeys: previous.rowKeys,
    shownSessionIds: previous.shownSessionIds,
    listedSessionIds: previous.listedSessionIds,
    heldSessionIds: previous.heldSessionIds,
  );
}

/// Where a surface draws a project's launching rows: at the head of
/// [sessions]. See [resolveHeldLaunchSessions] for [placedSessionIds].
typedef LaunchSlot = ({List<Session> sessions, Set<String> placedSessionIds});

/// Each project's launching rows on a surface that draws a project's launches
/// at the head of its [slots] rows: Activity's rows for the project, or all
/// of the project's sessions. A launch's session takes its row's place only
/// there; until then it is held out of the project's other rows, which the
/// project's sessions follow the slot in, so it reaching the slot is a
/// sessions update. A project whose sessions are not loaded keeps its rows.
Map<String, LaunchRows> resolveProjectLaunchRows({
  required Map<String, LaunchRows> previous,
  required SessionLaunchState launches,
  required Map<String, RecentSessionsEntry> entries,
  required Map<String, LaunchSlot> slots,
}) => {
  for (final MapEntry(key: projectId, value: entry) in entries.entries)
    projectId: _projectLaunchRows(
      previous: previous[projectId] ?? LaunchRows.none,
      launching: [
        for (final launch in launches.launching)
          if (launch.projectId == projectId) launch,
      ],
      sessionIds: launches.sessionIds,
      entry: entry,
      slot: slots[projectId] ?? (sessions: const [], placedSessionIds: const {}),
    ),
};

LaunchRows _projectLaunchRows({
  required LaunchRows previous,
  required List<LaunchingSession> launching,
  required Map<String, String> sessionIds,
  required RecentSessionsEntry entry,
  required LaunchSlot slot,
}) {
  if (entry is! RecentSessionsLoaded) {
    return latchLaunchSessions(previous: previous, launching: launching, sessionIds: sessionIds);
  }
  final inSlot = {for (final session in slot.sessions) session.id};
  return resolveHeldLaunchSessions(
    previous: previous,
    launching: launching,
    sessionIds: sessionIds,
    sessions: [
      ...slot.sessions,
      ...entry.visibleSessions.where((session) => !inSlot.contains(session.id)),
    ],
    slot: slot.sessions,
    placedSessionIds: slot.placedSessionIds,
  );
}

/// How many of the last [rows] can give way to their sessions in place: the
/// longest tail whose sessions open [slot] in the rows' order.
int _inPlaceCount({
  required List<LaunchingSession> rows,
  required Map<String, ({String sessionId, bool arrived})> resolved,
  required List<String> slot,
}) {
  for (var count = rows.length; count > 0; count--) {
    final tail = rows.sublist(rows.length - count);
    var matches = true;
    for (var index = 0; index < count && matches; index++) {
      matches = resolved[tail[index].launchId]?.sessionId == slot.elementAtOrNull(index);
    }
    if (matches) return count;
  }
  return 0;
}

int _newestFirst({required LaunchingSession a, required LaunchingSession b}) {
  final byStart = b.startedAt.compareTo(a.startedAt);
  return byStart != 0 ? byStart : b.launchId.compareTo(a.launchId);
}
