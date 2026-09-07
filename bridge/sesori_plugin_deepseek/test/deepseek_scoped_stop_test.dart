import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/deepseek_test_plugin.dart";

void main() {
  group("DeepSeek scoped stop", () {
    late _StopHarness harness;
    setUp(() async {
      harness = _StopHarness();
      await harness.connect();
    });
    tearDown(() => harness.close());

    test("confirm is side-effect free and reports main/background capability", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: true);
      final before = harness.fake.written.length;
      final result = await harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.confirm);
      expect(
        result,
        isA<PluginAbortRejectedSubAgentsRunning>()
            .having((r) => r.runningSubAgentCount, "children", 1)
            .having((r) => r.mainAgentRunning, "main", true)
            .having((r) => r.mainAgentOnlySupported, "keep supported", true),
      );
      expect(harness.fake.written, hasLength(before));
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isTrue);
    });

    test("keep rejects mixed foreground work without side effects", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "foreground", parent: "root", background: false);
      await harness.spawn(child: "background", parent: "root", background: true);
      final before = harness.fake.written.length;
      final result = await harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.keep);
      expect(
        result,
        isA<PluginAbortRejectedSubAgentsRunning>().having((r) => r.mainAgentOnlySupported, "keep supported", false),
      );
      expect(harness.fake.written, hasLength(before));
    });

    test("foreground named child cannot offer main-only stop even with background descendants", () async {
      await harness.spawn(child: "foreground", parent: "root", background: false);
      await harness.spawn(child: "background", parent: "foreground", background: true);
      final before = harness.fake.written.length;
      for (final policy in [PluginAbortSubAgentPolicy.confirm, PluginAbortSubAgentPolicy.keep]) {
        final result = await harness.plugin.abortSession(sessionId: "foreground", subAgents: policy);
        expect(
          result,
          isA<PluginAbortRejectedSubAgentsRunning>()
              .having((r) => r.runningSubAgentCount, "children", 1)
              .having((r) => r.mainAgentRunning, "main", true)
              .having((r) => r.mainAgentOnlySupported, "keep supported", false),
        );
        expect(harness.fake.written, hasLength(before));
      }
    });

    test("background named child can be interrupted while retaining its background descendant", () async {
      await harness.spawn(child: "parent", parent: "root", background: true);
      await harness.spawn(child: "child", parent: "parent", background: true);
      final stopping = harness.plugin.abortSession(sessionId: "parent", subAgents: PluginAbortSubAgentPolicy.keep);
      await harness.replyInterrupts(results: const {"parent": "interrupted"});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", true));
      expect(harness.cancels, isEmpty);
      expect(harness.interrupts.single["params"], {"sessionId": "root", "childSessionId": "parent"});
      expect(harness.plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"parent", "child"});
    });

    test("keep cancels only main when every child is background", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: true);
      final result = await harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.keep);
      expect(result, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", true));
      expect(harness.cancels.single["params"], {"sessionId": "root"});
      expect(harness.interrupts, isEmpty);
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isTrue);
    });

    test("child-only keep sends no cancellation", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      final before = harness.fake.written.length;
      final result = await harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.keep);
      expect(result, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", true));
      expect(harness.fake.written, hasLength(before));
    });

    test("stop sends one native subtree request and keeps lifecycle settlement authoritative", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "background", parent: "root", background: true);
      await harness.spawn(child: "foreground", parent: "background", background: false);
      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(stop["params"], {"kind": "session", "sessionId": "root"});
      expect(harness.cancels, isEmpty);
      expect(harness.interrupts, isEmpty);
      harness.reply(frame: stop, result: const {"workKept": false});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", false));
      expect(harness.plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"background", "foreground"});
      await harness.end(child: "foreground", parent: "background");
      await harness.end(child: "background", parent: "root");
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
    });

    test("native retained-work result does not synthesize child settlement", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      harness.reply(frame: stop, result: const {"workKept": true});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", true));
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isTrue);
      await harness.end(child: "child", parent: "root");
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
    });

    test("named child stop uses exact parent target without cancelling its parent or sibling", () async {
      await harness.spawn(child: "child", parent: "root", background: false);
      await harness.spawn(child: "sibling", parent: "root", background: true);
      final stopping = harness.plugin.abortSession(sessionId: "child", subAgents: PluginAbortSubAgentPolicy.stop);
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(stop["params"], {"kind": "child", "sessionId": "root", "childSessionId": "child"});
      harness.reply(frame: stop, result: const {"workKept": true});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", true));
      expect(harness.cancels, isEmpty);
      expect(harness.interrupts, isEmpty);
      expect(harness.plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"child", "sibling"});
    });

    test("a finished child opened for a new user turn uses a resident-session target", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.end(child: "child", parent: "root");
      await harness.prompt(sessionId: "child");
      final stopping = harness.plugin.abortSession(sessionId: "child", subAgents: PluginAbortSubAgentPolicy.stop);
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(stop["params"], {"kind": "session", "sessionId": "child"});
      harness.reply(frame: stop, result: const {"workKept": false});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", false));
      expect(harness.cancels, isEmpty);
      expect(harness.interrupts, isEmpty);
    });

    test("whole-plugin stop uses native authority and waits for lifecycle", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      final stopping = harness.plugin.interruptActiveWork(budget: const Duration(seconds: 2));
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      harness.reply(frame: stop, result: const {"workKept": false});
      var settled = false;
      final observed = stopping.then((value) {
        settled = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      expect(harness.plugin.currentWorkState, isNot(PluginWorkState.idle));
      await harness.end(child: "child", parent: "root");
      expect(await observed, containsAll(["root", "child"]));
      expect(harness.cancels, isEmpty);
      expect(harness.interrupts, isEmpty);
    });

    test("stop still uses native authority when the bridge knows no children", () async {
      await harness.prompt(sessionId: "root");
      final prompt = await harness.waitFor(method: AcpMethods.sessionPrompt, count: 1);
      harness.reply(frame: prompt, result: const {"stopReason": "end_turn"});
      await Future<void>.delayed(Duration.zero);

      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(stop["params"], {"kind": "session", "sessionId": "root"});
      harness.reply(frame: stop, result: const {"workKept": false});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", false));
    });

    test("stop discards only prompts queued before dispatch and preserves a later prompt", () async {
      await harness.prompt(sessionId: "root");
      final first = await harness.waitFor(method: AcpMethods.sessionPrompt, count: 1);
      await harness.plugin.sendPrompt(
        sessionId: "root",
        promptId: "old-queued",
        parts: const [PluginPromptPart.text(text: "old queued")],
        variant: null,
        agent: null,
        model: null,
      );
      expect(await harness.plugin.getQueuedPrompts(sessionId: "root"), hasLength(1));
      final cancelsBeforeStop = harness.cancels.length;

      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(harness.cancels, hasLength(cancelsBeforeStop));
      await harness.plugin.sendPrompt(
        sessionId: "root",
        promptId: "new-queued",
        parts: const [PluginPromptPart.text(text: "new queued")],
        variant: null,
        agent: null,
        model: null,
      );
      expect((await harness.plugin.getQueuedPrompts(sessionId: "root")).single.id, "new-queued");
      harness.reply(frame: stop, result: const {"workKept": false});
      await stopping;
      expect((await harness.plugin.getQueuedPrompts(sessionId: "root")).single.id, "new-queued");

      harness.reply(frame: first, result: const {"stopReason": "cancelled"});
      final later = await harness.waitFor(method: AcpMethods.sessionPrompt, count: 2);
      expect(((later["params"] as Map)["prompt"] as List).single, {"type": "text", "text": "new queued"});
      harness.reply(frame: later, result: const {"stopReason": "end_turn"});
    });

    test("stop response cannot cancel input admitted after the ordered cancellation request", () async {
      harness.emitQuestion(requestId: 71, sessionId: "root", text: "Old", questionId: "reused");
      await Future<void>.delayed(Duration.zero);
      expect(await harness.plugin.getPendingQuestions(sessionId: "root"), hasLength(1));

      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      harness.reply(frame: stop, result: const {"workKept": false});
      harness.fake.emit({
        "jsonrpc": "2.0",
        "id": 72,
        "method": DeepSeekAcpApi.inputCancelMethod,
        "params": {"sessionId": "root"},
      });
      harness.emitQuestion(requestId: 73, sessionId: "root", text: "New", questionId: "reused");
      await stopping;
      await Future<void>.delayed(Duration.zero);

      final pending = await harness.plugin.getPendingQuestions(sessionId: "root");
      expect(pending, hasLength(1));
      expect(pending.single.questions.single.question, "New");
      expect(harness.fake.written.singleWhere((frame) => frame["id"] == 71)["error"], {
        "code": -32603,
        "message": "aborted",
      });
      expect(harness.fake.written.singleWhere((frame) => frame["id"] == 72)["result"], isEmpty);
    });

    test("prompt-write buffering preserves old input, cancel, new input order", () async {
      await harness.close();
      final fake = _FlushControlledAcpProcess();
      harness = _StopHarness(fake: fake);
      await harness.connect();
      await harness.prompt(sessionId: "root");
      final first = await harness.waitFor(method: AcpMethods.sessionPrompt, count: 1);
      harness.reply(frame: first, result: const {"stopReason": "end_turn"});
      await Future<void>.delayed(Duration.zero);

      final flush = fake.holdNextFlush();
      await harness.plugin.sendPrompt(
        sessionId: "root",
        promptId: "writing",
        parts: const [PluginPromptPart.text(text: "writing")],
        variant: null,
        agent: null,
        model: null,
      );
      final writing = await harness.waitFor(method: AcpMethods.sessionPrompt, count: 2);
      harness.emitQuestion(requestId: 81, sessionId: "root", text: "Old", questionId: "reused");
      fake.emit({
        "jsonrpc": "2.0",
        "id": 82,
        "method": DeepSeekAcpApi.inputCancelMethod,
        "params": {"sessionId": "root"},
      });
      harness.emitQuestion(requestId: 83, sessionId: "root", text: "New", questionId: "reused");
      await Future<void>.delayed(Duration.zero);
      expect(await harness.plugin.getPendingQuestions(sessionId: "root"), isEmpty);

      flush.complete();
      for (var attempt = 0; attempt < 20; attempt++) {
        if ((await harness.plugin.getPendingQuestions(sessionId: "root")).isNotEmpty) break;
        await Future<void>.delayed(Duration.zero);
      }
      final pending = await harness.plugin.getPendingQuestions(sessionId: "root");
      expect(pending.single.questions.single.question, "New");
      expect(fake.written.singleWhere((frame) => frame["id"] == 81)["error"], {
        "code": -32603,
        "message": "aborted",
      });
      expect(fake.written.singleWhere((frame) => frame["id"] == 82)["result"], isEmpty);
      harness.reply(frame: writing, result: const {"stopReason": "end_turn"});
    });

    test("tree-stop failure retains the original RPC error and busy state", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      final failure = expectLater(
        stopping,
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.operation, "operation", DeepSeekAcpApi.sessionStopMethod)
              .having((error) => error.message, "message", "DeepSeek scoped stop failed for session root")
              .having(
                (error) => error.cause,
                "cause",
                isA<AcpRpcException>()
                    .having((error) => error.code, "code", -32603)
                    .having((error) => error.message, "message", "stop failed"),
              ),
        ),
      );
      final request = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      harness.fake.emit({
        "jsonrpc": "2.0",
        "id": request["id"],
        "error": {"code": -32603, "message": "stop failed"},
      });
      await failure;
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isTrue);
    });
  });
}

class _StopHarness({FakeAcpProcess? fake}) {
  final FakeAcpProcess fake = fake ?? FakeAcpProcess();
  late final DeepSeekPlugin plugin = buildDeepSeekTestPlugin(fake: fake);

  List<Map<String, dynamic>> get cancels => fake.written.where((f) => f["method"] == AcpMethods.sessionCancel).toList();
  List<Map<String, dynamic>> get interrupts =>
      fake.written.where((f) => f["method"] == DeepSeekAcpApi.subagentInterruptMethod).toList();

  Future<Map<String, dynamic>> waitFor({required String method, required int count}) async {
    for (var i = 0; i < 100; i++) {
      final frames = fake.written.where((frame) => frame["method"] == method).toList();
      if (frames.length >= count) return frames[count - 1];
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError("Missing frame $count: $method");
  }

  Future<void> connect() async {
    final connecting = plugin.ensureConnected();
    final frame = await waitFor(method: AcpMethods.initialize, count: 1);
    fake.emit({
      "jsonrpc": "2.0",
      "id": frame["id"],
      "result": {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{"loadSession": true},
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
    plugin.mapper.setSessionProject("root", "/repo");
  }

  Future<void> prompt({required String sessionId}) async {
    await plugin.sendPrompt(
      sessionId: sessionId,
      promptId: "prompt",
      parts: const [PluginPromptPart.text(text: "Work")],
      variant: null,
      agent: null,
      model: null,
    );
    final loading = await waitFor(method: AcpMethods.sessionLoad, count: 1);
    expect((loading["params"] as Map)["sessionId"], sessionId);
    fake.emit({"jsonrpc": "2.0", "id": loading["id"], "result": <String, dynamic>{}});
    await waitFor(method: AcpMethods.sessionPrompt, count: 1);
  }

  void emitQuestion({
    required int requestId,
    required String sessionId,
    required String text,
    required String questionId,
  }) {
    fake.emit({
      "jsonrpc": "2.0",
      "id": requestId,
      "method": DeepSeekAcpApi.askUserQuestionMethod,
      "params": {
        "sessionId": sessionId,
        "questions": [
          {"id": questionId, "text": text},
        ],
      },
    });
  }

  Future<void> spawn({required String child, required String parent, required bool background}) async {
    fake.emit({
      "jsonrpc": "2.0",
      "method": DeepSeekAcpApi.subagentMethod,
      "params": {
        "kind": "started",
        "sessionId": parent,
        "childSessionId": child,
        "toolCallId": "call-$child",
        "prompt": "Work",
        "label": "Child",
        "mode": background ? "background" : "foreground",
      },
    });
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> end({required String child, required String parent}) async {
    fake.emit({
      "jsonrpc": "2.0",
      "method": DeepSeekAcpApi.subagentMethod,
      "params": {
        "kind": "ended",
        "sessionId": parent,
        "childSessionId": child,
        "stopReason": "aborted",
      },
    });
    await Future<void>.delayed(Duration.zero);
  }

  void reply({required Map<String, dynamic> frame, required Map<String, dynamic> result}) {
    fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
  }

  Future<void> replyInterrupts({required Map<String, String> results}) async {
    await waitFor(method: DeepSeekAcpApi.subagentInterruptMethod, count: results.length);
    for (final frame in interrupts) {
      final child = (frame["params"] as Map)["childSessionId"];
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "result": {"result": results[child]},
      });
    }
  }

  Future<void> close() async {
    for (final frame in fake.written.where((frame) => frame["method"] == AcpMethods.sessionPrompt)) {
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "result": {"stopReason": "cancelled"},
      });
    }
    await Future<void>.delayed(Duration.zero);
    await plugin.dispose();
    await fake.close();
  }
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
