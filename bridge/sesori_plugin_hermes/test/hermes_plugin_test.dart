import "dart:async";

import "package:acp_plugin/acp_testing.dart";
import "package:hermes_plugin/hermes_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// The `initialize` result Hermes actually advertises (verified 2026-08-13
/// against `hermes acp` v0.20.0): load/list/resume/fork session capabilities,
/// image prompt support, and no `closeSession` — the base must therefore
/// never call `session/close`.
const Map<String, dynamic> hermesInitializeResult = {
  "protocolVersion": 1,
  "agentCapabilities": {
    "loadSession": true,
    "promptCapabilities": {"image": true},
    "sessionCapabilities": {
      "fork": <String, dynamic>{},
      "list": <String, dynamic>{},
      "resume": <String, dynamic>{},
    },
  },
  "authMethods": [
    {
      "type": "terminal",
      "id": "hermes-setup",
      "title": "Hermes terminal setup",
    },
  ],
};

void main() {
  group("HermesPlugin", () {
    late FakeAcpProcess fake;
    late HermesPlugin plugin;
    late Set<Object?> handledFrameIds;

    setUp(() {
      fake = FakeAcpProcess();
      handledFrameIds = {};
      plugin = HermesPlugin(
        launchDirectory: "/repo",
        processFactory: (_) async => fake,
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 50; i++) {
        final matches = fake.written.where(
          (frame) => frame["method"] == method && !handledFrameIds.contains(frame["id"]),
        );
        if (matches.isNotEmpty) {
          final frame = matches.first;
          handledFrameIds.add(frame["id"]);
          return frame;
        }
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      final frame = await waitForFrame(method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
    }

    Future<void> connect() async {
      final connecting = plugin.ensureConnected();
      await respond("initialize", hermesInitializeResult);
      // Hermes advertises a terminal auth method, so the handshake calls
      // authenticate with it; a configured install answers with an empty body.
      await respond("authenticate", const <String, dynamic>{});
      expect(await connecting, isTrue);
    }

    test("id is hermes", () {
      expect(plugin.id, "hermes");
    });

    test("the default binary is the Hermes CLI and the launch spec drives `hermes acp`", () {
      expect(HermesBinary.defaultBinary, "hermes");
      final spec = HermesBinary.launchSpec(cwd: "/repo");
      expect(spec.command, "hermes");
      expect(spec.args, ["acp"]);
    });

    test("declares the neutral ACP policies for a stock v1 server", () {
      expect(plugin.clientName, "sesori-bridge");
      expect(plugin.clientVersion, "0.0.0");
      expect(plugin.authMethodId, isNull, reason: "use the first advertised method");
      expect(plugin.initializeCapabilityMeta, isNull);
      expect(plugin.supportsFormElicitation, isFalse, reason: "no elicitation/create on Hermes");
      expect(plugin.serializesPromptsProcessWide, isFalse);
      expect(plugin.failsTurnOnSelectionError, isFalse);
      expect(plugin.sessionCloseSettlementTimeout, const Duration(seconds: 5));
    });

    test("handshake succeeds against Hermes's advertised capabilities", () async {
      await connect();
    });

    test("a prompt turn streams text chunks into part delta events", () async {
      await connect();
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", const {"sessionId": "s1"});
      final session = await creating;
      expect(session.id, "s1");

      final prompting = plugin.sendPrompt(
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "Hello")],
        variant: null,
        agent: null,
        model: null,
      );
      final promptFrame = await waitForFrame("session/prompt");
      final params = (promptFrame["params"] as Map).cast<String, dynamic>();
      expect(params["sessionId"], "s1");
      final prompt = params["prompt"] as List;
      expect(
        (prompt.single as Map)["text"],
        "Hello",
        reason: "the prompt part must reach the agent verbatim",
      );
      fake.emit({"jsonrpc": "2.0", "id": promptFrame["id"], "result": <String, dynamic>{}});
      await prompting;

      // Hermes streams assistant output as session/update agent_message_chunk
      // notifications (same shape the base mapper expects).
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "Hello"},
          },
        },
      });
      await pump();

      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "Hello");
    });

    test("deleteSession never calls session/close when closeSession is not advertised", () async {
      await connect();

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", const {"sessionId": "s1"});
      await creating;

      await plugin.deleteSession("s1");
      await pump();

      expect(
        fake.written.where((frame) => frame["method"] == "session/close"),
        isEmpty,
        reason: "Hermes does not advertise closeSession, so deletion must be local-only",
      );
    });
  });
}
