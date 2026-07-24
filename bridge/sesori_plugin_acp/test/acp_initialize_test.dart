import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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
        commandTracker: AcpCommandTracker(),
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

    Future<Map<String, dynamic>> waitForMethod(FakeAcpProcess fake, String method) async {
      for (var i = 0; i < 80; i++) {
        final frames = fake.written.where((frame) => frame["method"] == method);
        if (frames.isNotEmpty) return frames.last;
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
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

    test("an advertised authentication rejection remains typed on backend operations", () async {
      final connecting = plugin.ensureConnected();
      final fake = fakes.single;
      final initialize = await waitForMethod(fake, "initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {"id": "agent_login", "name": "Agent login"},
          ],
        },
      });
      final authenticate = await waitForMethod(fake, "authenticate");
      fake.emit({
        "jsonrpc": "2.0",
        "id": authenticate["id"],
        "error": {"code": -32000, "message": "login required"},
      });
      expect(await connecting, isFalse);

      final matcher = isA<PluginAuthenticationRequiredException>()
          .having((error) => error.statusCode, "statusCode", 503)
          .having((error) => error.actionHint, "actionHint", isNotEmpty);
      final sending = plugin.sendPrompt(
        sessionId: "session-1",
        parts: const [PluginPromptPart.text(text: "hello")],
        variant: null,
        agent: null,
        model: null,
      );
      for (var i = 0; i < 80 && fakes.length < 2; i++) {
        await pump();
      }
      expect(fakes, hasLength(2));
      final retry = fakes.last;
      final retryInitialize = await waitForMethod(retry, "initialize");
      retry.emit({
        "jsonrpc": "2.0",
        "id": retryInitialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {"id": "agent_login", "name": "Agent login"},
          ],
        },
      });
      final retryAuthenticate = await waitForMethod(retry, "authenticate");
      retry.emit({
        "jsonrpc": "2.0",
        "id": retryAuthenticate["id"],
        "error": {"code": -32000, "message": "login still required"},
      });
      await expectLater(
        sending,
        throwsA(matcher),
      );
    });

    test("a later connection retries after an authentication rejection", () async {
      final connecting = plugin.ensureConnected();
      final first = fakes.single;
      final initialize = await waitForMethod(first, "initialize");
      first.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {"id": "agent_login", "name": "Agent login"},
          ],
        },
      });
      final authenticate = await waitForMethod(first, "authenticate");
      first.emit({
        "jsonrpc": "2.0",
        "id": authenticate["id"],
        "error": {"code": -32000, "message": "login required"},
      });
      expect(await connecting, isFalse);

      final retrying = plugin.ensureConnected();
      for (var i = 0; i < 80 && fakes.length < 2; i++) {
        await pump();
      }
      expect(fakes, hasLength(2));
      await respondInitialize(fakes.last, protocolVersion: 1);

      expect(await retrying, isTrue);
    });

    test("a process exit during authentication remains a connection failure", () async {
      final sending = plugin.sendPrompt(
        sessionId: "session-1",
        parts: const [PluginPromptPart.text(text: "hello")],
        variant: null,
        agent: null,
        model: null,
      );
      final fake = fakes.single;
      final initialize = await waitForMethod(fake, "initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {"id": "agent_login", "name": "Agent login"},
          ],
        },
      });
      await waitForMethod(fake, "authenticate");
      fake.exit(1);

      await expectLater(sending, throwsA(isA<StateError>()));
    });
  });
}
