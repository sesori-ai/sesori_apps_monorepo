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

    test("confirm rejection is side-effect free", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: true);
      final before = harness.fake.written.length;

      final result = await harness.atomicAbort(sessionId: "root", policy: PluginAbortSubAgentPolicy.confirm);

      expect(
        result,
        isA<PluginAbortRejectedSubAgentsRunning>()
            .having((result) => result.runningSubAgentCount, "children", 1)
            .having((result) => result.mainAgentRunning, "main", true)
            .having((result) => result.mainAgentOnlySupported, "keep supported", true),
      );
      expect(harness.fake.written, hasLength(before));
    });

    for (final resident in [false, true]) {
      test("confirm preserves an accepted child turn before dispatch (resident: $resident)", () async {
        await harness.spawn(child: "child", parent: "root", background: true);
        await harness.end(child: "child", parent: "root");
        if (resident) {
          harness.settlePrompt(await harness.prompt(sessionId: "child"));
          await harness.waitForIdle();
        }
        await harness.queuePromptUntilLoad(sessionId: "child");

        final result = await harness.atomicAbort(
          sessionId: "root",
          policy: PluginAbortSubAgentPolicy.confirm,
          knownSubAgentSessionIds: const {"child"},
        );

        expect(result, isA<PluginAbortRejectedSubAgentsRunning>());
        expect(harness.stops, isEmpty);
        expect(harness.cancels, isEmpty);
        expect(harness.interrupts, isEmpty);
        if (!resident) {
          final load = await harness.waitForSession(method: AcpMethods.sessionLoad, sessionId: "child");
          harness.reply(frame: load, result: <String, dynamic>{});
        }
        harness.settlePrompt(await harness.waitFor(method: AcpMethods.sessionPrompt, count: resident ? 2 : 1));
      });
    }

    test("unsupported keep is side-effect free", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "foreground", parent: "root", background: false);
      final before = harness.fake.written.length;

      final result = await harness.atomicAbort(sessionId: "root", policy: PluginAbortSubAgentPolicy.keep);

      expect(
        result,
        isA<PluginAbortRejectedSubAgentsRunning>().having(
          (result) => result.mainAgentOnlySupported,
          "keep supported",
          false,
        ),
      );
      expect(harness.fake.written, hasLength(before));
    });

    test("independently resident foreground child does not reject root keep", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: false);
      await harness.prompt(sessionId: "child");

      final result = await harness.atomicAbort(
        sessionId: "root",
        policy: PluginAbortSubAgentPolicy.keep,
        knownSubAgentSessionIds: const {"child"},
      );

      expect(result, isA<PluginAbortAccepted>().having((result) => result.workKept, "kept", true));
      expect(harness.cancels.single["params"], {"sessionId": "root"});
      expect(harness.stops, isEmpty);
    });

    test("native root scope covers delayed nested admission", () async {
      await harness.prompt(sessionId: "root");
      final stopping = harness.atomicAbort(sessionId: "root");
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(stop["params"], {"kind": "session", "sessionId": "root"});

      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.spawn(child: "grandchild", parent: "child", background: true);
      harness.reply(frame: stop, result: {"workKept": false});

      expect(
        await stopping,
        isA<PluginAbortAccepted>()
            .having((result) => result.workKept, "kept", false)
            .having((result) => result.subAgentsHandled, "handled", true),
      );
      expect(harness.stops, hasLength(1));
      expect(harness.plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"child", "grandchild"});
    });

    test("settled independent child remains a scope while its grandchild runs", () async {
      final rootPrompt = await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: true);
      final childPrompt = await harness.prompt(sessionId: "child");
      harness.settlePrompt(childPrompt);
      await harness.spawn(child: "grandchild", parent: "child", background: true);

      final stopping = harness.atomicAbort(
        sessionId: "root",
        knownSubAgentSessionIds: const {"child", "grandchild"},
      );
      await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 2);
      expect(
        harness.stops.map((frame) => frame["params"]),
        unorderedEquals([
          {"kind": "session", "sessionId": "root"},
          {"kind": "session", "sessionId": "child"},
        ]),
      );
      harness.replyStops(workKeptBySession: const {"root": false, "child": true});

      expect(await stopping, isA<PluginAbortAccepted>().having((result) => result.workKept, "OR result", true));
      harness.settlePrompt(rootPrompt);
    });

    test("nested independently resident roots all receive native stops", () async {
      final prompts = <Map<String, dynamic>>[await harness.prompt(sessionId: "root")];
      await harness.spawn(child: "child", parent: "root", background: true);
      prompts.add(await harness.prompt(sessionId: "child"));
      await harness.spawn(child: "grandchild", parent: "child", background: true);
      prompts.add(await harness.prompt(sessionId: "grandchild"));

      final stopping = harness.atomicAbort(
        sessionId: "root",
        knownSubAgentSessionIds: const {"child", "grandchild"},
      );
      await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 3);
      expect(
        harness.stops.map((frame) => (frame["params"] as Map)["sessionId"]),
        unorderedEquals(["root", "child", "grandchild"]),
      );
      harness.replyStops(workKeptBySession: const {"root": false, "child": false, "grandchild": false});
      expect(await stopping, isA<PluginAbortAccepted>());
      prompts.forEach(harness.settlePrompt);
    });

    test("all stop frames precede a later prompt and responses cannot erase it", () async {
      final rootPrompt = await harness.prompt(sessionId: "root");
      harness.settlePrompt(rootPrompt);
      await harness.spawn(child: "child", parent: "root", background: true);
      final childPrompt = await harness.prompt(sessionId: "child");
      harness.settlePrompt(childPrompt);

      final stopping = harness.atomicAbort(sessionId: "root", knownSubAgentSessionIds: const {"child"});
      await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 2);
      final laterPrompt = await harness.prompt(sessionId: "root");
      final laterPromptIndex = harness.fake.written.indexOf(laterPrompt);
      expect(harness.stops.every((frame) => harness.fake.written.indexOf(frame) < laterPromptIndex), isTrue);

      harness.replyStops(workKeptBySession: const {"root": false, "child": false});
      expect(await stopping, isA<PluginAbortAccepted>());
      expect(harness.fake.written, contains(same(laterPrompt)));
      harness.settlePrompt(laterPrompt);
    });

    test("partial native failure still dispatches and waits for every scope", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.prompt(sessionId: "child");
      var completed = false;
      final stopping = harness
          .atomicAbort(sessionId: "root", knownSubAgentSessionIds: const {"child"})
          .whenComplete(() => completed = true);
      final failure = expectLater(
        stopping,
        throwsA(
          isA<PluginOperationException>().having(
            (error) => error.cause,
            "cause",
            isA<AcpRpcException>().having((error) => error.message, "message", "stop failed"),
          ),
        ),
      );
      await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 2);
      final rootStop = harness.stopFor(sessionId: "root");
      harness.fake.emit({
        "jsonrpc": "2.0",
        "id": rootStop["id"],
        "error": {"code": -32603, "message": "stop failed"},
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      harness.reply(
        frame: harness.stopFor(sessionId: "child"),
        result: {"workKept": false},
      );
      await failure;
      expect(harness.stops, hasLength(2));
    });

    test("pending-load child is cleared without inventing native ownership", () async {
      final rootPrompt = await harness.prompt(sessionId: "root");
      harness.settlePrompt(rootPrompt);
      await harness.queuePromptUntilLoad(sessionId: "queued-child");
      final loading = await harness.waitForSession(method: AcpMethods.sessionLoad, sessionId: "queued-child");

      final stopping = harness.atomicAbort(
        sessionId: "root",
        knownSubAgentSessionIds: const {"queued-child"},
      );
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(stop["params"], {"kind": "session", "sessionId": "root"});
      harness.reply(frame: stop, result: {"workKept": false});
      expect(await stopping, isA<PluginAbortAccepted>());

      harness.reply(frame: loading, result: <String, dynamic>{});
      await harness.waitForIdle();
      expect(harness.stops, hasLength(1));
      expect(
        harness.fake.written.where(
          (frame) =>
              frame["method"] == AcpMethods.sessionPrompt && (frame["params"] as Map)["sessionId"] == "queued-child",
        ),
        isEmpty,
      );
    });

    test("keep clears a queued root without inventing native ownership", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.queuePromptUntilLoad(sessionId: "root");
      final loading = await harness.waitForSession(method: AcpMethods.sessionLoad, sessionId: "root");
      final before = harness.fake.written.length;

      final result = await harness.atomicAbort(
        sessionId: "root",
        policy: PluginAbortSubAgentPolicy.keep,
        knownSubAgentSessionIds: const {"child"},
      );

      expect(result, isA<PluginAbortAccepted>().having((result) => result.workKept, "kept", true));
      expect(harness.fake.written, hasLength(before));
      harness.reply(frame: loading, result: <String, dynamic>{});
      await harness.end(child: "child", parent: "root");
      await harness.waitForIdle();
      expect(
        harness.fake.written.where(
          (frame) => frame["method"] == AcpMethods.sessionPrompt && (frame["params"] as Map)["sessionId"] == "root",
        ),
        isEmpty,
      );
    });

    test("terminal retained named child uses exact direct-parent authority", () async {
      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.end(child: "child", parent: "root");

      final stopping = harness.atomicAbort(sessionId: "child");
      final stop = await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 1);
      expect(stop["params"], {"kind": "child", "sessionId": "root", "childSessionId": "child"});
      harness.reply(frame: stop, result: {"workKept": false});
      expect(await stopping, isA<PluginAbortAccepted>());
      expect(harness.cancels, isEmpty);
    });

    test("released-client opt-out preserves named cancellation and client fanout", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: true);

      final result = await harness.plugin.abortSession(
        sessionId: "root",
        subAgents: PluginAbortSubAgentPolicy.stop,
        useAtomicStop: false,
        knownSubAgentSessionIds: const {"child"},
      );

      expect(result, isA<PluginAbortAccepted>().having((result) => result.subAgentsHandled, "handled", false));
      expect(harness.cancels.single["params"], {"sessionId": "root"});
      expect(harness.stops, isEmpty);
      expect(harness.interrupts, isEmpty);
    });

    test("delete, reset, and no-client paths do not retain native ownership", () async {
      final rootPrompt = await harness.prompt(sessionId: "root");
      harness.settlePrompt(rootPrompt);
      await harness.plugin.deleteSession("root");
      final afterDelete = await harness.atomicAbort(sessionId: "root");
      expect(afterDelete, isA<PluginAbortAccepted>().having((result) => result.subAgentsHandled, "handled", true));
      expect(harness.stops, isEmpty);

      final otherPrompt = await harness.prompt(sessionId: "other");
      harness.settlePrompt(otherPrompt);
      await harness.plugin.resetConnectionAfterExit();
      final afterReset = await harness.atomicAbort(sessionId: "other");
      expect(afterReset, isA<PluginAbortAccepted>());
      expect(harness.stops, isEmpty);

      final disconnected = _StopHarness();
      final noClient = await disconnected.atomicAbort(sessionId: "never-loaded");
      expect(noClient, isA<PluginAbortAccepted>().having((result) => result.subAgentsHandled, "handled", true));
      await disconnected.close();
    });

    test("whole-plugin stop deduplicates native scopes and waits for lifecycle", () async {
      await harness.prompt(sessionId: "root");
      await harness.spawn(child: "child", parent: "root", background: true);
      await harness.end(child: "child", parent: "root");
      final childPrompt = await harness.prompt(sessionId: "child");
      await harness.spawn(child: "grandchild", parent: "child", background: true);
      var settled = false;
      final stopping = harness.plugin.interruptActiveWork(budget: const Duration(seconds: 2)).then((value) {
        settled = true;
        return value;
      });
      await harness.waitFor(method: DeepSeekAcpApi.sessionStopMethod, count: 2);
      expect(harness.stops, hasLength(2));
      harness.replyStops(workKeptBySession: const {"root": false, "child": false});
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      await harness.end(child: "grandchild", parent: "child");
      final prompt = await harness.waitForSession(method: AcpMethods.sessionPrompt, sessionId: "root");
      harness.settlePrompt(prompt);
      harness.settlePrompt(childPrompt);
      expect(await stopping, containsAll(["root", "child", "grandchild"]));
    });
  });
}

class _StopHarness() {
  final fake = FakeAcpProcess();
  late final DeepSeekPlugin plugin = buildDeepSeekTestPlugin(fake: fake);
  var _promptIndex = 0;

  List<Map<String, dynamic>> get cancels =>
      fake.written.where((frame) => frame["method"] == AcpMethods.sessionCancel).toList();
  List<Map<String, dynamic>> get interrupts =>
      fake.written.where((frame) => frame["method"] == DeepSeekAcpApi.subagentInterruptMethod).toList();
  List<Map<String, dynamic>> get stops =>
      fake.written.where((frame) => frame["method"] == DeepSeekAcpApi.sessionStopMethod).toList();

  Future<PluginAbortResult> atomicAbort({
    required String sessionId,
    PluginAbortSubAgentPolicy policy = PluginAbortSubAgentPolicy.stop,
    Set<String> knownSubAgentSessionIds = const {},
  }) => plugin.abortSession(
    sessionId: sessionId,
    subAgents: policy,
    useAtomicStop: true,
    knownSubAgentSessionIds: knownSubAgentSessionIds,
  );

  Future<Map<String, dynamic>> waitFor({required String method, required int count}) async {
    for (var i = 0; i < 100; i++) {
      final frames = fake.written.where((frame) => frame["method"] == method).toList();
      if (frames.length >= count) return frames[count - 1];
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError("Missing frame $count: $method");
  }

  Future<Map<String, dynamic>> waitForSession({required String method, required String sessionId}) async {
    for (var i = 0; i < 100; i++) {
      for (final frame in fake.written.reversed) {
        if (frame["method"] == method && (frame["params"] as Map)["sessionId"] == sessionId) return frame;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError("Missing $method for $sessionId");
  }

  Map<String, dynamic> stopFor({required String sessionId}) => stops.singleWhere(
    (frame) => (frame["params"] as Map)["sessionId"] == sessionId,
  );

  void reply({required Map<String, dynamic> frame, required Map<String, dynamic> result}) {
    fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
  }

  void replyStops({required Map<String, bool> workKeptBySession}) {
    for (final frame in stops) {
      final sessionId = (frame["params"] as Map)["sessionId"] as String;
      if (workKeptBySession.containsKey(sessionId)) {
        reply(frame: frame, result: {"workKept": workKeptBySession[sessionId]});
      }
    }
  }

  Future<void> connect() async {
    final connecting = plugin.ensureConnected();
    final frame = await waitFor(method: AcpMethods.initialize, count: 1);
    reply(
      frame: frame,
      result: {
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
    );
    expect(await connecting, isTrue);
    plugin.mapper.setSessionProject("root", "/repo");
  }

  Future<Map<String, dynamic>> prompt({required String sessionId}) async {
    final firstNewFrame = fake.written.length;
    await queuePromptUntilLoad(sessionId: sessionId);
    Map<String, dynamic>? repliedLoad;
    for (var i = 0; i < 100; i++) {
      final newFrames = fake.written.skip(firstNewFrame);
      for (final frame in newFrames) {
        if ((frame["params"] as Map? ?? const {})["sessionId"] != sessionId) continue;
        if (frame["method"] == AcpMethods.sessionLoad && !identical(frame, repliedLoad)) {
          repliedLoad = frame;
          reply(frame: frame, result: <String, dynamic>{});
        }
        if (frame["method"] == AcpMethods.sessionPrompt) return frame;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError("Missing new prompt for $sessionId");
  }

  Future<void> waitForIdle() async {
    for (var i = 0; i < 100; i++) {
      if (plugin.currentWorkState == PluginWorkState.idle) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError("Plugin did not become idle");
  }

  Future<void> queuePromptUntilLoad({required String sessionId}) => plugin.sendPrompt(
    sessionId: sessionId,
    promptId: "prompt-${_promptIndex++}",
    parts: const [PluginPromptPart.text(text: "Work")],
    variant: null,
    agent: null,
    model: null,
  );

  void settlePrompt(Map<String, dynamic> frame) {
    reply(frame: frame, result: {"stopReason": "cancelled"});
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

  Future<void> close() async {
    for (final frame in fake.written.where((frame) => frame["method"] == AcpMethods.sessionPrompt)) {
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "result": {"stopReason": "cancelled"},
      });
    }
    for (final frame in stops) {
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "result": {"workKept": false},
      });
    }
    await Future<void>.delayed(Duration.zero);
    await plugin.dispose();
    await fake.close();
  }
}
