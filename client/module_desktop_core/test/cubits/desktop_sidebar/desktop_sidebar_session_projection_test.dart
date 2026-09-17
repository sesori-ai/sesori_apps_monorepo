import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("projects every running or live-unseen active session in owner order", () {
    final projectTwoUnseen = _session(id: "two-unseen", projectId: "two", unseen: true);
    final projectTwoCleared = _session(id: "two-cleared", projectId: "two", unseen: true);
    final projectOneRunning = _session(id: "one-running", projectId: "one");
    final projection = DesktopSidebarSessionProjection.from(
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
    );

    expect(projection.activityGroups.map((group) => group.project.id), ["two", "one"]);
    expect(projection.activityGroups[0].sessions.map((item) => item.session.id), ["two-unseen"]);
    expect(projection.activityGroups[0].sessions.single.isUnseen, isTrue);
    expect(projection.activityGroups[1].sessions.single.session.id, "one-running");
    expect(projection.activityGroups[1].sessions.single.isRunning, isTrue);
    expect(projection.activityGroups[1].sessions.single.isAwaitingInput, isTrue);
  });

  test("ordinary rows exclude activity before choosing three plus the selected session", () {
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
    final projection = DesktopSidebarSessionProjection.from(
      projects: const [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
      entries: {"one": loaded},
    );

    expect(projection.activityGroups.single.sessions.single.session.id, "priority");
    expect(
      projection
          .ordinaryRows(projectId: "one", loaded: loaded, selectedSessionId: "session-5")
          .map((session) => session.id),
      ["session-2", "session-3", "session-4", "session-5"],
    );
    expect(
      projection
          .ordinaryRows(projectId: "one", loaded: loaded, selectedSessionId: "priority")
          .map((session) => session.id),
      ["session-2", "session-3", "session-4"],
    );
  });
}

Session _session({required String id, required String projectId, bool unseen = false}) => Session(
  id: id,
  title: id,
  projectID: projectId,
  pluginId: "plugin",
  directory: "/$projectId",
  parentID: null,
  branchName: null,
  pullRequest: null,
  time: const SessionTime(created: 1, updated: 1, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  unseen: unseen,
);
