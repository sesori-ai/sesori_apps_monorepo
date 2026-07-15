import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:test/test.dart";

/// [AcpPlugin.probeCatalogFromExistingSession] warms the config catalog by
/// `session/load`-ing existing sessions on a short-lived probe client. The base
/// completes on the first capture, but a subclass whose catalog needs data
/// present only on some sessions (e.g. Cursor's per-model effort) keeps the
/// probe walking older sessions until [AcpPlugin.isCatalogComplete] is satisfied
/// or the [AcpPlugin.maxCatalogProbeSessions] bound is hit. These tests cover
/// that bounded, most-recent-first walk without any harness-specific meaning.
void main() {
  group("AcpPlugin catalog probe walk", () {
    final fakes = <FakeAcpProcess>[];
    late _WalkCatalogAcpPlugin plugin;
    const cwd = "/repo";

    void makePlugin({required int probeBound}) {
      plugin = _WalkCatalogAcpPlugin(
        probeBound: probeBound,
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp", pluginId: "acp"),
        processFactory: (_) async {
          final fake = FakeAcpProcess();
          fakes.add(fake);
          return fake;
        },
      );
    }

    setUp(fakes.clear);

    tearDown(() async {
      await plugin.dispose();
      for (final fake in fakes) {
        await fake.close();
      }
    });

    /// All frames written across every spawned fake (live client + probe).
    List<Map<String, dynamic>> allWritten() =>
        [for (final fake in fakes) ...fake.written];

    /// Background agent that answers `initialize` / `session/list` /
    /// `session/load` across every fake until stopped. [listSessions] is the
    /// enumeration result; [loadResults] maps a sessionId to its load result;
    /// each answered `session/load` appends its sessionId to [loadOrder].
    void Function() autoAnswer({
      required List<Map<String, dynamic>> listSessions,
      required Map<String, Map<String, dynamic>> loadResults,
      required List<String> loadOrder,
    }) {
      // Request ids restart per spawned client, so scope answered ids to their
      // owning fake instance.
      final answered = <(FakeAcpProcess, Object?)>{};
      var running = true;
      unawaited(() async {
        while (running) {
          for (final fake in fakes.toList()) {
            for (final frame in fake.written.toList()) {
              final id = frame["id"];
              if (id == null) continue; // notification, no response expected
              if (!answered.add((fake, id))) continue;
              final Map<String, dynamic> result;
              switch (frame["method"]) {
                case "initialize":
                  result = {
                    "protocolVersion": 1,
                    "agentCapabilities": {
                      "loadSession": true,
                      "sessionCapabilities": {"list": <String, dynamic>{}},
                    },
                    "authMethods": <Object?>[],
                  };
                case "session/list":
                  result = {"sessions": listSessions};
                case "session/load":
                  final params = (frame["params"] as Map).cast<String, dynamic>();
                  loadOrder.add(params["sessionId"] as String);
                  result = loadResults[params["sessionId"]] ?? const {};
                default:
                  answered.remove((fake, id)); // leave other methods unanswered
                  continue;
              }
              fake.emit({"jsonrpc": "2.0", "id": id, "result": result});
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }());
      return () => running = false;
    }

    Map<String, dynamic> session(String id, {required int updatedAt}) =>
        {"sessionId": id, "cwd": cwd, "title": id, "updatedAt": updatedAt};

    test("walks sessions most-recent-first, stopping when the catalog completes", () async {
      makePlugin(probeBound: 8);
      final loadOrder = <String>[];
      final stop = autoAnswer(
        listSessions: [
          session("s-old", updatedAt: 1000),
          session("s-new", updatedAt: 3000),
          session("s-mid", updatedAt: 2000),
        ],
        loadResults: {
          "s-new": const {"configOptions": <Object?>[]},
          "s-mid": const {"configOptions": <Object?>[]},
          // Only the oldest session completes the catalog.
          "s-old": const {"complete": true},
        },
        loadOrder: loadOrder,
      );

      expect(await plugin.ensureConnected(), isTrue);
      await plugin.probeCatalogFromExistingSession();
      stop();

      expect(loadOrder, ["s-new", "s-mid", "s-old"], reason: "loaded newest-first until one completed");
      expect(plugin.captured, hasLength(3));
      expect(plugin.captured.last["complete"], isTrue);
      expect(
        allWritten().where((f) => f["method"] == "session/new"),
        isEmpty,
        reason: "the probe must never create a throwaway session",
      );
    });

    test("stops at the probe bound when no session completes the catalog", () async {
      makePlugin(probeBound: 2);
      final loadOrder = <String>[];
      final stop = autoAnswer(
        listSessions: [
          session("s-new", updatedAt: 3000),
          session("s-mid", updatedAt: 2000),
          session("s-old", updatedAt: 1000),
        ],
        // No session completes the catalog.
        loadResults: const {
          "s-new": {"configOptions": <Object?>[]},
          "s-mid": {"configOptions": <Object?>[]},
          "s-old": {"configOptions": <Object?>[]},
        },
        loadOrder: loadOrder,
      );

      expect(await plugin.ensureConnected(), isTrue);
      await plugin.probeCatalogFromExistingSession();
      stop();

      expect(loadOrder, ["s-new", "s-mid"], reason: "the walk stops at the 2-session bound");
      expect(plugin.captured, hasLength(2));
      expect(
        allWritten().where((f) => f["method"] == "session/new"),
        isEmpty,
        reason: "hitting the bound must not fall back to a throwaway session",
      );
    });

    test("a failed load does not abandon the walk", () async {
      makePlugin(probeBound: 8);
      final loadOrder = <String>[];
      // s-new returns an error; the walk must continue to s-old, which completes.
      final answered = <(FakeAcpProcess, Object?)>{};
      var running = true;
      unawaited(() async {
        while (running) {
          for (final fake in fakes.toList()) {
            for (final frame in fake.written.toList()) {
              final id = frame["id"];
              if (id == null || !answered.add((fake, id))) continue;
              switch (frame["method"]) {
                case "initialize":
                  fake.emit({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": {
                      "protocolVersion": 1,
                      "agentCapabilities": {
                        "loadSession": true,
                        "sessionCapabilities": {"list": <String, dynamic>{}},
                      },
                      "authMethods": <Object?>[],
                    },
                  });
                case "session/list":
                  fake.emit({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": {
                      "sessions": [
                        session("s-new", updatedAt: 3000),
                        session("s-old", updatedAt: 1000),
                      ],
                    },
                  });
                case "session/load":
                  final sid = (frame["params"] as Map).cast<String, dynamic>()["sessionId"] as String;
                  loadOrder.add(sid);
                  if (sid == "s-new") {
                    fake.emit({
                      "jsonrpc": "2.0",
                      "id": id,
                      "error": {"code": -32000, "message": "load failed"},
                    });
                  } else {
                    fake.emit({"jsonrpc": "2.0", "id": id, "result": const {"complete": true}});
                  }
                default:
                  answered.remove((fake, id));
              }
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }());

      expect(await plugin.ensureConnected(), isTrue);
      await plugin.probeCatalogFromExistingSession();
      running = false;

      expect(loadOrder, ["s-new", "s-old"], reason: "a failed load is skipped, not fatal");
      expect(plugin.captured, hasLength(1), reason: "only the successful load captured");
      expect(plugin.captured.single["complete"], isTrue);
    });
  });
}

/// Test [AcpPlugin] whose catalog is "complete" once it has captured a session
/// result tagged `complete`. Stands in for a subclass (like Cursor) that needs
/// more than the newest session to fully warm its catalog.
class _WalkCatalogAcpPlugin extends AcpPlugin {
  _WalkCatalogAcpPlugin({
    required this.probeBound,
    required super.launchSpec,
    required super.launchDirectory,
    required super.eventMapper,
    super.processFactory,
  }) : super(id: "acp", agentDisplayName: "ACP");

  final int probeBound;
  final List<Map<String, dynamic>> captured = [];
  bool _complete = false;

  @override
  int get maxCatalogProbeSessions => probeBound;

  @override
  bool get isCatalogComplete => _complete;

  @override
  void captureSessionConfig(
    Map<String, dynamic> result, {
    String? sessionId,
    bool fromNewSession = false,
  }) {
    captured.add(result);
    if (result["complete"] == true) _complete = true;
  }
}
