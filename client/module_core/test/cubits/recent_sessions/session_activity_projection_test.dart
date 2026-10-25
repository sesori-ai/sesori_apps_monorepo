import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("needsYou and running split active sessions in project order, leaving finished unseen out", () {
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
          archivedSessions: const [],
          activityBySessionId: {
            "running": activity(awaitingInput: false),
            "waiting-one": activity(awaitingInput: true),
          },
          listStateBySessionId: const {},
        ),
        "two": RecentSessionsLoaded(
          sourceSessions: [waitingTwo],
          visibleSessions: [waitingTwo],
          archivedSessions: const [],
          activityBySessionId: {"waiting-two": activity(awaitingInput: true)},
          listStateBySessionId: const {},
        ),
      },
      hiddenSessionIds: const {},
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
          archivedSessions: const [],
          activityBySessionId: const {},
          listStateBySessionId: const {},
        ),
        "two": RecentSessionsLoaded(
          sourceSessions: two,
          visibleSessions: two,
          archivedSessions: const [],
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
      hiddenSessionIds: const {"two-hidden"},
    );

    expect(
      projection.recent.map((item) => (item.project.id, item.entry.session.id)),
      [
        ("two", "two-unseen"),
        ("one", "one-4"),
        ("one", "one-3"),
        ("one", "one-2"),
        ("one", "one-1"),
        ("two", "two-old"),
      ],
    );
    expect(projection.recent.first.entry.isUnseen, isTrue);
  });

  test("a session waiting on the user stays in Activity while its agent is idle", () {
    final waiting = _session(id: "waiting", projectId: "one");
    final projection = SessionActivityProjection.from(
      projects: const [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
      entries: {
        "one": RecentSessionsLoaded(
          sourceSessions: [waiting],
          visibleSessions: [waiting],
          archivedSessions: const [],
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
      hiddenSessionIds: const {},
    );

    expect(projection.needsYou.map((item) => item.entry.session.id), ["waiting"]);
  });
}

Session _session({required String id, required String projectId, bool unseen = false, int updated = 1}) => Session(
  approvalOverride: null,
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
