import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Multi-project behaviour: an ACP agent is a single process with no project
/// list of its own, so the plugin tracks every directory opened as a project.
/// Before this, `getProjects` returned only the launch CWD, so a discovered
/// directory never appeared in the app's project list.
void main() {
  group("AcpPlugin projects", () {
    late FakeAcpProcess fake;
    late AcpPlugin plugin;
    const cwd = "/repo";

    setUp(() {
      fake = FakeAcpProcess();
      plugin = AcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        projectCwd: cwd,
        eventMapper: AcpEventMapper(projectCwd: cwd, agentId: "acp"),
        processFactory: (_) async => fake,
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    test("getProjects starts with just the launch CWD", () async {
      final projects = await plugin.getProjects();
      expect(projects.map((p) => p.id), [cwd]);
    });

    test("getProject registers a newly opened directory; getProjects then lists it", () async {
      const opened = "/Users/x/kustos";
      final project = await plugin.getProject(opened);
      expect(project.id, opened);
      expect(project.name, "kustos");

      final ids = (await plugin.getProjects()).map((p) => p.id).toSet();
      expect(ids, {cwd, opened}, reason: "the opened directory must appear in the list");
    });

    test("getProject normalizes a trailing slash to the same project", () async {
      await plugin.getProject("/Users/x/kustos/");
      final ids = (await plugin.getProjects()).map((p) => p.id).toList();
      expect(ids, contains("/Users/x/kustos"));
      expect(ids.where((id) => id.startsWith("/Users/x/kustos")), hasLength(1));
    });

    // ── Session attribution across projects ───────────────────────────────────

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 50; i++) {
        final matches = fake.written.where((f) => f["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      final frame = await waitForFrame(method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
    }

    Future<void> connect({bool sessionCapabilities = false}) async {
      final connecting = plugin.ensureConnected();
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{
          if (sessionCapabilities) ...{
            "loadSession": true,
            "sessionCapabilities": {"list": <String, dynamic>{}},
          },
        },
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);
    }

    test("a session created in an opened directory is attributed to that project", () async {
      await connect();
      const opened = "/Users/x/kustos";

      final creating = plugin.createSession(
        directory: opened,
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", {"sessionId": "s1"});
      final session = await creating;

      expect(session.projectID, opened, reason: "session belongs to the opened directory, not the launch CWD");
      expect(session.directory, opened);

      // Opening a session in a directory implicitly registers it as a project.
      final ids = (await plugin.getProjects()).map((p) => p.id).toSet();
      expect(ids, containsAll(<String>[cwd, opened]));

      // A running turn surfaces under that project's activity row, not the CWD.
      await plugin.sendPrompt(
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );
      await waitForFrame("session/prompt");
      final running = plugin.getActiveSessionsSummary();
      expect(running, hasLength(1));
      expect(running.single.id, opened);
      expect(running.single.activeSessions.single.id, session.id);
    });

    test("session/load for a prior-run session uses its project's cwd", () async {
      await connect(sessionCapabilities: true);
      const opened = "/Users/x/kustos";

      // Teach the plugin the session->project mapping the way getSessions would
      // (the app lists a project's sessions before opening one), then prompt a
      // session this process never created so a resume-load is forced.
      final listing = plugin.getSessions(opened);
      await respond("session/list", {
        "sessions": [
          {"sessionId": "old-s", "cwd": opened, "title": "Prior"},
        ],
      });
      final sessions = await listing;
      expect(sessions.single.projectID, opened);

      final sending = plugin.sendPrompt(
        sessionId: "old-s",
        parts: const [PluginPromptPart.text(text: "again")],
        variant: null,
        agent: null,
        model: null,
      );
      final loadFrame = await waitForFrame("session/load");
      expect((loadFrame["params"] as Map)["cwd"], opened, reason: "resume-load must use the session's own project cwd");
      fake.emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});

      // sendPrompt drains the (empty) suppressed replay, then dispatches the
      // prompt; await it so the prompt frame exists before we resolve the turn.
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });
  });
}
