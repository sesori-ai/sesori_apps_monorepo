import "package:sesori_bridge/src/bridge/repositories/derived_session_builder.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const builder = DerivedSessionBuilder();

  PluginSession session(String directory, {required String id}) {
    return PluginSession(
      id: id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: null,
      time: const PluginSessionTime(created: 1, updated: 1, archived: null),
    );
  }

  group("DerivedSessionBuilder", () {
    test("a rowless session belongs to its own directory", () {
      final sessions = builder.build(
        projectId: "/tmp/proj/alpha",
        sessions: [
          session("/tmp/proj/alpha", id: "a1"),
          session("/tmp/proj/beta", id: "b1"),
        ],
        projectPathBySessionId: const {},
      );

      expect(sessions.map((s) => s.id), ["a1"]);
    });

    test("a stored attribution wins over the session's own cwd", () {
      final sessions = builder.build(
        projectId: "/tmp/proj/alpha",
        sessions: [
          session("/tmp/proj/alpha", id: "a1"),
          // Reported under its worktree cwd, but the bridge recorded it under
          // the parent project at creation.
          session("/tmp/proj/alpha/.worktrees/session-001", id: "w1"),
        ],
        projectPathBySessionId: const {"w1": "/tmp/proj/alpha"},
      );

      expect(sessions.map((s) => s.id), ["a1", "w1"]);
    });

    test("a session attributed to another project is excluded even when its cwd matches", () {
      final sessions = builder.build(
        projectId: "/tmp/proj/alpha/.worktrees/session-001",
        sessions: [
          session("/tmp/proj/alpha/.worktrees/session-001", id: "w1"),
        ],
        projectPathBySessionId: const {"w1": "/tmp/proj/alpha"},
      );

      expect(sessions, isEmpty);
    });

    test("directory spellings normalize before matching", () {
      final sessions = builder.build(
        projectId: "/tmp/proj/alpha/",
        sessions: [session("/tmp/proj/alpha", id: "a1")],
        projectPathBySessionId: const {},
      );

      expect(sessions.map((s) => s.id), ["a1"]);
    });
  });
}
