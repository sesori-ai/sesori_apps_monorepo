import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("projects every running or live-unseen active session in owner order", () {
    final projectTwoUnseen = _session(id: "two-unseen", projectId: "two", unseen: true);
    final projectTwoCleared = _session(id: "two-cleared", projectId: "two", unseen: true);
    final projectOneRunning = _session(id: "one-running", projectId: "one");
    final projection = SessionActivityProjection.from(
      projects: const [
        ProjectSummary(id: "two", name: "Two", path: "/two", time: null),
        ProjectSummary(id: "one", name: "One", path: "/one", time: null),
      ],
      entries: {
        "one": RecentSessionsLoaded(
          sourceSessions: [projectOneRunning],
          visibleSessions: [projectOneRunning],
          activityBySessionId: const {
            "one-running": SessionActivityInfo(
              mainAgentRunning: true,
              awaitingInput: true,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
          },
          listStateBySessionId: const {},
        ),
        "two": RecentSessionsLoaded(
          sourceSessions: [projectTwoUnseen, projectTwoCleared],
          visibleSessions: [projectTwoUnseen, projectTwoCleared],
          activityBySessionId: const {},
          listStateBySessionId: const {
            "two-cleared": (unseen: false, lastUserActivityAt: null),
          },
        ),
      },
      deferredSessions: const {},
      stickySessionId: null,
      hiddenSessionIds: const {},
    );

    expect(projection.activityGroups.map((group) => group.project.id), ["two", "one"]);
    expect(projection.activityGroups[0].sessions.map((item) => item.session.id), ["two-unseen"]);
    expect(projection.activityGroups[0].sessions.single.isUnseen, isTrue);
    expect(projection.activityGroups[1].sessions.single.session.id, "one-running");
    expect(projection.activityGroups[1].sessions.single.isRunning, isTrue);
    expect(projection.activityGroups[1].sessions.single.isAwaitingInput, isTrue);
  });

  test("a session marked unread stays out of Activity until the agent moves its stamp", () {
    final deferred = _session(id: "deferred", projectId: "one", unseen: true, updated: 5);
    final news = _session(id: "news", projectId: "one", unseen: true, updated: 9);
    List<String> activity({required List<Session> sessions, required String? stickySessionId}) =>
        SessionActivityProjection.from(
          projects: const [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
          entries: {
            "one": RecentSessionsLoaded(
              sourceSessions: sessions,
              visibleSessions: sessions,
              activityBySessionId: const {},
              listStateBySessionId: const {},
            ),
          },
          deferredSessions: const {"deferred": 5, "news": 5},
          stickySessionId: stickySessionId,
          hiddenSessionIds: const {},
        ).activityGroups.expand((group) => group.sessions).map((item) => item.session.id).toList();

    expect(activity(sessions: [deferred, news], stickySessionId: null), ["news"]);
    // Running always counts as in motion, deferred or not.
    final running = RecentSessionsLoaded(
      sourceSessions: [deferred],
      visibleSessions: [deferred],
      activityBySessionId: const {
        "deferred": SessionActivityInfo(
          mainAgentRunning: true,
          awaitingInput: false,
          lastUserActivityAt: null,
          updatedAt: null,
        ),
      },
      listStateBySessionId: const {},
    );
    expect(
      SessionActivityProjection.from(
        projects: const [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
        entries: {"one": running},
        deferredSessions: const {"deferred": 5},
        stickySessionId: null,
        hiddenSessionIds: const {},
      ).activityGroups.single.sessions.single.isRunning,
      isTrue,
    );
    // The session the user just opened from Activity stays listed once seen.
    final opened = _session(id: "opened", projectId: "one");
    expect(activity(sessions: [opened, deferred], stickySessionId: null), isEmpty);
    expect(activity(sessions: [opened, deferred], stickySessionId: "opened"), ["opened"]);
    // Marking the open session unread sets it aside at once.
    expect(activity(sessions: [opened, deferred], stickySessionId: "deferred"), isEmpty);
  });

  test("waitingFirst lists waiting sessions, then running ones, leaving finished unseen out", () {
    SessionActivityInfo activity({required bool awaitingInput}) => SessionActivityInfo(
      mainAgentRunning: true,
      awaitingInput: awaitingInput,
      lastUserActivityAt: null,
      updatedAt: null,
    );
    final running = _session(id: "running", projectId: "one");
    final waitingOne = _session(id: "waiting-one", projectId: "one");
    final unseen = _session(id: "unseen", projectId: "one", unseen: true);
    final waitingTwo = _session(id: "waiting-two", projectId: "two");
    final projection = SessionActivityProjection.from(
      projects: const [
        ProjectSummary(id: "one", name: "One", path: "/one", time: null),
        ProjectSummary(id: "two", name: "Two", path: "/two", time: null),
      ],
      entries: {
        "one": RecentSessionsLoaded(
          sourceSessions: [running, waitingOne, unseen],
          visibleSessions: [running, waitingOne, unseen],
          activityBySessionId: {
            "running": activity(awaitingInput: false),
            "waiting-one": activity(awaitingInput: true),
          },
          listStateBySessionId: const {},
        ),
        "two": RecentSessionsLoaded(
          sourceSessions: [waitingTwo],
          visibleSessions: [waitingTwo],
          activityBySessionId: {"waiting-two": activity(awaitingInput: true)},
          listStateBySessionId: const {},
        ),
      },
      deferredSessions: const {},
      stickySessionId: null,
      hiddenSessionIds: const {},
    );

    expect(
      projection.waitingFirst.map((item) => (item.project.id, item.entry.session.id)),
      [("one", "waiting-one"), ("two", "waiting-two"), ("one", "running")],
    );
    expect(projection.needsYou.map((item) => item.entry.session.id), ["waiting-one", "waiting-two"]);
    expect(projection.running.map((item) => item.entry.session.id), ["running"]);
  });

  test("recent holds settled sessions across projects newest first, leaving hidden ones out", () {
    final one = [for (var index = 1; index <= 4; index++) _session(id: "one-$index", projectId: "one", updated: index)];
    final two = [
      _session(id: "two-running", projectId: "two", updated: 99),
      _session(id: "two-hidden", projectId: "two", updated: 98),
      _session(id: "two-unseen", projectId: "two", unseen: true, updated: 10),
      _session(id: "two-old", projectId: "two", updated: 0),
    ];
    final projection = SessionActivityProjection.from(
      projects: const [
        ProjectSummary(id: "one", name: "One", path: "/one", time: null),
        ProjectSummary(id: "two", name: "Two", path: "/two", time: null),
      ],
      entries: {
        "one": RecentSessionsLoaded(
          sourceSessions: one,
          visibleSessions: one,
          activityBySessionId: const {},
          listStateBySessionId: const {},
        ),
        "two": RecentSessionsLoaded(
          sourceSessions: two,
          visibleSessions: two,
          activityBySessionId: const {
            "two-running": SessionActivityInfo(
              mainAgentRunning: true,
              awaitingInput: false,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
          },
          listStateBySessionId: const {},
        ),
      },
      deferredSessions: const {},
      stickySessionId: null,
      hiddenSessionIds: const {"two-hidden"},
    );

    expect(
      projection.recent.map((item) => (item.project.id, item.entry.session.id)),
      [("two", "two-unseen"), ("one", "one-4"), ("one", "one-3"), ("one", "one-2"), ("one", "one-1"), ("two", "two-old")],
    );
    expect(projection.recent.first.entry.isUnseen, isTrue);
  });

  test("a session waiting on the user stays in Activity while its agent is idle, until set aside", () {
    final waiting = _session(id: "waiting", projectId: "one");
    final projection = SessionActivityProjection.from(
      projects: const [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
      entries: {
        "one": RecentSessionsLoaded(
          sourceSessions: [waiting],
          visibleSessions: [waiting],
          activityBySessionId: const {
            "waiting": SessionActivityInfo(
              mainAgentRunning: false,
              awaitingInput: true,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
          },
          listStateBySessionId: const {},
        ),
      },
      deferredSessions: const {},
      stickySessionId: null,
      hiddenSessionIds: const {},
    );

    expect(projection.waitingFirst.map((item) => item.entry.session.id), ["waiting"]);

    // Marking it unread sets it aside like any other session.
    final markedUnread = _session(id: "waiting", projectId: "one", unseen: true, updated: 5);
    final setAside = SessionActivityProjection.from(
      projects: const [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
      entries: {
        "one": RecentSessionsLoaded(
          sourceSessions: [markedUnread],
          visibleSessions: [markedUnread],
          activityBySessionId: const {
            "waiting": SessionActivityInfo(
              mainAgentRunning: false,
              awaitingInput: true,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
          },
          listStateBySessionId: const {},
        ),
      },
      deferredSessions: const {"waiting": 5},
      stickySessionId: null,
      hiddenSessionIds: const {},
    );
    expect(setAside.activityGroups, isEmpty);
  });

  test("Activity sessions stay in their project's rows", () {
    final sessions = [
      _session(id: "priority", projectId: "one", unseen: true),
      for (var index = 2; index <= 5; index++) _session(id: "session-$index", projectId: "one"),
    ];
    final loaded = RecentSessionsLoaded(
      sourceSessions: sessions,
      visibleSessions: sessions,
      activityBySessionId: const {},
      listStateBySessionId: const {},
    );
    final projection = SessionActivityProjection.from(
      projects: const [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
      entries: {"one": loaded},
      deferredSessions: const {},
      stickySessionId: null,
      hiddenSessionIds: const {},
    );

    expect(projection.activityGroups.single.sessions.single.session.id, "priority");
    expect(
      loaded.rows(selectedSessionId: "session-5", limit: 3).map((session) => session.id),
      ["priority", "session-2", "session-3", "session-5"],
    );
  });
}

Session _session({required String id, required String projectId, bool unseen = false, int updated = 1}) => Session(
  autoContinuation: null,
  id: id,
  title: id,
  projectID: projectId,
  pluginId: "plugin",
  directory: "/$projectId",
  parentID: null,
  branchName: null,
  pullRequest: null,
  time: SessionTime(created: 1, updated: updated, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  unseen: unseen,
);
