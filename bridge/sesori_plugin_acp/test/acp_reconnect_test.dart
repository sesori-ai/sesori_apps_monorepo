import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:test/test.dart";

/// After the agent subprocess exits, the cached ACP connection must be torn
/// down so the next request spawns a fresh agent instead of writing to the dead
/// process (the "recoverable" degraded path the lifecycle wrapper advertises).
void main() {
  group("AcpPlugin reconnect after exit", () {
    final fakes = <FakeAcpProcess>[];
    late AcpPlugin plugin;
    const cwd = "/repo";

    setUp(() {
      fakes.clear();
      plugin = AcpPlugin(
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

    Future<void> pump() => Future<void>.delayed(Duration.zero);
    Future<void> respondInitialize(FakeAcpProcess fake) async {
      for (var i = 0; i < 80; i++) {
        final init = fake.written.where((f) => f["method"] == "initialize");
        if (init.isNotEmpty) {
          fake.emit({
            "jsonrpc": "2.0",
            "id": init.last["id"],
            "result": {
              "protocolVersion": 1,
              "agentCapabilities": <String, dynamic>{},
              "authMethods": <Object?>[],
            },
          });
          await pump();
          return;
        }
        await pump();
      }
      throw StateError("agent never wrote an 'initialize' frame");
    }

    test("resetConnectionAfterExit drops the cached connection so the next request reconnects", () async {
      // onConnected must fire on every successful (re)connect so the lifecycle
      // wrapper can re-arm its exit watch on the new client.
      var connects = 0;
      plugin.onConnected.listen((_) => connects++);

      final connecting = plugin.ensureConnected();
      await respondInitialize(fakes.single);
      expect(await connecting, isTrue);
      expect(fakes, hasLength(1));
      final first = plugin.client;
      expect(first, isNotNull);
      await pump();
      expect(connects, 1);

      // The agent process dies, then the lifecycle resets the connection.
      fakes.single.exit(1);
      await pump();
      await plugin.resetConnectionAfterExit();
      expect(plugin.client, isNull);

      // The next ensureConnected must spawn a brand-new agent process rather
      // than hand back the stale cached success.
      final reconnecting = plugin.ensureConnected();
      await respondInitialize(fakes.last);
      expect(await reconnecting, isTrue);
      expect(fakes, hasLength(2), reason: "a fresh agent process was spawned");
      expect(
        identical(plugin.client, first),
        isTrue,
        reason: "the composed transport is reused while it spawns a fresh process",
      );
      await pump();
      expect(connects, 2, reason: "onConnected fires again on reconnect");

      fakes.last.emit({
        "jsonrpc": "2.0",
        "id": 17,
        "method": "session/request_permission",
        "params": {
          "sessionId": "s1",
          "toolCall": {"kind": "execute"},
          "options": [
            {"optionId": "allow", "kind": "allow_once"},
          ],
        },
      });
      await pump();
      await pump();
      expect(
        await plugin.getPendingPermissions(sessionId: "s1"),
        hasLength(1),
        reason: "approval requests must be observed after reconnect",
      );
    });
  });
}
