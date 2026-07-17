import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Derived-project behaviour: an ACP agent is a single process with no project
/// list of its own, so the bridge derives projects from [AcpPlugin.listAllSessions]
/// and owns all project/session persistence. These tests cover the enumeration
/// contract — the union of the spec's unfiltered `session/list` with
/// per-directory scans over the bridge's known directories — plus the flows
/// that depend on the resulting attribution (resume cwd, activity grouping,
/// catalog probing).
void main() {
  group("AcpPlugin session enumeration", () {
    final fakes = <FakeAcpProcess>[];
    late _RegistryCapturingAcpPlugin plugin;
    const cwd = "/repo";

    setUp(() {
      fakes.clear();
      plugin = _RegistryCapturingAcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp", pluginId: "acp"),
        processFactory: (_) async {
          final fake = FakeAcpProcess();
          fakes.add(fake);
          return fake;
        },
      );
    });

    tearDown(() async {
      await plugin.dispose();
      for (final fake in fakes) {
        await fake.close();
      }
    });

    FakeAcpProcess fake() => fakes.last;

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    // Frames respond() has already answered, keyed per fake process (request
    // ids restart at 1 for every spawned client, so a bare id would collide
    // across a respawn). Lets a second same-method request wait for ITS frame
    // instead of re-answering the first one.
    final answered = <(FakeAcpProcess, Object?)>{};

    // Polls with a small real delay: a serialized turn's dispatch can sit
    // behind the resume-load replay drain (~250ms of wall-clock quiet time),
    // which zero-duration pumps never outlast.
    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 400; i++) {
        final matches = fake().written.where((f) => f["method"] == method && !answered.contains((fake(), f["id"])));
        if (matches.isNotEmpty) return matches.last;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      final frame = await waitForFrame(method);
      answered.add((fake(), frame["id"]));
      fake().emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
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

    /// Auto-answers every `session/list` request until stopped: an unfiltered
    /// request gets [bare]'s result (or an error when null — a non-spec agent
    /// that requires `cwd`), a cwd-filtered request gets its [byCwd] sessions
    /// (empty when absent). Returns a stop function; counts unfiltered
    /// attempts via [onBareRequest].
    void Function() autoListResponder({
      Map<String, dynamic> Function()? bare,
      Map<String, List<Map<String, dynamic>>> byCwd = const {},
      void Function()? onBareRequest,
    }) {
      // Scoped to the CURRENT fake: request ids restart per spawned client, so
      // scanning a dead process's frames would re-answer stale ids on the live
      // one.
      final answered = <Object?>{};
      var running = true;
      unawaited(() async {
        while (running) {
          final frames = fake().written.where((f) => f["method"] == "session/list").toList(growable: false);
          for (final frame in frames) {
            if (!answered.add(frame["id"])) continue;
            final params = (frame["params"] as Map?)?.cast<String, dynamic>() ?? const {};
            final requestedCwd = params["cwd"] as String?;
            if (requestedCwd == null) {
              onBareRequest?.call();
              if (bare == null) {
                fake().emit({
                  "jsonrpc": "2.0",
                  "id": frame["id"],
                  "error": {"code": -32602, "message": "cwd is required"},
                });
              } else {
                fake().emit({"jsonrpc": "2.0", "id": frame["id"], "result": bare()});
              }
            } else {
              fake().emit({
                "jsonrpc": "2.0",
                "id": frame["id"],
                "result": {"sessions": byCwd[requestedCwd] ?? <Object?>[]},
              });
            }
          }
          await pump();
        }
      }());
      return () => running = false;
    }

    test("without the list capability, listAllSessions is empty", () async {
      await connect();
      expect(await plugin.listAllSessions(knownDirectories: const {}), isEmpty);
    });

    test("unions the unfiltered list with per-directory scans and dedupes by id", () async {
      await connect(sessionCapabilities: true);
      const known = "/Users/x/kustos";

      final stop = autoListResponder(
        // The spec's global list also knows a session in a directory the
        // bridge never recorded (created via the agent's own CLI)...
        bare: () => {
          "sessions": [
            {"sessionId": "outside", "cwd": "/elsewhere/lab", "title": "Outside"},
            // ...and re-reports a known-directory session (must not duplicate).
            {"sessionId": "known-s", "cwd": known, "title": "Known"},
          ],
        },
        byCwd: {
          known: [
            {"sessionId": "known-s", "cwd": known, "title": "Known"},
          ],
        },
      );
      final sessions = await plugin.listAllSessions(knownDirectories: const {known});
      stop();

      expect(sessions.map((s) => s.id).toSet(), {"outside", "known-s"});
      final outside = sessions.singleWhere((s) => s.id == "outside");
      expect(outside.directory, "/elsewhere/lab");
      expect(outside.projectID, "/elsewhere/lab");
      final knownSession = sessions.singleWhere((s) => s.id == "known-s");
      expect(knownSession.directory, known);

      // Both the launch directory and the bridge-known directory were scanned.
      final listedCwds = fake().written
          .where((f) => f["method"] == "session/list")
          .map((f) => ((f["params"] as Map?) ?? const {})["cwd"])
          .toSet();
      expect(listedCwds, containsAll(<Object?>[null, cwd, known]));
    });

    test("a rejected unfiltered list is remembered for the connection, forgotten after reset", () async {
      await connect(sessionCapabilities: true);
      var bareAttempts = 0;
      final stop = autoListResponder(onBareRequest: () => bareAttempts++);

      await plugin.listAllSessions(knownDirectories: const {});
      expect(bareAttempts, 1, reason: "the spec path is attempted first");
      await plugin.listAllSessions(knownDirectories: const {});
      expect(bareAttempts, 1, reason: "a rejecting agent is not re-asked on this connection");
      stop();

      // A respawned agent may support it — the memo must reset with the
      // connection.
      fake().exit(1);
      await pump();
      await plugin.resetConnectionAfterExit();
      final reconnecting = plugin.ensureConnected();
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": {
          "loadSession": true,
          "sessionCapabilities": {"list": <String, dynamic>{}},
        },
        "authMethods": <Object?>[],
      });
      expect(await reconnecting, isTrue);

      final stopSecond = autoListResponder(onBareRequest: () => bareAttempts++);
      await plugin.listAllSessions(knownDirectories: const {});
      stopSecond();
      expect(bareAttempts, 2, reason: "the fresh process is probed again");
    });

    test("a transient unfiltered-list failure is retried, not memoized", () async {
      await connect(sessionCapabilities: true);
      var bareAttempts = 0;
      // The bare request fails with a TRANSIENT error (-32000, not a
      // method/params rejection) each time; per-directory scans return empty.
      final answered = <Object?>{};
      var running = true;
      unawaited(() async {
        while (running) {
          for (final frame in fake().written.where((f) => f["method"] == "session/list").toList(growable: false)) {
            if (!answered.add(frame["id"])) continue;
            final params = (frame["params"] as Map?)?.cast<String, dynamic>() ?? const {};
            if (params["cwd"] == null) {
              bareAttempts++;
              fake().emit({
                "jsonrpc": "2.0",
                "id": frame["id"],
                "error": {"code": -32000, "message": "boom"},
              });
            } else {
              fake().emit({
                "jsonrpc": "2.0",
                "id": frame["id"],
                "result": {"sessions": <Object?>[]},
              });
            }
          }
          await pump();
        }
      }());

      await plugin.listAllSessions(knownDirectories: const {});
      await plugin.listAllSessions(knownDirectories: const {});
      running = false;
      expect(bareAttempts, 2, reason: "a transient error must not be memoized; the unfiltered form is retried");
    });

    test("a mid-pagination error does not memoize the unfiltered form as unsupported", () async {
      await connect(sessionCapabilities: true);
      var bareFirstPages = 0;
      final answered = <Object?>{};
      var running = true;
      unawaited(() async {
        while (running) {
          for (final frame in fake().written.where((f) => f["method"] == "session/list").toList(growable: false)) {
            if (!answered.add(frame["id"])) continue;
            final params = (frame["params"] as Map?)?.cast<String, dynamic>() ?? const {};
            if (params["cwd"] == null) {
              if (params["cursor"] == null) {
                bareFirstPages++;
                // First page succeeds (proving the unfiltered form works)...
                fake().emit({
                  "jsonrpc": "2.0",
                  "id": frame["id"],
                  "result": {
                    "sessions": [
                      {"sessionId": "s1", "cwd": "/x"},
                    ],
                    "nextCursor": "p2",
                  },
                });
              } else {
                // ...then page 2 fails with a pagination-specific -32602.
                fake().emit({
                  "jsonrpc": "2.0",
                  "id": frame["id"],
                  "error": {"code": -32602, "message": "bad cursor"},
                });
              }
            } else {
              fake().emit({
                "jsonrpc": "2.0",
                "id": frame["id"],
                "result": {"sessions": <Object?>[]},
              });
            }
          }
          await pump();
        }
      }());

      final first = await plugin.listAllSessions(knownDirectories: const {});
      expect(first.map((s) => s.id), contains("s1"), reason: "the successful first page is still returned");
      // A second enumeration must retry the unfiltered form — a page-2 error is
      // not proof the form is unsupported.
      await plugin.listAllSessions(knownDirectories: const {});
      running = false;
      expect(bareFirstPages, 2, reason: "a mid-pagination -32602 must not memoize the unfiltered form");
    });

    test("follows nextCursor pagination and parses both timestamp shapes", () async {
      await connect(sessionCapabilities: true);

      // Answer the unfiltered probe with an error, then serve two pages for
      // the launch-directory scan.
      unawaited(() async {
        final answered = <Object?>{};
        while (answered.length < 3) {
          for (final frame in fake().written.where((f) => f["method"] == "session/list").toList(growable: false)) {
            if (!answered.add(frame["id"])) continue;
            final params = (frame["params"] as Map?)?.cast<String, dynamic>() ?? const {};
            if (params["cwd"] == null) {
              fake().emit({
                "jsonrpc": "2.0",
                "id": frame["id"],
                "error": {"code": -32602, "message": "cwd is required"},
              });
            } else if (params["cursor"] == null) {
              fake().emit({
                "jsonrpc": "2.0",
                "id": frame["id"],
                "result": {
                  "sessions": [
                    // Spec shape: ISO 8601 updatedAt.
                    {"sessionId": "s1", "cwd": cwd, "updatedAt": "2026-07-01T10:00:00Z"},
                  ],
                  "nextCursor": "page-2",
                },
              });
            } else {
              expect(params["cursor"], "page-2");
              fake().emit({
                "jsonrpc": "2.0",
                "id": frame["id"],
                "result": {
                  "sessions": [
                    // Live cursor-agent shape: epoch milliseconds.
                    {"sessionId": "s2", "cwd": cwd, "updatedAt": 1751364000000},
                  ],
                },
              });
            }
          }
          await pump();
        }
      }());

      final sessions = await plugin.listAllSessions(knownDirectories: const {});
      expect(sessions.map((s) => s.id).toSet(), {"s1", "s2"});
      final s1 = sessions.singleWhere((s) => s.id == "s1");
      expect(
        s1.time?.updated,
        DateTime.utc(2026, 7, 1, 10).millisecondsSinceEpoch,
        reason: "ISO 8601 updatedAt must parse",
      );
      final s2 = sessions.singleWhere((s) => s.id == "s2");
      expect(s2.time?.updated, 1751364000000, reason: "epoch-ms updatedAt must parse");
    });

    test("a cwd-scoped scan repairs a session the unfiltered list left on the launch dir", () async {
      await connect(sessionCapabilities: true);
      const home = "/Users/x/kustos";
      // The unfiltered (spec) list returns the session with NO cwd, so it is
      // first attributed to the launch directory; the per-directory scan of a
      // bridge-known directory then confirms its real cwd.
      final stop = autoListResponder(
        bare: () => {
          "sessions": [
            {"sessionId": "s1", "title": "One"},
          ],
        },
        byCwd: {
          home: [
            {"sessionId": "s1", "title": "One"},
          ],
        },
      );
      final sessions = await plugin.listAllSessions(knownDirectories: const {home});

      final s1 = sessions.singleWhere((s) => s.id == "s1");
      expect(s1.directory, home, reason: "the cwd-scoped hit must replace the launch fallback");
      expect(s1.projectID, home);

      final sending = plugin.sendPrompt(
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "resume me")],
        variant: null,
        agent: null,
        model: null,
      );
      final loadFrame = await waitForFrame("session/load");
      stop();
      expect(
        (loadFrame["params"] as Map)["cwd"],
        home,
        reason: "a cwd-scoped hit stays authoritative when the item omits cwd",
      );
      fake().emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });

    test("a blank cwd falls back to the launch directory, not the process cwd", () async {
      await connect(sessionCapabilities: true);
      // The unfiltered list returns a blank (whitespace) cwd and nothing else
      // scans up that session, so it must land on the launch directory — a bare
      // `?? ` would let "" through to normalizeProjectDirectory → the process
      // cwd, which is neither the launch dir nor a real project.
      final stop = autoListResponder(
        bare: () => {
          "sessions": [
            {"sessionId": "s1", "cwd": "   ", "title": "One"},
          ],
        },
      );
      final sessions = await plugin.listAllSessions(knownDirectories: const {});
      stop();

      final s1 = sessions.singleWhere((s) => s.id == "s1");
      expect(s1.directory, cwd, reason: "a blank cwd must fall back to the launch directory");
    });

    test("a session/prompt rejection after dispatch surfaces a session error, not a silent idle", () async {
      await connect();
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", {"sessionId": "s1"});
      await creating;

      final events = <BridgeSseEvent>[];
      final sub = plugin.events.listen(events.add);
      addTearDown(sub.cancel);

      await plugin.sendPrompt(
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );
      final promptFrame = await waitForFrame("session/prompt");
      // The agent rejects the prompt AFTER the frame was accepted.
      fake().emit({
        "jsonrpc": "2.0",
        "id": promptFrame["id"],
        "error": {"code": -32000, "message": "boom"},
      });
      await pump();
      await pump();

      expect(
        events.whereType<BridgeSseSessionError>(),
        isNotEmpty,
        reason: "a post-dispatch prompt rejection must surface as an error, not a silent idle",
      );
    });

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

      // Teach the plugin the session->directory mapping the way an
      // enumeration would (the app lists a project's sessions before opening
      // one), then prompt a session this process never created so a
      // resume-load is forced.
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
      fake().emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});

      // sendPrompt drains the (empty) suppressed replay, then dispatches the
      // prompt; await it so the prompt frame exists before we resolve the turn.
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });

    test("a prompt to a never-enumerated session warms attribution before the load", () async {
      await connect(sessionCapabilities: true);
      const home = "/Users/x/kustos";

      // The plugin has never seen "cold-s" (no create, no enumeration this
      // run — e.g. a prompt straight from a push notification). The pre-load
      // enumeration must discover its directory so the resume-load runs there
      // instead of the launch directory.
      final stop = autoListResponder(
        bare: () => {
          "sessions": [
            {"sessionId": "cold-s", "cwd": home, "title": "Cold"},
          ],
        },
      );

      final sending = plugin.sendPrompt(
        sessionId: "cold-s",
        parts: const [PluginPromptPart.text(text: "resume me")],
        variant: null,
        agent: null,
        model: null,
      );
      final loadFrame = await waitForFrame("session/load");
      stop();
      expect(
        (loadFrame["params"] as Map)["cwd"],
        home,
        reason: "the warm-up enumeration must teach the load its real cwd",
      );
      fake().emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });

    test("the pre-resume warm-up scans directories the bridge hinted earlier", () async {
      await connect(sessionCapabilities: true);
      const home = "/Users/x/kustos";

      // The bridge hints at a known directory during a routine enumeration
      // that finds nothing yet, on an agent WITHOUT the unfiltered list form.
      final stopFirst = autoListResponder();
      await plugin.listAllSessions(knownDirectories: const {home});
      stopFirst();

      // A prior-run session in that directory becomes visible later (it was
      // never enumerated, so the plugin has no per-session attribution). The
      // hint-less warm-up must still scan the remembered directory so the
      // resume-load runs in the session's own cwd.
      final stopSecond = autoListResponder(
        byCwd: {
          home: [
            {"sessionId": "cold-s", "cwd": home, "title": "Cold"},
          ],
        },
      );
      final sending = plugin.sendPrompt(
        sessionId: "cold-s",
        parts: const [PluginPromptPart.text(text: "resume me")],
        variant: null,
        agent: null,
        model: null,
      );
      final loadFrame = await waitForFrame("session/load");
      stopSecond();
      expect(
        (loadFrame["params"] as Map)["cwd"],
        home,
        reason: "the remembered bridge hint must teach the load its real cwd",
      );
      fake().emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });

    test("a primed directory is used for the resume-load without any enumeration", () async {
      await connect(sessionCapabilities: true);
      const stored = "/Users/x/kustos";

      // The bridge feeds its stored attribution (worktree/project path) before
      // the prompt — no warm-up enumeration is needed for the load to run in
      // the session's own cwd.
      plugin.primeSessionDirectory(sessionId: "cold-s", directory: stored);

      final sending = plugin.sendPrompt(
        sessionId: "cold-s",
        parts: const [PluginPromptPart.text(text: "resume me")],
        variant: null,
        agent: null,
        model: null,
      );
      final loadFrame = await waitForFrame("session/load");
      expect((loadFrame["params"] as Map)["cwd"], stored);
      expect(
        fake().written.where((f) => f["method"] == "session/list"),
        isEmpty,
        reason: "a primed directory removes the need for the warm-up enumeration",
      );
      fake().emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });

    test("a prime repairs a launch-directory fallback from enumeration", () async {
      await connect(sessionCapabilities: true);
      const stored = "/Users/x/kustos";

      final stop = autoListResponder(
        bare: () => {
          "sessions": [
            {"sessionId": "cold-s", "title": "Cold"},
          ],
        },
      );
      final sessions = await plugin.listAllSessions(knownDirectories: const {});
      stop();
      expect(sessions.single.directory, cwd);

      plugin.primeSessionDirectory(sessionId: "cold-s", directory: stored);
      final stopAgain = autoListResponder(
        bare: () => {
          "sessions": [
            {"sessionId": "cold-s", "title": "Cold"},
          ],
        },
      );
      await plugin.listAllSessions(knownDirectories: const {});
      stopAgain();
      expect(
        plugin.eventMapper.projectForSession("cold-s"),
        stored,
        reason: "an unfiltered fallback must not replace established event attribution",
      );

      final sending = plugin.sendPrompt(
        sessionId: "cold-s",
        parts: const [PluginPromptPart.text(text: "resume me")],
        variant: null,
        agent: null,
        model: null,
      );
      final loadFrame = await waitForFrame("session/load");
      expect(
        (loadFrame["params"] as Map)["cwd"],
        stored,
        reason: "the stored bridge prime must repair a scan-only fallback",
      );
      fake().emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });

    test("a prime does not override an agent-reported directory", () async {
      await connect(sessionCapabilities: true);
      const opened = "/Users/x/kustos";

      // The agent itself reported the session's cwd via enumeration…
      final listing = plugin.getSessions(opened);
      await respond("session/list", {
        "sessions": [
          {"sessionId": "old-s", "cwd": opened, "title": "Prior"},
        ],
      });
      await listing;

      // …so a later (hypothetically stale) bridge prime must not replace it.
      plugin.primeSessionDirectory(sessionId: "old-s", directory: "/somewhere/stale");

      final sending = plugin.sendPrompt(
        sessionId: "old-s",
        parts: const [PluginPromptPart.text(text: "again")],
        variant: null,
        agent: null,
        model: null,
      );
      final loadFrame = await waitForFrame("session/load");
      expect(
        (loadFrame["params"] as Map)["cwd"],
        opened,
        reason: "the agent-reported cwd stays authoritative over a bridge hint",
      );
      fake().emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});
      await sending;
      await respond("session/prompt", {"stopReason": "end_turn"});
    });

    test("a broken history replay surfaces as a typed failure, not an empty thread", () async {
      final failingPlugin = AcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp", pluginId: "acp"),
        processFactory: _throwReplayProcess,
      );
      addTearDown(failingPlugin.dispose);
      // Prime the directory so the replay needs no warm-up enumeration (and
      // therefore no main-client connection).
      failingPlugin.primeSessionDirectory(sessionId: "s-x", directory: cwd);

      try {
        await failingPlugin.getSessionMessages(
          "s-x",
          acceptedCommands: const [],
        );
        fail("Expected history replay to fail");
      } on PluginOperationException catch (_, stackTrace) {
        expect(
          stackTrace.toString(),
          contains("_throwReplayProcess"),
          reason: "the typed wrapper must retain the original replay failure stack",
        );
      }
    });

    test("an agent without loadSession serves an empty thread, not a failure", () async {
      plugin.primeSessionDirectory(sessionId: "s-x", directory: cwd);

      final loading = plugin.getSessionMessages(
        "s-x",
        acceptedCommands: const [],
      );
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });

      expect(await loading, isEmpty, reason: "no history capability = empty thread; the session stays usable");
    });

    test("listAllSessions scans the launch directory and every known directory", () async {
      await connect(sessionCapabilities: true);
      const opened = "/Users/x/kustos";

      // Empty everywhere: enumeration still scans both the launch directory
      // and the directory supplied by the bridge.
      final stop = autoListResponder();
      await plugin.listAllSessions(knownDirectories: const {opened});
      stop();

      final listedCwds = fake().written
          .where((f) => f["method"] == "session/list")
          .map((f) => ((f["params"] as Map?) ?? const {})["cwd"])
          .toSet();
      expect(
        listedCwds,
        containsAll(<Object?>[cwd, opened]),
        reason: "enumeration must scan the launch CWD AND the requested project",
      );
    });

    test("getProjectQuestions only reports sessions attributed to the project", () async {
      await connect();
      const opened = "/Users/x/kustos";

      // One session per directory, both with a pending question.
      Future<PluginSession> create(String directory, String sessionId) async {
        final creating = plugin.createSession(
          directory: directory,
          parentSessionId: null,
          parts: const [],
          variant: null,
          agent: null,
          model: null,
        );
        await respond("session/new", {"sessionId": sessionId});
        return creating;
      }

      final inLaunch = await create(cwd, "s-launch");
      final inOpened = await create(opened, "s-opened");

      const question = PluginQuestionInfo(
        question: "Proceed?",
        header: "Plan",
        options: [PluginQuestionOption(label: "Yes", description: "confirm")],
        multiple: false,
        custom: false,
      );
      for (final session in [inLaunch, inOpened]) {
        plugin.registry.addPendingQuestion(
          bridgeRequestId: "q-${session.id}",
          acpId: "acp-${session.id}",
          sessionId: session.id,
          questions: const [question],
          replyBuilder: (answers) => null,
        );
      }

      final launchQuestions = await plugin.getProjectQuestions(projectId: cwd);
      expect(launchQuestions.map((q) => q.sessionID).toSet(), {"s-launch"});
      final openedQuestions = await plugin.getProjectQuestions(projectId: opened);
      expect(openedQuestions.map((q) => q.sessionID).toSet(), {"s-opened"});
    });
  });
}

Future<AcpProcessHandle> _throwReplayProcess(AcpLaunchSpec _) async {
  throw StateError("replay process failed to start");
}

/// [AcpPlugin] that captures the approval registry built at connect so tests
/// can register pending questions directly (the base registry only creates
/// questions through harness extension handlers).
class _RegistryCapturingAcpPlugin extends AcpPlugin {
  factory _RegistryCapturingAcpPlugin({
    required String id,
    required String agentDisplayName,
    required AcpLaunchSpec launchSpec,
    required String launchDirectory,
    required AcpEventMapper eventMapper,
    AcpProcessFactory? processFactory,
  }) {
    final clientBuilder = AcpStdioClientBuilder(
      launchSpec: launchSpec,
      processFactory: processFactory,
    );
    final liveClient = clientBuilder.build(logTag: id);
    final api = AcpApi(client: liveClient);
    final sessionRepository = AcpSessionRepository(api: api);
    final commandTracker = AcpCommandTracker();
    final commandTurnTracker = AcpCommandTurnTracker();
    final directoryTracker = AcpSessionDirectoryTracker(
      launchDirectory: launchDirectory,
    );
    final residencyTracker = AcpSessionResidencyTracker();
    final queueTracker = AcpTurnQueueTracker(pluginId: id);
    final eventDispatcher = AcpTurnEventDispatcher(
      eventMapper: eventMapper,
      commandTracker: commandTracker,
      commandTurnTracker: commandTurnTracker,
      residencyTracker: residencyTracker,
    );
    final connectionService = AcpConnectionService(
      client: liveClient,
      repository: sessionRepository,
      configuration: const AcpConnectionConfiguration(
        initializeRequest: AcpInitializeRequest(
          clientName: "sesori-bridge",
          clientVersion: "0.0.0",
          clientTitle: null,
          capabilityMeta: null,
        ),
        authMethodId: null,
      ),
    );
    final notificationListener = AcpNotificationListener(
      notificationRepository: AcpNotificationRepository(
        apiNotifications: api.notifications,
      ),
      eventDispatcher: eventDispatcher,
    );
    final approvalRegistry = AcpApprovalRegistry.forClient(
      client: liveClient,
      emit: eventDispatcher.emit,
      activeSessionResolver: queueTracker.resolveActiveSession,
    );
    final approvalListener = AcpApprovalListener(
      registry: approvalRegistry,
      requests: liveClient.serverRequests,
    );
    const turnConfigurationDispatcher = AcpTurnConfigurationDispatcher();
    final turnService = AcpTurnService(
      pluginId: id,
      connectionService: connectionService,
      directoryTracker: directoryTracker,
      residencyTracker: residencyTracker,
      queueTracker: queueTracker,
      commandTurnTracker: commandTurnTracker,
      eventDispatcher: eventDispatcher,
      turnConfigurationDispatcher: turnConfigurationDispatcher,
      commandFastFailWindow: const Duration(milliseconds: 100),
    );
    return _RegistryCapturingAcpPlugin._(
      id: id,
      agentDisplayName: agentDisplayName,
      launchSpec: launchSpec,
      launchDirectory: launchDirectory,
      eventMapper: eventMapper,
      clientBuilder: clientBuilder,
      commandTracker: commandTracker,
      connectionService: connectionService,
      notificationListener: notificationListener,
      approvalListener: approvalListener,
      approvalRegistry: approvalRegistry,
      directoryTracker: directoryTracker,
      turnService: turnService,
      turnConfigurationDispatcher: turnConfigurationDispatcher,
    );
  }

  _RegistryCapturingAcpPlugin._({
    required super.id,
    required super.agentDisplayName,
    required super.launchSpec,
    required super.launchDirectory,
    required super.eventMapper,
    required super.clientBuilder,
    required super.commandTracker,
    required super.connectionService,
    required super.notificationListener,
    required super.approvalListener,
    required super.approvalRegistry,
    required super.directoryTracker,
    required super.turnService,
    required super.turnConfigurationDispatcher,
  }) : _registry = approvalRegistry,
       super.configured();

  final AcpApprovalRegistry _registry;

  AcpApprovalRegistry get registry => _registry;
}
