import "package:sesori_bridge/src/bridge/persistence/tables/projects_table.dart";
import "package:sesori_bridge/src/bridge/repositories/derived_project_builder.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/worktree_project_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const builder = DerivedProjectBuilder();
  const noWorktrees = WorktreeProjectMapper.empty();

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

  group("DerivedProjectBuilder", () {
    test("groups sessions in the same directory into one project, folding times", () {
      final projects = builder.build(
        sessions: [
          session("/tmp/projects/alpha", id: "s1", created: 100, updated: 200),
          session("/tmp/projects/alpha", id: "s2", created: 50, updated: 300),
        ],
        storedProjects: const [],
        worktreeMapper: noWorktrees,
      );

      expect(projects, hasLength(1));
      final project = projects.single;
      expect(project.id, "/tmp/projects/alpha");
      expect(project.name, "alpha");
      // earliest created, latest updated across the project's sessions.
      expect(project.time?.created, 50);
      expect(project.time?.updated, 300);
    });

    test("separate directories produce separate projects", () {
      final projects = builder.build(
        sessions: [
          session("/tmp/projects/alpha", id: "s1", created: 1, updated: 1),
          session("/tmp/projects/beta", id: "s2", created: 1, updated: 1),
        ],
        storedProjects: const [],
        worktreeMapper: noWorktrees,
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
        worktreeMapper: noWorktrees,
      );

      expect(projects, hasLength(1));
      expect(projects.single.id, "/tmp/projects/alpha");
    });

    test("a session in a known worktree folds into its parent project", () {
      final mapper = WorktreeProjectMapper(
        worktreeProjectPaths: const [
          (worktreePath: "/tmp/projects/alpha/.worktrees/session-001", projectId: "/tmp/projects/alpha"),
        ],
      );

      final projects = builder.build(
        sessions: [
          session("/tmp/projects/alpha", id: "s1", created: 100, updated: 100),
          session("/tmp/projects/alpha/.worktrees/session-001", id: "s2", created: 200, updated: 200),
        ],
        storedProjects: const [],
        worktreeMapper: mapper,
      );

      // Both sessions collapse to the parent — no separate worktree project card.
      expect(projects, hasLength(1));
      final project = projects.single;
      expect(project.id, "/tmp/projects/alpha");
      // The worktree session's later timestamp folds into the parent.
      expect(project.time?.updated, 200);
    });

    test("a stored display-name override wins over the basename", () {
      final projects = builder.build(
        sessions: [session("/tmp/projects/alpha", created: 1, updated: 1)],
        storedProjects: const [
          ProjectDto(projectId: "/tmp/projects/alpha", displayName: "My Alpha"),
        ],
        worktreeMapper: noWorktrees,
      );

      expect(projects.single.name, "My Alpha");
    });

    test("an opened folder with no sessions is listed with its openedAt time", () {
      final projects = builder.build(
        sessions: const [],
        storedProjects: const [
          ProjectDto(projectId: "/tmp/projects/empty", openedAt: 4242),
        ],
        worktreeMapper: noWorktrees,
      );

      expect(projects, hasLength(1));
      expect(projects.single.id, "/tmp/projects/empty");
      expect(projects.single.name, "empty");
      expect(projects.single.time?.created, 4242);
      expect(projects.single.time?.updated, 4242);
    });

    test("a bare placeholder row (no openedAt, no sessions) is NOT listed", () {
      final projects = builder.build(
        sessions: const [],
        storedProjects: const [
          ProjectDto(projectId: "/tmp/projects/placeholder"),
        ],
        worktreeMapper: noWorktrees,
      );

      expect(projects, isEmpty);
    });

    test("session timestamps win over the opened-folder timestamp", () {
      final projects = builder.build(
        sessions: [session("/tmp/projects/alpha", created: 100, updated: 900)],
        storedProjects: const [
          ProjectDto(projectId: "/tmp/projects/alpha", openedAt: 1),
        ],
        worktreeMapper: noWorktrees,
      );

      expect(projects.single.time?.created, 100);
      expect(projects.single.time?.updated, 900);
    });
  });
}
