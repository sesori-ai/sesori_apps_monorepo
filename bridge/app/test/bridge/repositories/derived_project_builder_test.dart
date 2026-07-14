import "package:sesori_bridge/src/bridge/persistence/tables/projects_table.dart";
import "package:sesori_bridge/src/bridge/repositories/derived_project_builder.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const builder = DerivedProjectBuilder();

  PluginSession session(
    String directory, {
    required int created,
    required int updated,
    String id = "s",
  }) {
    return PluginSession(
      id: id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: null,
      time: PluginSessionTime(created: created, updated: updated, archived: null),
    );
  }

  ProjectDto storedProject(String path, {String? displayName, int createdAt = 1, int updatedAt = 1}) {
    return ProjectDto(
      projectId: path,
      path: path,
      displayName: displayName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      projectionUpdatedAt: updatedAt,
    );
  }

  group("DerivedProjectBuilder", () {
    test("groups sessions in the same directory into project identity", () {
      final projects = builder.build(
        sessions: [
          session("/tmp/projects/alpha", id: "s1", created: 100, updated: 200),
          session("/tmp/projects/alpha", id: "s2", created: 50, updated: 300),
        ],
        storedProjects: const [],
        projectPathBySessionId: const {},
      );

      expect(projects, hasLength(1));
      final project = projects.single;
      expect(project.id, "/tmp/projects/alpha");
      expect(project.name, "alpha");
      expect(project.time, isNull);
    });

    test("separate directories produce separate projects", () {
      final projects = builder.build(
        sessions: [
          session("/tmp/projects/alpha", id: "s1", created: 1, updated: 1),
          session("/tmp/projects/beta", id: "s2", created: 1, updated: 1),
        ],
        storedProjects: const [],
        projectPathBySessionId: const {},
      );

      expect(projects.map((p) => p.id), containsAll(["/tmp/projects/alpha", "/tmp/projects/beta"]));
      expect(projects, hasLength(2));
    });

    test("differently-spelled directories collapse to one normalized project", () {
      final projects = builder.build(
        sessions: [
          session("/tmp/projects/alpha", id: "s1", created: 1, updated: 1),
          session("/tmp/projects/alpha/", id: "s2", created: 1, updated: 1),
          session("/tmp/projects/alpha/.", id: "s3", created: 1, updated: 1),
        ],
        storedProjects: const [],
        projectPathBySessionId: const {},
      );

      expect(projects, hasLength(1));
      expect(projects.single.id, "/tmp/projects/alpha");
    });

    test("a session with a stored project attribution groups under that project, not its own cwd", () {
      final projects = builder.build(
        sessions: [
          session("/tmp/projects/alpha", id: "s1", created: 100, updated: 100),
          session("/tmp/projects/alpha/.worktrees/session-001", id: "s2", created: 200, updated: 200),
        ],
        storedProjects: const [],
        // The bridge recorded s2 under the project the user opened; the row's
        // project path wins over the session's worktree cwd.
        projectPathBySessionId: const {"s2": "/tmp/projects/alpha"},
      );

      // Both sessions collapse to the parent — no separate worktree project card.
      expect(projects, hasLength(1));
      expect(projects.single.id, "/tmp/projects/alpha");
    });

    test("a stored display-name override wins over the basename", () {
      final projects = builder.build(
        sessions: [session("/tmp/projects/alpha", created: 1, updated: 1)],
        storedProjects: [
          storedProject("/tmp/projects/alpha", displayName: "My Alpha"),
        ],
        projectPathBySessionId: const {},
      );

      expect(projects.single.name, "My Alpha");
    });

    test("a stored folder with no sessions is listed without activity evidence", () {
      final projects = builder.build(
        sessions: const [],
        storedProjects: [
          storedProject("/tmp/projects/empty", createdAt: 4242, updatedAt: 4242),
        ],
        projectPathBySessionId: const {},
      );

      expect(projects, hasLength(1));
      expect(projects.single.id, "/tmp/projects/empty");
      expect(projects.single.name, "empty");
      expect(projects.single.time, isNull);
    });
  });
}
