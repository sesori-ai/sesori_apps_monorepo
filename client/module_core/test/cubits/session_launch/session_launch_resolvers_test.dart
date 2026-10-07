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
    required bool sessionsChanged,
    bool inSlot = true,
  }) => resolveHeldLaunchSessions(
    previous: previous,
    launching: launching,
    sessionIds: sessionIds,
    sessions: sessions,
    sessionsChanged: sessionsChanged,
    isInSlot: ({required session}) => inSlot,
  );

  test("a list opened mid-launch shows every session it finds, under the launching row", () {
    final rows = resolve(
      previous: LaunchRows.none,
      launching: [launch],
      sessionIds: const {},
      sessions: [existing],
      sessionsChanged: true,
    );

    expect(rows.placeholders, [launch]);
    expect(rows.heldSessionIds, isEmpty);
  });

  test("a session that arrives before the reply naming its launch is held until the launch resolves", () {
    final opened = resolve(
      previous: LaunchRows.none,
      launching: [launch],
      sessionIds: const {},
      sessions: [existing],
      sessionsChanged: true,
    );
    final arrivedEarly = resolve(
      previous: opened,
      launching: [launch],
      sessionIds: const {},
      sessions: [created, existing],
      sessionsChanged: true,
    );
    expect(arrivedEarly.placeholders, [launch]);
    expect(arrivedEarly.heldSessionIds, {"created"}, reason: "opening it now would find no handoff (#1822)");

    final promoted = resolve(
      previous: arrivedEarly,
      launching: const [],
      sessionIds: const {"launch-1": "created"},
      sessions: [created, existing],
      sessionsChanged: false,
    );
    expect(promoted.placeholders, isEmpty);
    expect(promoted.heldSessionIds, isEmpty);
    expect(promoted.rowKeys, {"created": "launch-1"}, reason: "the session takes the launching row's place");
  });

  test("a new session in a project with no waiting launch is shown at once", () {
    final opened = resolve(
      previous: LaunchRows.none,
      launching: [launch],
      sessionIds: const {},
      sessions: [existing],
      sessionsChanged: true,
    );
    final elsewhere = resolve(
      previous: opened,
      launching: [launch],
      sessionIds: const {},
      sessions: [
        testSession(id: "other").copyWith(projectID: "project-2"),
        existing,
      ],
      sessionsChanged: true,
    );

    expect(elsewhere.heldSessionIds, isEmpty);
  });

  test("a launch promoted before its session arrives keeps one row until the session lands", () {
    final opened = resolve(
      previous: LaunchRows.none,
      launching: [launch],
      sessionIds: const {},
      sessions: [existing],
      sessionsChanged: true,
    );
    final promoted = resolve(
      previous: opened,
      launching: const [],
      sessionIds: const {"launch-1": "created"},
      sessions: [existing],
      sessionsChanged: false,
    );
    expect(promoted.placeholders, [launch]);
    expect(promoted.heldSessionIds, {"created"});

    // The handoff was taken meanwhile, so only the latched association names it.
    final landed = resolve(
      previous: promoted,
      launching: const [],
      sessionIds: const {},
      sessions: [created, existing],
      sessionsChanged: true,
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
        sessionsChanged: true,
      ),
      launching: const [],
      sessionIds: const {"launch-1": "created"},
      sessions: [created, existing],
      sessionsChanged: false,
      inSlot: false,
    );
    expect(promoted.placeholders, [launch]);

    final launchUpdate = resolve(
      previous: promoted,
      launching: const [],
      sessionIds: const {},
      sessions: [created, existing],
      sessionsChanged: false,
      inSlot: false,
    );
    expect(launchUpdate.placeholders, [launch], reason: "only a sessions update moves it");

    final released = resolve(
      previous: launchUpdate,
      launching: const [],
      sessionIds: const {},
      sessions: [created, existing],
      sessionsChanged: true,
      inSlot: false,
    );
    expect(released.placeholders, isEmpty);
    expect(released.heldSessionIds, isEmpty);
    expect(released.rowKeys, isEmpty, reason: "it moves as an ordinary change");
  });

  test("a launch that failed drops its row", () {
    final failed = resolve(
      previous: resolve(
        previous: LaunchRows.none,
        launching: [launch],
        sessionIds: const {},
        sessions: [existing],
        sessionsChanged: true,
      ),
      launching: const [],
      sessionIds: const {},
      sessions: [existing],
      sessionsChanged: false,
    );

    expect(failed.placeholders, isEmpty);
    expect(failed.heldSessionIds, isEmpty);
  });
}
