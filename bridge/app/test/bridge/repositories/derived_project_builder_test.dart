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
      summary: null,
    );
  }

  ProjectDto storedProject(String path, {String? displayName, int createdAt = 1, int updatedAt = 1}) {
    return ProjectDto(
      projectId: path,
      path: path,
      displayName: displayName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  group("DerivedProjectBuilder", () {
    test("groups sessions in the same directory without folding their times", () {
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
      expect(project.project.id, "/tmp/projects/alpha");
      expect(project.project.name, "alpha");
      expect(project.project.time, isNull);
      expect(project.sessionActivities.map((time) => time.created), [100, 50]);
      expect(project.sessionActivities.map((time) => time.updated), [200, 300]);
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

      expect(projects.map((p) => p.project.id), containsAll(["/tmp/projects/alpha", "/tmp/projects/beta"]));
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
      expect(projects.single.project.id, "/tmp/projects/alpha");
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
      final project = projects.single;
      expect(project.project.id, "/tmp/projects/alpha");
      expect(project.sessionActivities.map((time) => time.updated), [100, 200]);
    });

    test("a stored display-name override wins over the basename", () {
      final projects = builder.build(
        sessions: [session("/tmp/projects/alpha", created: 1, updated: 1)],
        storedProjects: [
          storedProject("/tmp/projects/alpha", displayName: "My Alpha"),
        ],
        projectPathBySessionId: const {},
      );

      expect(projects.single.project.name, "My Alpha");
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
      expect(projects.single.project.id, "/tmp/projects/empty");
      expect(projects.single.project.name, "empty");
      expect(projects.single.project.time, isNull);
      expect(projects.single.sessionActivities, isEmpty);
    });

    test("session timestamps remain raw evidence beside stored projects", () {
      final projects = builder.build(
        sessions: [session("/tmp/projects/alpha", created: 100, updated: 900)],
        storedProjects: [
          storedProject("/tmp/projects/alpha", createdAt: 1, updatedAt: 1),
        ],
        projectPathBySessionId: const {},
      );

      expect(projects.single.sessionActivities.single.created, 100);
      expect(projects.single.sessionActivities.single.updated, 900);
    });
  });
}
