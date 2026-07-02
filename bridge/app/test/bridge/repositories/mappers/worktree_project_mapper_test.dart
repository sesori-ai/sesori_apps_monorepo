import "package:sesori_bridge/src/bridge/repositories/mappers/worktree_project_mapper.dart";
import "package:test/test.dart";

void main() {
  group("WorktreeProjectMapper", () {
    test("rewrites a known worktree directory to its parent project", () {
      final mapper = WorktreeProjectMapper(
        worktreeProjectPaths: const [
          (worktreePath: "/tmp/proj/alpha/.worktrees/session-001", projectId: "/tmp/proj/alpha"),
        ],
      );

      expect(
        mapper.canonicalDirectory("/tmp/proj/alpha/.worktrees/session-001"),
        "/tmp/proj/alpha",
      );
    });

    test("normalizes before matching, so differently-spelled worktree paths still fold", () {
      final mapper = WorktreeProjectMapper(
        worktreeProjectPaths: const [
          (worktreePath: "/tmp/proj/alpha/.worktrees/session-001", projectId: "/tmp/proj/alpha"),
        ],
      );

      expect(
        mapper.canonicalDirectory("/tmp/proj/alpha/.worktrees/session-001/"),
        "/tmp/proj/alpha",
      );
    });

    test("returns the normalized directory unchanged when it is not a worktree", () {
      final mapper = WorktreeProjectMapper(
        worktreeProjectPaths: const [
          (worktreePath: "/tmp/proj/alpha/.worktrees/session-001", projectId: "/tmp/proj/alpha"),
        ],
      );

      expect(mapper.canonicalDirectory("/tmp/proj/beta/."), "/tmp/proj/beta");
    });

    test("empty knows of no worktrees — every directory is its own project", () {
      const mapper = WorktreeProjectMapper.empty();

      expect(mapper.canonicalDirectory("/tmp/proj/alpha/.worktrees/x"), "/tmp/proj/alpha/.worktrees/x");
    });
  });
}
