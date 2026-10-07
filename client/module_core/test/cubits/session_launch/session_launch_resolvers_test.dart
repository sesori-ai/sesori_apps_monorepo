import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  final launch = LaunchingSession(
    launchId: "launch-1",
    projectId: "project-1",
    pluginId: "claude",
    startedAt: DateTime.utc(2026, 10, 7, 12),
    title: "Fix the bug",
  );
  final existing = testSession(id: "existing");
  final created = testSession(id: "created");

  LaunchRows resolve({
    required LaunchRows previous,
    required List<LaunchingSession> launching,
    required Map<String, String> sessionIds,
    required List<Session> sessions,
  }) => resolveHeldLaunchSessions(
    previous: previous,
    launching: launching,
    sessionIds: sessionIds,
    sessions: sessions,
    slot: sessions,
    placedSessionIds: const {},
  );

  test("a list opened mid-launch holds its project's newest session for each launch waiting, whatever the clocks", () {
    final newest = testSession(id: "newest", createdAt: 300);
    final older = testSession(id: "older", createdAt: 200);
    final elsewhere = testSession(id: "elsewhere", createdAt: 400).copyWith(projectID: "project-2");
    final sessions = [elsewhere, older, newest];
    final opened = resolve(previous: LaunchRows.none, launching: [launch], sessionIds: const {}, sessions: sessions);

    expect(opened.placeholders, [launch]);
    expect(opened.heldSessionIds, {"newest"}, reason: "it may be the launch's session, which the bridge's clock dated");

    final failed = resolve(previous: opened, launching: const [], sessionIds: const {}, sessions: sessions);
    expect(failed.heldSessionIds, isEmpty, reason: "an older session held this way returns once the launch resolves");
  });

  test("a session that arrives before the reply naming its launch is held until the launch resolves", () {
    final opened = resolve(
      previous: LaunchRows.none,
      launching: const [],
      sessionIds: const {},
      sessions: [existing],
    );
    final arrivedEarly = resolve(
      previous: opened,
      launching: [launch],
      sessionIds: const {},
      sessions: [created, existing],
    );
    expect(arrivedEarly.placeholders, [launch]);
    expect(arrivedEarly.heldSessionIds, {"created"}, reason: "opening it now would find no handoff (#1822)");

    final promoted = resolve(
      previous: arrivedEarly,
      launching: const [],
      sessionIds: const {"launch-1": "created"},
      sessions: [created, existing],
    );
    expect(promoted.placeholders, isEmpty);
    expect(promoted.heldSessionIds, isEmpty);
    expect(promoted.rowKeys, {"created": "launch-1"}, reason: "the session takes the launching row's place");
  });

  test("a new session in a project with no waiting launch is shown at once", () {
    final opened = resolve(
      previous: LaunchRows.none,
      launching: const [],
      sessionIds: const {},
      sessions: [existing],
    );
    final elsewhere = resolve(
      previous: opened,
      launching: [launch],
      sessionIds: const {},
      sessions: [
        testSession(id: "other").copyWith(projectID: "project-2"),
        existing,
      ],
    );

    expect(elsewhere.heldSessionIds, isEmpty);
  });

  test("a launch promoted before its session arrives keeps one row until the session lands", () {
    final opened = resolve(
      previous: LaunchRows.none,
      launching: [launch],
      sessionIds: const {},
      sessions: [existing],
    );
    final promoted = resolve(
      previous: opened,
      launching: const [],
      sessionIds: const {"launch-1": "created"},
      sessions: [existing],
    );
    expect(promoted.placeholders, [launch]);
    expect(promoted.heldSessionIds, {"created"});

    // The handoff was taken meanwhile, so only the latched association names it.
    final landed = resolve(
      previous: promoted,
      launching: const [],
      sessionIds: const {},
      sessions: [created, existing],
    );
    expect(landed.placeholders, isEmpty);
    expect(landed.heldSessionIds, isEmpty);
    expect(landed.rowKeys, {"created": "launch-1"});
  });

  test("a session not in the row's slot goes where it belongs on the next sessions update", () {
    final promoted = resolve(
      previous: resolve(
        previous: LaunchRows.none,
        launching: [launch],
        sessionIds: const {},
        sessions: [existing],
      ),
      launching: const [],
      sessionIds: const {"launch-1": "created"},
      sessions: [existing, created],
    );
    expect(promoted.placeholders, [launch]);
    expect(promoted.heldSessionIds, {"created"});

    // An activity or progress emission rebuilds the list with the same sessions.
    final statusUpdate = resolve(
      previous: promoted,
      launching: const [],
      sessionIds: const {},
      sessions: [existing, created],
    );
    expect(statusUpdate.placeholders, [launch], reason: "only a sessions update moves it");

    final released = resolve(
      previous: statusUpdate,
      launching: const [],
      sessionIds: const {},
      sessions: [
        existing,
        created,
        testSession(id: "other"),
      ],
    );
    expect(released.placeholders, isEmpty);
    expect(released.heldSessionIds, isEmpty);
    expect(released.rowKeys, isEmpty, reason: "it moves as an ordinary change");
  });

  test("launches whose sessions land together each take their own row's place", () {
    final newer = LaunchingSession(
      launchId: "launch-2",
      projectId: "project-1",
      pluginId: "claude",
      startedAt: DateTime.utc(2026, 10, 7, 12, 1),
      title: "Add tests",
    );
    final createdNewer = testSession(id: "created-2");
    final opened = resolve(
      previous: LaunchRows.none,
      launching: [newer, launch],
      sessionIds: const {},
      sessions: [existing],
    );
    expect(opened.placeholders, [newer, launch]);

    final landed = resolve(
      previous: opened,
      launching: const [],
      sessionIds: const {"launch-1": "created", "launch-2": "created-2"},
      sessions: [createdNewer, created, existing],
    );
    expect(landed.placeholders, isEmpty);
    expect(landed.heldSessionIds, isEmpty);
    expect(landed.rowKeys, {"created-2": "launch-2", "created": "launch-1"});
  });

  test("a session lands in place under a newer launch that is still waiting", () {
    final newer = LaunchingSession(
      launchId: "launch-2",
      projectId: "project-1",
      pluginId: "claude",
      startedAt: DateTime.utc(2026, 10, 7, 12, 1),
      title: "Add tests",
    );
    final landed = resolve(
      previous: resolve(
        previous: LaunchRows.none,
        launching: [newer, launch],
        sessionIds: const {},
        sessions: [existing],
      ),
      launching: [newer],
      sessionIds: const {"launch-1": "created"},
      sessions: [created, existing],
    );
    expect(landed.placeholders, [newer]);
    expect(landed.rowKeys, {"created": "launch-1"});
  });

  test("a newer launch that lands first keeps its row until the older one settles, then takes its place", () {
    final newer = LaunchingSession(
      launchId: "launch-2",
      projectId: "project-1",
      pluginId: "claude",
      startedAt: DateTime.utc(2026, 10, 7, 12, 1),
      title: "Add tests",
    );
    final createdNewer = testSession(id: "created-2");
    final elsewhere = testSession(id: "elsewhere").copyWith(projectID: "project-2");
    final opened = resolve(previous: LaunchRows.none, launching: const [], sessionIds: const {}, sessions: [existing]);
    final landedFirst = resolve(
      previous: resolve(previous: opened, launching: [newer, launch], sessionIds: const {}, sessions: [existing]),
      launching: [launch],
      sessionIds: const {"launch-2": "created-2"},
      sessions: [createdNewer, existing],
    );
    expect(landedFirst.placeholders, [newer, launch]);
    expect(landedFirst.heldSessionIds, {"created-2"});

    final sessionsUpdate = resolve(
      previous: landedFirst,
      launching: [launch],
      sessionIds: const {"launch-2": "created-2"},
      sessions: [createdNewer, existing, elsewhere],
    );
    expect(sessionsUpdate.placeholders, [newer, launch], reason: "it is in place but for the older row below it");

    // The older launch's reply names its session before the list has it.
    final olderNamed = resolve(
      previous: resolve(
        previous: sessionsUpdate,
        launching: const [],
        sessionIds: const {"launch-1": "created", "launch-2": "created-2"},
        sessions: [createdNewer, existing, elsewhere],
      ),
      launching: const [],
      sessionIds: const {"launch-1": "created", "launch-2": "created-2"},
      sessions: [createdNewer, existing],
    );
    expect(olderNamed.placeholders, [newer, launch], reason: "the older session is still on its way");

    final bothLanded = resolve(
      previous: olderNamed,
      launching: const [],
      sessionIds: const {"launch-1": "created", "launch-2": "created-2"},
      sessions: [createdNewer, created, existing, elsewhere],
    );
    expect(bothLanded.placeholders, isEmpty);
    expect(bothLanded.rowKeys, {"created-2": "launch-2", "created": "launch-1"});

    final olderFailed = resolve(
      previous: sessionsUpdate,
      launching: const [],
      sessionIds: const {"launch-2": "created-2"},
      sessions: [createdNewer, existing, elsewhere],
    );
    expect(olderFailed.placeholders, isEmpty);
    expect(olderFailed.rowKeys, {"created-2": "launch-2"});
  });

  test("a launch that failed drops its row", () {
    final failed = resolve(
      previous: resolve(
        previous: LaunchRows.none,
        launching: [launch],
        sessionIds: const {},
        sessions: [existing],
      ),
      launching: const [],
      sessionIds: const {},
      sessions: [existing],
    );

    expect(failed.placeholders, isEmpty);
    expect(failed.heldSessionIds, isEmpty);
  });

  group("an Activity surface", () {
    RecentSessionsEntry loaded(List<Session> sessions) => RecentSessionsLoaded(
      sourceSessions: sessions,
      visibleSessions: sessions,
      activityBySessionId: const {},
      listStateBySessionId: const {},
    );
    Map<String, LaunchRows> resolveActivity({
      required Map<String, LaunchRows> previous,
      required SessionLaunchState launches,
      required RecentSessionsEntry entry,
      required List<Session> running,
    }) => resolveProjectLaunchRows(
      previous: previous,
      launches: launches,
      entries: {"project-1": entry},
      slots: {"project-1": (sessions: running, placedSessionIds: const {})},
    );
    const promotedState = SessionLaunchState(launching: [], sessionIds: {"launch-1": "created"});

    test("holds a session that reached its project before Activity, and swaps it in once it runs", () {
      final opened = resolveActivity(
        previous: const {},
        launches: SessionLaunchState(launching: [launch], sessionIds: const {}),
        entry: loaded([existing]),
        running: const [],
      );
      final arrived = resolveActivity(
        previous: opened,
        launches: promotedState,
        entry: loaded([created, existing]),
        running: const [],
      );
      expect(arrived["project-1"]?.placeholders, [launch], reason: "the project lists it, Activity does not yet");
      expect(arrived["project-1"]?.heldSessionIds, {"created"}, reason: "so Recent leaves it out meanwhile");

      final running = resolveActivity(
        previous: arrived,
        launches: promotedState,
        entry: loaded([created, existing]),
        running: [created],
      );
      expect(running["project-1"]?.placeholders, isEmpty);
      expect(running["project-1"]?.heldSessionIds, isEmpty);
      expect(running["project-1"]?.rowKeys, {"created": "launch-1"}, reason: "it takes the row's place");
    });

    test("lets a session that never runs go where it belongs on the next sessions update", () {
      final arrived = resolveActivity(
        previous: resolveActivity(
          previous: const {},
          launches: SessionLaunchState(launching: [launch], sessionIds: const {}),
          entry: loaded([existing]),
          running: const [],
        ),
        launches: promotedState,
        entry: loaded([created, existing]),
        running: const [],
      );
      final released = resolveActivity(
        previous: arrived,
        launches: promotedState,
        entry: loaded([testSession(id: "other"), created, existing]),
        running: const [],
      );

      expect(released["project-1"]?.placeholders, isEmpty, reason: "no Creating… is left behind");
      expect(released["project-1"]?.heldSessionIds, isEmpty);
    });

    test("keeps a project's row and its session while the project reloads", () {
      final opened = resolveActivity(
        previous: const {},
        launches: SessionLaunchState(launching: [launch], sessionIds: const {}),
        entry: loaded([existing]),
        running: const [],
      );
      final reloading = resolveActivity(
        previous: opened,
        launches: promotedState,
        entry: RecentSessionsLoading(),
        running: const [],
      );

      expect(reloading["project-1"]?.placeholders, [launch]);
      expect(reloading["project-1"]?.named, {"launch-1": (sessionId: "created", arrived: false)});
    });

    test("drops a failed launch's row while the project's read is unavailable", () {
      final waiting = resolveActivity(
        previous: const {},
        launches: SessionLaunchState(launching: [launch], sessionIds: const {}),
        entry: const RecentSessionsFailed(reason: RemoteFailureReason.networkDown),
        running: const [],
      );
      expect(waiting["project-1"]?.placeholders, [launch]);

      final failed = resolveActivity(
        previous: waiting,
        launches: const SessionLaunchState(launching: [], sessionIds: {}),
        entry: const RecentSessionsFailed(reason: RemoteFailureReason.networkDown),
        running: const [],
      );
      expect(failed["project-1"]?.placeholders, isEmpty, reason: "no Creating… outlives the failure alert");
    });
  });
}
