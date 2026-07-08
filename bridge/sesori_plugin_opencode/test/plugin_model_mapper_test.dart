import "package:opencode_plugin/src/message_part_mapper.dart";
import "package:opencode_plugin/src/models/openapi/project.g.dart";
import "package:opencode_plugin/src/plugin_model_mapper.dart";
import "package:test/test.dart";

void main() {
  const mapper = PluginModelMapper(messagePartMapper: MessagePartMapper());

  Project project({
    required String worktree,
    List<String> sandboxes = const <String>[],
    String? name,
  }) {
    return Project(
      id: "p1",
      worktree: worktree,
      vcs: "git",
      name: name,
      icon: null,
      commands: null,
      time: const ProjectTime(created: 1, updated: 2, initialized: null),
      sandboxes: sandboxes,
    );
  }

  group("mapProject id resolution", () {
    test("uses the worktree when no requested directory is given", () {
      final result = mapper.mapProject(project(worktree: "/repo"));

      expect(result.id, equals("/repo"));
    });

    test("uses the worktree when the requested directory matches it", () {
      final result = mapper.mapProject(
        project(worktree: "/repo"),
        requestedDirectory: "/repo",
      );

      expect(result.id, equals("/repo"));
    });

    test("keys off the requested directory when the folder was moved (worktree stale, requested is a sandbox)", () {
      // OpenCode identifies a git project by git identity, so opening the moved
      // repo at /new-repo resolves to the same project but returns the stale
      // primary worktree /old-repo while listing /new-repo as a sandbox.
      final result = mapper.mapProject(
        project(worktree: "/old-repo", sandboxes: ["/new-repo"]),
        requestedDirectory: "/new-repo",
      );

      expect(result.id, equals("/new-repo"));
    });

    test("falls back to the worktree when the requested directory is unknown to the project", () {
      final result = mapper.mapProject(
        project(worktree: "/old-repo", sandboxes: ["/other"]),
        requestedDirectory: "/new-repo",
      );

      expect(result.id, equals("/old-repo"));
    });

    test("normalizes path separators when comparing against sandboxes", () {
      final result = mapper.mapProject(
        project(worktree: r"C:\old-repo", sandboxes: [r"C:\new-repo"]),
        requestedDirectory: "C:/new-repo",
      );

      expect(result.id, equals(r"C:\new-repo"));
    });
  });
}
