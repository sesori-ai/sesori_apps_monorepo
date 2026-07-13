import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:test/test.dart";

/// The ACP client only implements v1. The agent echoes the protocol version it
/// will use in its `initialize` result; if that is not v1 the handshake must
/// fail so the plugin degrades, rather than driving an incompatible agent with
/// v1-shaped `session/*` calls.
void main() {
  group("AcpPlugin initialize handshake", () {
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
    Future<void> respondInitialize(
      FakeAcpProcess fake, {
      required int protocolVersion,
    }) async {
      for (var i = 0; i < 80; i++) {
        final init = fake.written.where((f) => f["method"] == "initialize");
        if (init.isNotEmpty) {
          fake.emit({
            "jsonrpc": "2.0",
            "id": init.last["id"],
            "result": {
              "protocolVersion": protocolVersion,
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

    test("an incompatible negotiated protocol version degrades the connection", () async {
      final connecting = plugin.ensureConnected();
      await respondInitialize(fakes.single, protocolVersion: 2);
      expect(await connecting, isFalse, reason: "a non-v1 agent must not connect");
    });

    test("the v1 handshake connects", () async {
      final connecting = plugin.ensureConnected();
      await respondInitialize(fakes.single, protocolVersion: 1);
      expect(await connecting, isTrue);
    });
  });
}
