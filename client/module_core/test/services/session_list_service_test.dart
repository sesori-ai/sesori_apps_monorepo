import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("SessionListService", () {
    late SessionListService service;

    setUp(() {
      service = SessionListService(repository: MockProjectRepository());
    });

    test("active sessions lead and sort by last user interaction", () {
      final sorted = service.visibleSessions(
        sessions: [
          _session(id: "inactive", title: "Inactive", updated: 999, interaction: 999),
          _session(id: "unknown", title: "Zulu", updated: 1, interaction: null),
          _session(id: "older", title: "Beta", updated: 1, interaction: 100),
          _session(id: "newer", title: "Alpha", updated: 1, interaction: 300),
        ],
        showArchived: true,
        activeSessionIds: const {"unknown", "older", "newer"},
        lastUserInteractionAtBySessionId: const {},
      );

      expect(sorted.map((session) => session.id), ["newer", "older", "unknown", "inactive"]);
    });

    test("live values override snapshots and active ties use title then id", () {
      final sorted = service.visibleSessions(
        sessions: [
          _session(id: "z", title: "Alpha", updated: 1, interaction: 500),
          _session(id: "a", title: "Alpha", updated: 1, interaction: 500),
          _session(id: "beta", title: "Beta", updated: 1, interaction: 900),
        ],
        showArchived: true,
        activeSessionIds: const {"z", "a", "beta"},
        lastUserInteractionAtBySessionId: const {"z": 700, "a": 700, "beta": 600},
      );

      expect(sorted.map((session) => session.id), ["a", "z", "beta"]);
    });

    test("inactive sessions preserve the old updated-desc comparator", () {
      final sorted = service.visibleSessions(
        sessions: [
          _session(id: "old", title: "Old", updated: 100, interaction: 999),
          _session(id: "missing", title: "Missing", updated: null, interaction: 999),
          _session(id: "new", title: "New", updated: 300, interaction: null),
        ],
        showArchived: true,
        activeSessionIds: const {},
        lastUserInteractionAtBySessionId: const {},
      );

      expect(sorted.map((session) => session.id), ["new", "old", "missing"]);
    });
  });
}

Session _session({
  required String id,
  required String title,
  required int? updated,
  required int? interaction,
}) {
  return Session(
    id: id,
    pluginId: legacyMissingPluginId,
    projectID: "p1",
    directory: "/projects/p1",
    parentID: null,
    title: title,
    time: updated == null ? null : SessionTime(created: 1, updated: updated, archived: null),
    pullRequest: null,
    promptDefaults: null,
    lastUserInteractionAt: interaction,
  );
}
