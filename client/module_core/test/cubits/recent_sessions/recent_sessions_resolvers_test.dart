import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const running = SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null);
  const waiting = SessionActivityInfo(awaitingInput: true, lastUserActivityAt: null, updatedAt: null);

  RecentSessionsLoaded loaded({required int count, required Map<String, SessionActivityInfo> activity}) {
    final sessions = [for (var index = 1; index <= count; index++) _session(id: "s$index")];
    return RecentSessionsLoaded(
      sourceSessions: sessions,
      visibleSessions: sessions,
      activityBySessionId: activity,
      listStateBySessionId: const {},
    );
  }

  List<String> rows({
    required RecentSessionsLoaded entry,
    required String? selectedSessionId,
    required int idleLimit,
  }) => [
    for (final session in entry.rows(selectedSessionId: selectedSessionId, idleLimit: idleLimit)) session.id,
  ];

  test("every running session shows, in list order, beside the two newest others", () {
    final entry = loaded(
      count: 9,
      activity: {
        for (final id in ["s2", "s4", "s5", "s7", "s9"]) id: running,
      },
    );

    expect(rows(entry: entry, selectedSessionId: null, idleLimit: 2), ["s1", "s2", "s3", "s4", "s5", "s7", "s9"]);
    expect(rows(entry: entry, selectedSessionId: null, idleLimit: 12), hasLength(9));
  });

  test("without running sessions only the two newest show", () {
    expect(rows(entry: loaded(count: 5, activity: const {}), selectedSessionId: null, idleLimit: 2), ["s1", "s2"]);
  });

  test("a session only waiting for input is not running", () {
    expect(rows(entry: loaded(count: 4, activity: const {"s4": waiting}), selectedSessionId: null, idleLimit: 2), [
      "s1",
      "s2",
    ]);
  });

  test("fewer than two other sessions show every session", () {
    expect(
      rows(
        entry: loaded(count: 4, activity: const {"s1": running, "s2": running, "s3": running}),
        selectedSessionId: null,
        idleLimit: 2,
      ),
      [
        "s1",
        "s2",
        "s3",
        "s4",
      ],
    );
  });

  test("the selected session shows in place when it sits further down", () {
    final entry = loaded(count: 6, activity: const {"s6": running});

    expect(rows(entry: entry, selectedSessionId: "s4", idleLimit: 2), ["s1", "s2", "s4", "s6"]);
    expect(rows(entry: entry, selectedSessionId: "s2", idleLimit: 2), ["s1", "s2", "s6"]);
  });
}

Session _session({required String id}) => Session(
  approvalOverride: null,
  autoContinuation: null,
  id: id,
  title: id,
  projectID: "project",
  pluginId: "plugin",
  directory: "/project",
  parentID: null,
  branchName: null,
  pullRequest: null,
  time: null,
  promptDefaults: null,
  lastUserActivityAt: null,
  unseen: false,
);
