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

    test("stop uses each direct parent and keeps cancellation settlement authoritative", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "background", parent: "root", background: true);
      await harness.spawn(child: "foreground", parent: "background", background: false);
      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      await harness.replyInterrupts(results: const {"background": "interrupted", "foreground": "not_cancellable"});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", false));
      expect(
        harness.interrupts.map((f) => f["params"]),
        unorderedEquals([
          {"sessionId": "root", "childSessionId": "background"},
          {"sessionId": "background", "childSessionId": "foreground"},
        ]),
      );
      expect(harness.cancels.single["params"], {"sessionId": "root"});
      expect(harness.plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"background", "foreground"});
      await harness.end(child: "foreground", parent: "background");
      await harness.end(child: "background", parent: "root");
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
    });

    test("unknown child during settlement is neither kept nor synthetically finished", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      await harness.replyInterrupts(results: const {"child": "unknown_child"});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", false));
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isTrue);
      await harness.end(child: "child", parent: "root");
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
    });

    test("non-cancellable named child is retained without cancelling its parent or sibling", () async {
      await harness.spawn(child: "child", parent: "root", background: false);
      await harness.spawn(child: "sibling", parent: "root", background: true);
      final stopping = harness.plugin.abortSession(sessionId: "child", subAgents: PluginAbortSubAgentPolicy.stop);
      await harness.replyInterrupts(results: const {"child": "not_cancellable"});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", true));
      expect(harness.cancels, isEmpty);
      expect(harness.interrupts, hasLength(1));
      expect(harness.plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"child", "sibling"});
    });

    test("a finished child opened for a new user turn uses standard cancellation", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.end(child: "child", parent: "root");
      await harness.prompt(sessionId: "child");
      final result = await harness.plugin.abortSession(sessionId: "child", subAgents: PluginAbortSubAgentPolicy.stop);
      expect(result, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", false));
      expect(harness.cancels.single["params"], {"sessionId": "child"});
      expect(harness.interrupts, isEmpty);
    });

    test("whole-plugin stop also cancels a new user turn on a finished child", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.end(child: "child", parent: "root");
      await harness.prompt(sessionId: "child");
      final stopping = harness.plugin.interruptActiveWork(budget: const Duration(seconds: 2));
      await harness.waitFor(method: AcpMethods.sessionCancel, count: 2);
      expect(harness.cancels.map((frame) => (frame["params"] as Map)["sessionId"]), contains("child"));
      final prompt = await harness.waitFor(method: AcpMethods.sessionPrompt, count: 1);
      harness.fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "cancelled"},
      });
      expect(await stopping, contains("child"));
      expect(harness.interrupts, isEmpty);
    });

    test("foreground descendants are covered by root cancellation", () async {
      await harness.spawn(child: "parent", parent: "root", background: false);
      await harness.spawn(child: "child", parent: "parent", background: false);
      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      await harness.replyInterrupts(results: const {"parent": "not_cancellable", "child": "not_cancellable"});
      expect(await stopping, isA<PluginAbortAccepted>().having((r) => r.workKept, "kept", false));
      expect(harness.plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"parent", "child"});
    });

    test("interrupt failure keeps original RPC error and busy child state", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      final stopping = harness.plugin.abortSession(sessionId: "root", subAgents: PluginAbortSubAgentPolicy.stop);
      final failure = expectLater(
        stopping,
        throwsA(
          isA<AcpRpcException>()
              .having((error) => error.code, "code", -32603)
              .having((error) => error.message, "message", "interrupt failed"),
        ),
      );
      final request = await harness.waitFor(method: DeepSeekAcpApi.subagentInterruptMethod, count: 1);
      harness.fake.emit({
        "jsonrpc": "2.0",
        "id": request["id"],
        "error": {"code": -32603, "message": "interrupt failed"},
      });
      await failure;
      expect(harness.plugin.childSessionTracker.hasActiveWorkForRoot(sessionId: "root"), isTrue);
    });

    test("whole-plugin interruption waits for lifecycle instead of fabricating idle", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      var settled = false;
      final stopping = harness.plugin.interruptActiveWork(budget: const Duration(seconds: 2)).then((value) {
        settled = true;
        return value;
      });
      await harness.replyInterrupts(results: const {"child": "interrupted"});
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      expect(harness.plugin.currentWorkState, isNot(PluginWorkState.idle));
      await harness.end(child: "child", parent: "root");
      expect(await stopping, containsAll(["root", "child"]));
      expect(harness.plugin.currentWorkState, PluginWorkState.idle);
    });
  });
}

class _StopHarness() {
  final fake = FakeAcpProcess();
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
