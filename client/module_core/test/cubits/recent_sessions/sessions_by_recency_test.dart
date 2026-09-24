import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("lists loaded projects' sessions newest first, without hidden ones", () {
    const one = ProjectSummary(id: "one", name: "One", path: "/one", time: null);
    const two = ProjectSummary(id: "two", name: "Two", path: "/two", time: null);
    RecentSessionsLoaded loaded(List<Session> sessions) => RecentSessionsLoaded(
      sourceSessions: sessions,
      visibleSessions: sessions,
      activityBySessionId: const {},
      listStateBySessionId: const {},
    );
    final sessions = sessionsByRecency(
      projects: const [one, two],
      entries: {
        "one": loaded([_session(id: "old", updated: 1), _session(id: "archived", updated: 9)]),
        "two": loaded([_session(id: "new", updated: 5)]),
        "unlisted": loaded([_session(id: "stray", updated: 7)]),
      },
      hiddenSessionIds: const {"archived"},
    );
    expect([for (final item in sessions) (item.project.id, item.session.id)], [("two", "new"), ("one", "old")]);
  });
}

Session _session({required String id, required int updated}) => Session(
  id: id,
  title: id,
  projectID: "project",
  pluginId: "plugin",
  directory: "/project",
  parentID: null,
  branchName: null,
  pullRequest: null,
  time: SessionTime(created: 1, updated: updated, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  autoContinuation: null,
  unseen: false,
);
