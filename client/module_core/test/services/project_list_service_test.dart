import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("ProjectListService", () {
    late ProjectListService service;

    setUp(() {
      service = ProjectListService(repository: MockProjectRepository());
    });

    test("active projects lead and sort by last user interaction", () {
      final sorted = service.sortProjects(
        projects: [
          _project(id: "inactive", name: "Inactive", updated: 999, interaction: 999),
          _project(id: "unknown", name: "Zulu", updated: 1, interaction: null),
          _project(id: "older", name: "Beta", updated: 1, interaction: 100),
          _project(id: "newer", name: "Alpha", updated: 1, interaction: 300),
        ],
        activeProjectIds: const {"unknown", "older", "newer"},
        lastUserInteractionAtByProjectId: const {},
      );

      expect(sorted.map((project) => project.id), ["newer", "older", "unknown", "inactive"]);
    });

    test("live values override snapshots and active ties use displayed name then id", () {
      final sorted = service.sortProjects(
        projects: [
          _project(id: "z", name: "Alpha", updated: 1, interaction: 500),
          _project(id: "a", name: "Alpha", updated: 1, interaction: 500),
          _project(id: "beta", name: "Beta", updated: 1, interaction: 900),
        ],
        activeProjectIds: const {"z", "a", "beta"},
        lastUserInteractionAtByProjectId: const {"z": 700, "a": 700, "beta": 600},
      );

      expect(sorted.map((project) => project.id), ["a", "z", "beta"]);
    });

    test("inactive projects preserve updated-desc null-last ordering", () {
      final sorted = service.sortProjects(
        projects: [
          _project(id: "null", name: "A", updated: null, interaction: 999),
          _project(id: "old", name: "Z", updated: 100, interaction: null),
          _project(id: "new", name: "B", updated: 300, interaction: null),
        ],
        activeProjectIds: const {},
        lastUserInteractionAtByProjectId: const {},
      );

      expect(sorted.map((project) => project.id), ["new", "old", "null"]);
    });
  });
}

Project _project({
  required String id,
  required String name,
  required int? updated,
  required int? interaction,
}) {
  return Project(
    id: id,
    name: name,
    path: "/projects/$id",
    time: updated == null ? null : ProjectTime(created: 1, updated: updated),
    lastUserInteractionAt: interaction,
  );
}
