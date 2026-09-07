import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/deepseek_test_plugin.dart";

void main() {
  test("live initialization requires adapter 0.1.4 or newer", () async {
    final fake = FakeAcpProcess();
    final plugin = buildDeepSeekTestPlugin(fake: fake);
    AcpInitializeResult result(String version) => AcpInitializeResult.fromJson({
      "protocolVersion": 1,
      "agentCapabilities": <String, dynamic>{},
      "authMethods": <Object?>[],
      "_meta": {
        DeepSeekAcpApi.initializeMetadataKey: {
          "extensionProtocolVersion": 2,
          "adapterVersion": version,
          "harnessVersion": "0.1.1-rc.2",
          "persistenceOwner": "sesori",
        },
      },
    });

    expect(() => plugin.validateInitializeResult(result("0.1.3")), throwsFormatException);
    expect(() => plugin.validateInitializeResult(result("0.1.4")), returnsNormally);
    expect(() => plugin.validateInitializeResult(result("0.1.5")), returnsNormally);
    await plugin.dispose();
    await fake.close();
  });

  test("prompt-write buffering preserves old input, cancel, later reused input order", () async {
    final fake = _FlushControlledAcpProcess();
    final plugin = buildDeepSeekTestPlugin(fake: fake);

    Future<Map<String, dynamic>> waitForFrame({required String method, int count = 1}) async {
      for (var attempt = 0; attempt < 200; attempt++) {
        final matches = fake.written.where((frame) => frame["method"] == method).toList();
        if (matches.length >= count) return matches[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("DeepSeek never wrote '$method'");
    }

    try {
      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrame(method: AcpMethods.initialize);
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
          "_meta": {
            DeepSeekAcpApi.initializeMetadataKey: {
              "extensionProtocolVersion": 2,
              "adapterVersion": DeepSeekPluginDescriptor.targetVersion,
              "harnessVersion": "0.1.1-rc.2",
              "persistenceOwner": "sesori",
            },
          },
        },
      });
      expect(await connecting, isTrue);

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final sessionNew = await waitForFrame(method: AcpMethods.sessionNew);
      fake.emit({
        "jsonrpc": "2.0",
        "id": sessionNew["id"],
        "result": {"sessionId": "session-1"},
      });
      await creating;

      final flush = fake.holdNextFlush();
      await plugin.sendPrompt(
        sessionId: "session-1",
        promptId: "prompt-1",
        parts: const [PluginPromptPart.text(text: "writing")],
        variant: null,
        agent: null,
        model: null,
      );
      final prompt = await waitForFrame(method: AcpMethods.sessionPrompt);
      <Map<String, dynamic>>[
        {
          "jsonrpc": "2.0",
          "id": 81,
          "method": DeepSeekAcpApi.askUserQuestionMethod,
          "params": {
            "sessionId": "session-1",
            "questions": [
              {"id": "reused", "text": "Old question"},
            ],
          },
        },
        {
          "jsonrpc": "2.0",
          "id": 82,
          "method": DeepSeekAcpApi.inputCancelMethod,
          "params": {"sessionId": "session-1"},
        },
        {
          "jsonrpc": "2.0",
          "id": 83,
          "method": DeepSeekAcpApi.askUserQuestionMethod,
          "params": {
            "sessionId": "session-1",
            "questions": [
              {"id": "reused", "text": "New question"},
            ],
          },
        },
      ].forEach(fake.emit);
      await Future<void>.delayed(Duration.zero);
      expect(await plugin.getPendingQuestions(sessionId: "session-1"), isEmpty);

      flush.complete();
      for (var attempt = 0; attempt < 20; attempt++) {
        if ((await plugin.getPendingQuestions(sessionId: "session-1")).isNotEmpty) break;
        await Future<void>.delayed(Duration.zero);
      }
      final pending = await plugin.getPendingQuestions(sessionId: "session-1");
      expect(pending.single.questions.single.question, "New question");
      expect(fake.written.singleWhere((frame) => frame["id"] == 81)["error"], {
        "code": -32603,
        "message": "aborted",
      });
      expect(fake.written.singleWhere((frame) => frame["id"] == 82)["result"], isEmpty);
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });
    } finally {
      await plugin.dispose();
      await fake.close();
    }
  });

  test("a busy follow-up cancels before replacement prompt dispatch", () async {
    final fake = FakeAcpProcess();
    final plugin = buildDeepSeekTestPlugin(fake: fake);
    final handledFrames = <Map<String, dynamic>>{};

    Future<Map<String, dynamic>> waitForFrame({required String method}) async {
      for (var attempt = 0; attempt < 200; attempt++) {
        final matches = fake.written.where(
          (frame) => frame["method"] == method && !handledFrames.contains(frame),
        );
        if (matches.isNotEmpty) {
          final frame = matches.first;
          handledFrames.add(frame);
          return frame;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("DeepSeek never wrote '$method'");
    }

    try {
      expect(plugin.cancelsActiveTurnForQueuedInput, isTrue);
      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrame(method: AcpMethods.initialize);
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
          "_meta": {
            "sesori.ai/deepseek": {
              "extensionProtocolVersion": 2,
              "adapterVersion": DeepSeekPluginDescriptor.targetVersion,
              "harnessVersion": "0.1.1-rc.2",
              "persistenceOwner": "sesori",
            },
          },
        },
      });
      expect(await connecting, isTrue);

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final sessionNew = await waitForFrame(method: AcpMethods.sessionNew);
      fake.emit({
        "jsonrpc": "2.0",
        "id": sessionNew["id"],
        "result": {"sessionId": "session-1"},
      });
      await creating;

      await plugin.sendPrompt(
        sessionId: "session-1",
        promptId: "prompt-1",
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: null,
      );
      final first = await waitForFrame(method: AcpMethods.sessionPrompt);

      await plugin.sendPrompt(
        sessionId: "session-1",
        promptId: "prompt-2",
        parts: const [PluginPromptPart.text(text: "replacement")],
        variant: null,
        agent: null,
        model: null,
      );
      final cancel = await waitForFrame(method: AcpMethods.sessionCancel);
      expect(cancel["params"], {"sessionId": "session-1"});
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.sessionPrompt), hasLength(1));

      fake.emit({
        "jsonrpc": "2.0",
        "id": first["id"],
        "result": {"stopReason": "cancelled"},
      });
      final replacement = await waitForFrame(method: AcpMethods.sessionPrompt);
      expect(((replacement["params"] as Map)["prompt"] as List).single, {
        "type": "text",
        "text": "replacement",
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": replacement["id"],
        "result": {"stopReason": "end_turn"},
      });
    } finally {
      await plugin.dispose();
      await fake.close();
    }
  });
}

class _FlushControlledAcpProcess() extends FakeAcpProcess {
  final _FlushControlledIOSink _controlledStdin = _FlushControlledIOSink();

  @override
  _FlushControlledIOSink get stdin => _controlledStdin;

  @override
  List<Map<String, dynamic>> get written => _controlledStdin.frames;

  Completer<void> holdNextFlush() => _controlledStdin.holdNextFlush();
}

class _FlushControlledIOSink() extends CapturingIOSink {
  Completer<void>? _nextFlush;

  Completer<void> holdNextFlush() {
    final gate = Completer<void>();
    _nextFlush = gate;
    return gate;
  }

  @override
  Future<void> flush() {
    final gate = _nextFlush;
    _nextFlush = null;
    return gate?.future ?? Future<void>.value();
  }
}
