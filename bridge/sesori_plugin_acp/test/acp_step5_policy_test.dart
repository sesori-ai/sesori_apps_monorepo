import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _PolicyPlugin({
  required final bool processWide,
  required final bool failClosed,
  required final bool forms,
  required final Duration closeTimeout,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  required AcpProcessFactory super.processFactory,
}) extends TestAcpPlugin {
  this
    : super(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: "/repo",
      );

  int selectionFailures = 0;

  @override
  bool get serializesPromptsProcessWide => processWide;

  @override
  bool get failsTurnOnSelectionError => failClosed;

  @override
  bool get supportsFormElicitation => forms;

  @override
  Duration get sessionCloseSettlementTimeout => closeTimeout;

  @override
  Future<void> applyTurnSelection({
    required AcpAgentApi api,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    if (selectionFailures > 0) {
      selectionFailures--;
      throw StateError("selection rejected");
    }
  }
}

void main() {
  group("ACP Step 5 turn policies", () {
    late FakeAcpProcess fake;
    late _PolicyPlugin plugin;
    late List<BridgeSseEvent> events;

    _PolicyPlugin buildPlugin({
      required bool processWide,
      required bool failClosed,
      bool forms = false,
      Duration closeTimeout = const Duration(seconds: 1),
    }) {
      final configurationTracker = AcpSessionConfigurationTracker();
      final commandTracker = AcpCommandTracker();
      return _PolicyPlugin(
        processWide: processWide,
        failClosed: failClosed,
        forms: forms,
        closeTimeout: closeTimeout,
        eventMapper: AcpEventMapper(
          launchDirectory: "/repo",
          pluginId: "acp",
          configurationTracker: configurationTracker,
        ),
        commandTracker: commandTracker,
        sessionOptionsService: AcpSessionOptionsService(
          configurationTracker: configurationTracker,
          commandTracker: commandTracker,
          pluginId: "acp",
          agentDisplayName: "ACP",
        ),
        processFactory: (_) async => fake,
      );
    }

    setUp(() {
      fake = FakeAcpProcess();
      events = [];
      plugin = buildPlugin(processWide: false, failClosed: false);
      plugin.events.listen(events.add);
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    List<Map<String, dynamic>> frames(String method) =>
        fake.written.where((frame) => frame["method"] == method).toList(growable: false);

    Future<Map<String, dynamic>> waitForFrameCount(String method, int count) async {
      for (var i = 0; i < 200; i++) {
        final matches = frames(method);
        if (matches.length >= count) return matches[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote $count '$method' frame(s)");
    }

    void respond(Map<String, dynamic> frame, Map<String, dynamic> result) {
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
    }

    Future<void> connect({bool close = false}) async {
      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrameCount(AcpMethods.initialize, 1);
      respond(initialize, {
        "protocolVersion": 1,
        "agentCapabilities": {
          "sessionCapabilities": {
            if (close) "close": <String, dynamic>{},
          },
        },
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);
    }

    Future<PluginSession> create(String id) async {
      final expectedFrame = frames(AcpMethods.sessionNew).length + 1;
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final frame = await waitForFrameCount(AcpMethods.sessionNew, expectedFrame);
      respond(frame, {"sessionId": id});
      return await creating;
    }

    Future<void> send(String sessionId, String text) => plugin.sendPrompt(
      promptId: "prompt-1",
      sessionId: sessionId,
      parts: [PluginPromptPart.text(text: text)],
      variant: null,
      agent: null,
      model: null,
    );

    test("opt-in process lane serializes prompts across sessions", () async {
      await plugin.dispose();
      plugin = buildPlugin(processWide: true, failClosed: false);
      plugin.events.listen(events.add);
      await connect();
      final first = await create("first");
      final second = await create("second");

      await send(first.id, "one");
      final firstPrompt = await waitForFrameCount(AcpMethods.sessionPrompt, 1);
      await send(second.id, "two");
      await pump();
      expect(frames(AcpMethods.sessionPrompt), hasLength(1));

      respond(firstPrompt, {"stopReason": "end_turn"});
      final secondPrompt = await waitForFrameCount(AcpMethods.sessionPrompt, 2);
      expect((secondPrompt["params"] as Map)["sessionId"], second.id);
      respond(secondPrompt, {"stopReason": "end_turn"});
    });

    test("form capability is advertised only by an opted-in plugin", () async {
      await plugin.dispose();
      plugin = buildPlugin(processWide: false, failClosed: false, forms: true);
      plugin.events.listen(events.add);

      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrameCount(AcpMethods.initialize, 1);
      final params = (initialize["params"] as Map).cast<String, dynamic>();
      final capabilities = (params["clientCapabilities"] as Map).cast<String, dynamic>();
      expect(capabilities["elicitation"], {
        "form": <String, dynamic>{},
      });
      respond(initialize, {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);
    });

    test("fail-closed selection stops before prompt dispatch", () async {
      await plugin.dispose();
      plugin = buildPlugin(processWide: false, failClosed: true);
      plugin.events.listen(events.add);
      await connect();
      final session = await create("session-1");
      plugin.selectionFailures = 1;

      await send(session.id, "do not dispatch");
      for (var i = 0; i < 20 && events.whereType<BridgeSseSessionError>().isEmpty; i++) {
        await pump();
      }

      expect(frames(AcpMethods.sessionPrompt), isEmpty);
      expect(events.whereType<BridgeSseSessionError>(), hasLength(1));
    });

    test("empty-session selection failure stays bound and retries on first prompt", () async {
      await plugin.dispose();
      plugin = buildPlugin(processWide: false, failClosed: true);
      plugin.events.listen(events.add);
      await connect();
      plugin.selectionFailures = 1;

      final session = await create("session-1");
      await pump();
      expect(session.id, "session-1");
      expect(events.whereType<BridgeSseTuiToastShow>(), hasLength(1));

      await send(session.id, "retry");
      final prompt = await waitForFrameCount(AcpMethods.sessionPrompt, 1);
      respond(prompt, {"stopReason": "end_turn"});
    });

    test("close waits for cancelled prompt settlement before dropping state", () async {
      await connect(close: true);
      final session = await create("session-1");
      await send(session.id, "long turn");
      final prompt = await waitForFrameCount(AcpMethods.sessionPrompt, 1);

      final deleting = plugin.deleteSession(session.id);
      await waitForFrameCount(AcpMethods.sessionCancel, 1);
      expect(frames(AcpMethods.sessionClose), isEmpty);

      respond(prompt, {"stopReason": "cancelled"});
      final close = await waitForFrameCount(AcpMethods.sessionClose, 1);
      respond(close, const {});
      await deleting;
      expect(await plugin.getSessionStatuses(), isNot(contains(session.id)));
    });

    test("deleting a queued session does not wait behind another session", () async {
      await plugin.dispose();
      plugin = buildPlugin(processWide: true, failClosed: false);
      plugin.events.listen(events.add);
      await connect(close: true);
      final running = await create("running");
      final queued = await create("queued");
      await send(running.id, "long turn");
      final runningPrompt = await waitForFrameCount(AcpMethods.sessionPrompt, 1);
      await send(queued.id, "never dispatch");

      final deleting = plugin.deleteSession(queued.id);
      final close = await waitForFrameCount(AcpMethods.sessionClose, 1);
      expect((close["params"] as Map)["sessionId"], queued.id);
      respond(close, const {});
      await deleting;

      respond(runningPrompt, {"stopReason": "end_turn"});
      await pump();
      expect(frames(AcpMethods.sessionPrompt), hasLength(1));
    });

    test("close timeout fails deletion and preserves local session state", () async {
      await plugin.dispose();
      plugin = buildPlugin(
        processWide: false,
        failClosed: false,
        closeTimeout: const Duration(milliseconds: 20),
      );
      plugin.events.listen(events.add);
      await connect(close: true);
      final session = await create("session-1");
      await send(session.id, "stuck turn");
      await waitForFrameCount(AcpMethods.sessionPrompt, 1);

      await expectLater(
        plugin.deleteSession(session.id),
        throwsA(isA<PluginOperationException>()),
      );
      expect(await plugin.getSessionStatuses(), contains(session.id));
      expect(frames(AcpMethods.sessionClose), isEmpty);
    });
  });
}
