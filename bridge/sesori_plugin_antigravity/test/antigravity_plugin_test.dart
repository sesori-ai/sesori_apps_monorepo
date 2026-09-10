import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _old = "00000000-0000-4000-8000-000000000001";
const _secret = "synthetic-private-state";

enum _Auth() {
  personal,
  challenge,
  enterprise,
  failure,
}

class _Input({required final void Function({required Map<String, dynamic> frame}) receive}) extends CapturingIOSink {
  @override
  void add(List<int> bytes) {
    super.add(bytes);
    receive(frame: frames.last);
  }
}

class _Process() implements AcpProcessHandle {
  final out = StreamController<List<int>>();
  final err = StreamController<List<int>>();
  final exit = Completer<int>();
  final requests = StreamController<Map<String, dynamic>>.broadcast();
  final held = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  final listedSessions = <Map<String, dynamic>>[];
  _Auth auth = _Auth.personal;
  bool resume = true;
  bool holdPrompts = false;
  String defaultModelId = "default";
  String defaultModelName = "Default";
  String otherModelId = "other";
  String otherModelName = "Other";
  int created = 0;
  int kills = 0;
  bool outTapped = false;
  bool errTapped = false;

  @override
  late final _Input stdin = _Input(receive: _receive);
  @override
  Stream<List<int>> get stdout {
    outTapped = true;
    return out.stream;
  }

  @override
  Stream<List<int>> get stderr {
    errTapped = true;
    return err.stream;
  }

  @override
  Future<int> get exitCode => exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    kills++;
    if (!exit.isCompleted) exit.complete(-15);
    return true;
  }

  void emit({required Map<String, dynamic> frame}) => out.add(utf8.encode("${jsonEncode(frame)}\n"));
  void reply({required Map<String, dynamic> request, required Map<String, dynamic> result}) =>
      emit(frame: {"jsonrpc": "2.0", "id": request["id"], "result": result});

  void _receive({required Map<String, dynamic> frame}) {
    requests.add(frame);
    final params = frame["params"] as Map<String, dynamic>? ?? {};
    switch (frame["method"]) {
      case "initialize":
        if (auth == _Auth.failure) {
          emit(
            frame: {
              "id": frame["id"],
              "error": {"code": -32000, "message": "synthetic failure"},
            },
          );
        } else {
          reply(
            request: frame,
            result: {
              "protocolVersion": 1,
              "authMethods": [
                {"id": auth == _Auth.enterprise ? "enterprise" : "oauth-personal", "name": "Synthetic"},
              ],
              "agentCapabilities": {
                "loadSession": true,
                "sessionCapabilities": {"list": <String, dynamic>{}, if (resume) "resume": <String, dynamic>{}},
              },
            },
          );
        }
      case "authenticate":
        expect(params["methodId"], "oauth-personal");
        if (auth == _Auth.challenge) {
          final bytes = utf8.encode(
            "${AntigravityAuthorizationMapper.prefix}https://accounts.google.com/o/oauth2/v2/auth?state=$_secret\r\n",
          );
          for (final byte in bytes) {
            out.add([byte]);
          }
          err.add(utf8.encode("state=$_secret\nuseful diagnostic\n"));
        } else {
          reply(request: frame, result: {});
        }
      case "session/new":
        final sessionId = "new-${++created}";
        listedSessions.add({"sessionId": sessionId, "cwd": params["cwd"]});
        reply(
          request: frame,
          result: _catalog(
            session: sessionId,
            current: defaultModelId,
            defaultModelId: defaultModelId,
            defaultModelName: defaultModelName,
            otherModelId: otherModelId,
            otherModelName: otherModelName,
          ),
        );
      case "session/list":
        final cwd = params["cwd"];
        reply(
          request: frame,
          result: {
            "sessions": [
              for (final session in listedSessions)
                if (cwd == null || session["cwd"] == cwd) session,
            ],
          },
        );
      case "session/load":
      case "session/resume":
        for (final update in updates) {
          emit(
            frame: {
              "method": "session/update",
              "params": {"sessionId": params["sessionId"], "update": update},
            },
          );
        }
        reply(
          request: frame,
          result: _catalog(
            session: params["sessionId"] as String,
            current: otherModelId,
            defaultModelId: defaultModelId,
            defaultModelName: defaultModelName,
            otherModelId: otherModelId,
            otherModelName: otherModelName,
          ),
        );
      case "session/set_config_option":
      case "session/set_mode":
        reply(request: frame, result: {});
      case "session/prompt":
        if (holdPrompts) {
          held.add(frame);
        } else {
          reply(request: frame, result: {"stopReason": "end_turn"});
        }
      case "session/cancel":
        for (final pending in held.where((f) => (f["params"] as Map)["sessionId"] == params["sessionId"]).toList()) {
          held.remove(pending);
          reply(request: pending, result: {"stopReason": "cancelled"});
        }
    }
  }

  Future<Map<String, dynamic>> frame({required String method, int after = 0}) async {
    final found = stdin.frames.skip(after).where((f) => f["method"] == method);
    if (found.isNotEmpty) return found.last;
    return await requests.stream.firstWhere((f) => f["method"] == method).timeout(const Duration(seconds: 3));
  }

  Future<void> close() async {
    if (!outTapped) out.stream.listen(null);
    if (!errTapped) err.stream.listen(null);
    await out.close();
    await err.close();
    await requests.close();
  }
}

Map<String, dynamic> _catalog({
  required String session,
  required String current,
  required String defaultModelId,
  required String defaultModelName,
  required String otherModelId,
  required String otherModelName,
}) => {
  "sessionId": session,
  "configOptions": [
    {
      "id": "model",
      "type": "select",
      "currentValue": current,
      "options": [
        {"value": defaultModelId, "name": defaultModelName},
        {"value": otherModelId, "name": otherModelName},
      ],
    },
  ],
};

class _Harness({required final Directory directory, required final List<_Process> processes}) {
  Completer<void>? spawnGate;
  final specs = <AcpLaunchSpec>[];
  final events = <BridgeSseEvent>[];
  late final plugin = const AntigravityPluginComposer().compose(
    pair: const AntigravityRuntimePair(
      serverPath: "/synthetic/antigravity-acp",
      harnessPath: "/synthetic/localharness_external",
      target: PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    ),
    profile: AntigravityPreparedProfile(
      geminiHome: directory.path,
      environment: {"GEMINI_CLI_HOME": directory.path, "BROWSER": "prepared-noop"},
    ),
    launchDirectory: "/launch",
    processFactory: (spec) async {
      specs.add(spec);
      await spawnGate?.future;
      return processes[specs.length - 1];
    },
  );
  StreamSubscription<BridgeSseEvent>? subscription;
  Future<void> start() async {
    subscription = plugin.events.listen(events.add);
    expect(await plugin.ensureConnected(), isTrue);
  }

  Future<PluginSession> create() => plugin.createSession(
    directory: "/new-cwd",
    parentSessionId: null,
    parts: const [],
    userVisibleText: null,
    model: null,
    variant: null,
    agent: null,
  );
  Future<void> send({
    required String session,
    required ({String providerID, String modelID})? model,
    PluginSessionVariant? variant,
  }) => plugin.sendPrompt(
    promptId: "prompt-$session",
    sessionId: session,
    parts: const [PluginPromptPart.text(text: "synthetic")],
    model: model,
    variant: variant,
    agent: null,
  );
  Future<void> close() async {
    await subscription?.cancel();
    await plugin.dispose();
    for (final process in processes) {
      await process.close();
    }
    await directory.delete(recursive: true);
  }
}

Future<_Harness> _harness({required List<_Process> processes}) async {
  final harness = _Harness(
    directory: await Directory.systemTemp.createTemp("antigravity-composed-"),
    processes: processes,
  );
  addTearDown(harness.close);
  return harness;
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void _question({required _Process process, required String session, required String id}) => process.emit(
  frame: {
    "jsonrpc": "2.0",
    "id": id,
    "method": "session/request_permission",
    "params": {
      "sessionId": session,
      "toolCall": {"toolCallId": "interaction_$id", "title": "Synthetic?", "kind": "other"},
      "options": [
        {"optionId": "yes-id", "name": "Exact label", "kind": "allow_once"},
        {"optionId": "no-id", "name": "Other label", "kind": "reject_once"},
      ],
    },
  },
);

void main() {
  test("cold options use one hidden no-prompt discovery session and refresh resumes it", () async {
    final process = _Process();
    final h = await _harness(processes: [process]);
    final providers = await h.plugin.getProviders(projectId: "/launch");
    expect(providers.providers.single.defaultModelID, "default");
    expect((await h.plugin.getAgents(projectId: "/launch")).single.name, "antigravity");
    expect(h.specs, hasLength(1));
    expect(process.created, 1);
    final discoveryNew = process.stdin.frames.singleWhere((frame) => frame["method"] == "session/new");
    expect(
      (discoveryNew["params"] as Map)["cwd"],
      "${h.directory.path}/antigravity-acp/conversations",
    );
    expect(process.stdin.frames.where((frame) => frame["method"] == "session/prompt"), isEmpty);
    await h.start();
    final session = await h.create();
    expect(session.id, "new-2");
    expect((await h.plugin.getProviders(projectId: "/launch")).providers.single.defaultModelID, "default");
    final beforeStale = process.stdin.frames.length;
    await expectLater(
      h.send(session: session.id, model: (providerID: "antigravity", modelID: "stale")),
      throwsA(isA<PluginStaleOptionsException>().having((error) => error.operation, "operation", "sendPrompt")),
    );
    await expectLater(
      h.plugin.sendCommand(
        promptId: "stale-command",
        sessionId: session.id,
        command: "synthetic",
        arguments: "",
        userVisibleArguments: null,
        model: (providerID: "antigravity", modelID: "stale"),
        variant: null,
        agent: null,
      ),
      throwsA(isA<PluginStaleOptionsException>().having((error) => error.operation, "operation", "sendCommand")),
    );
    expect(process.stdin.frames, hasLength(beforeStale), reason: "Stale selections never enter the ACP turn queue");
    await h.send(session: session.id, model: (providerID: "antigravity", modelID: "other"));
    await process.frame(method: "session/prompt");
    final writes = process.stdin.frames
        .where((f) => f["method"] == "session/set_config_option" || f["method"] == "session/set_mode")
        .toList();
    expect((writes.last["params"] as Map)["modeId"], "default");
    expect((writes[writes.length - 2]["params"] as Map)["value"], "other");
    process.emit(
      frame: {
        "method": "session/update",
        "params": {
          "sessionId": session.id,
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "selected output"},
          },
        },
      },
    );
    await _settle();
    final assistant = h.events.whereType<BridgeSseMessageUpdated>().last.info as PluginMessageAssistant;
    expect((assistant.modelID, assistant.providerID), ("other", AntigravityIdentity.pluginId));
    expect(h.specs.single.includeParentEnvironment, isFalse);
    expect(h.specs.single.environment["GEMINI_CLI_HOME"], h.directory.path);
    final visible = await h.plugin.listAllSessions(knownDirectories: const {"/new-cwd"});
    expect(visible.map((entry) => entry.id), [session.id]);
    expect(
      await h.plugin.getSessions(projectId: "${h.directory.path}/antigravity-acp/conversations", start: 0, limit: 20),
      isEmpty,
    );
    expect(
      (await h.plugin.getSessions(projectId: "/new-cwd", start: 0, limit: 20)).map((entry) => entry.id),
      [session.id],
    );
    final beforeRefresh = process.stdin.frames.length;
    expect(
      await h.plugin.getSessionOptions(
        projectId: "/launch",
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      ),
      isA<PluginSessionOptionsDiscoveryObserved>(),
    );
    final refreshed = process.stdin.frames.skip(beforeRefresh).where((frame) => frame["method"] == "session/resume");
    expect((refreshed.single["params"] as Map)["sessionId"], "new-1");
    expect(process.created, 2, reason: "Refresh reuses discovery session and real session remains separate");
  });

  test("whitespace-bearing model IDs remain exact in fresh, selected, live and replay attribution", () async {
    final live = _Process()
      ..defaultModelId = " fresh default "
      ..otherModelId = " acknowledged selection ";
    final replay = _Process()
      ..defaultModelId = live.defaultModelId
      ..otherModelId = live.otherModelId;
    final h = await _harness(processes: [live, replay]);
    await h.start();
    final session = await h.create();

    void emitLiveAssistant({required String text}) => live.emit(
      frame: {
        "method": "session/update",
        "params": {
          "sessionId": session.id,
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": text},
          },
        },
      },
    );

    emitLiveAssistant(text: "fresh");
    await _settle();
    var assistant = h.events.whereType<BridgeSseMessageUpdated>().last.info as PluginMessageAssistant;
    expect(assistant.modelID, " fresh default ");

    await h.send(
      session: session.id,
      model: (providerID: AntigravityIdentity.pluginId, modelID: " acknowledged selection "),
    );
    await live.frame(method: "session/prompt");
    emitLiveAssistant(text: "selected");
    await _settle();
    assistant = h.events.whereType<BridgeSseMessageUpdated>().last.info as PluginMessageAssistant;
    expect(assistant.modelID, " acknowledged selection ");

    replay.updates.add({
      "sessionUpdate": "agent_message_chunk",
      "content": {"type": "text", "text": "replayed"},
    });
    final history = await h.plugin.getSessionMessages(session.id);
    final replayed = history.where((message) => message.info is PluginMessageAssistant).single.info;
    expect((replayed as PluginMessageAssistant).modelID, " acknowledged selection ");
    expect(replayed.providerID, AntigravityIdentity.pluginId);
  });

  test("exact native variant selection stamps normalized live and replay metadata", () async {
    final live = _Process()
      ..defaultModelId = "gemini-3.7-flash-high"
      ..defaultModelName = "Gemini 3.7 Flash (High)"
      ..otherModelId = "gemini-3.7-flash-low"
      ..otherModelName = "Gemini 3.7 Flash (Low)";
    final replay = _Process()
      ..defaultModelId = live.defaultModelId
      ..defaultModelName = live.defaultModelName
      ..otherModelId = live.otherModelId
      ..otherModelName = live.otherModelName;
    final h = await _harness(processes: [live, replay]);
    final provider = (await h.plugin.getProviders(projectId: "/launch")).providers.single;
    expect(provider.models.single.id, "gemini-3.7-flash");
    expect(provider.models.single.variants, ["high", "low"]);
    await h.start();
    final session = await h.create();

    await h.send(
      session: session.id,
      model: (providerID: AntigravityIdentity.pluginId, modelID: "gemini-3.7-flash"),
      variant: const PluginSessionVariant(id: "low"),
    );
    final selection = await live.frame(method: "session/set_config_option");
    await live.frame(method: "session/prompt");
    expect((selection["params"] as Map)["value"], "gemini-3.7-flash-low");
    live.emit(
      frame: {
        "method": "session/update",
        "params": {
          "sessionId": session.id,
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "live variant"},
          },
        },
      },
    );
    await _settle();
    final liveMessage = h.events.whereType<BridgeSseMessageUpdated>().last.info as PluginMessageAssistant;
    expect((liveMessage.modelID, liveMessage.variant), ("gemini-3.7-flash", "low"));

    replay.updates.add({
      "sessionUpdate": "agent_message_chunk",
      "content": {"type": "text", "text": "replayed variant"},
    });
    final history = await h.plugin.getSessionMessages(session.id);
    final replayed = history.where((message) => message.info is PluginMessageAssistant).single.info;
    expect(((replayed as PluginMessageAssistant).modelID, replayed.variant), ("gemini-3.7-flash", "low"));
  });

  for (final resume in [true, false]) {
    test(
      "cold metadata recovery drives ${resume ? 'resume' : 'load'}; DB hint wins and replay stays load-based",
      () async {
        final live = _Process()..resume = resume;
        final replay = _Process();
        final h = await _harness(processes: [live, replay]);
        final metadata = File("${h.directory.path}/antigravity-acp/conversations/$_old.meta");
        await metadata.create(recursive: true);
        await metadata.writeAsString(jsonEncode({"cwd": "/recovered-cwd"}));
        const hidden = "00000000-0000-4000-8000-000000000003";
        await File("${h.directory.path}/antigravity-acp/conversations/$hidden.meta").writeAsString(
          jsonEncode({"cwd": "${h.directory.path}/antigravity-acp/conversations"}),
        );
        await h.start();
        expect(h.plugin.directoryForSession(sessionId: hidden), "/launch");
        const later = "00000000-0000-4000-8000-000000000002";
        await File("${h.directory.path}/antigravity-acp/conversations/$later.meta").writeAsString(
          jsonEncode({"cwd": "/late-metadata"}),
        );
        await h.plugin.listAllSessions(knownDirectories: const {});
        expect(
          h.plugin.directoryForSession(sessionId: later),
          "/launch",
          reason: "Ordinary enumeration does not rescan",
        );
        await h.send(session: _old, model: null);
        final activation = await live.frame(method: resume ? "session/resume" : "session/load");
        expect((activation["params"] as Map)["cwd"], "/recovered-cwd");
        await live.frame(method: "session/prompt");
        expect((await h.plugin.getProviders(projectId: "/launch")).providers.single.defaultModelID, isNull);
        h.plugin.primeSessionDirectory(sessionId: _old, directory: "/database-cwd");
        await h.plugin.getSessionMessages(_old);
        expect((await replay.frame(method: "session/load"))["params"], containsPair("cwd", "/database-cwd"));
        expect(replay.stdin.frames.where((f) => f["method"] == "session/resume"), isEmpty);
        expect(replay.kills, 1);
        await h.plugin.deleteSession(_old);
        expect(
          metadata.existsSync(),
          isTrue,
          reason: "Local delete never deletes Google history; bridge tombstones own reimport exclusion",
        );
      },
    );
  }

  test("two sessions and long replay share native normalization without replay events leaking live", () async {
    final live = _Process();
    final replay = _Process();
    final h = await _harness(processes: [live, replay]);
    await h.start();
    final first = await h.create();
    final second = await h.create();
    final update = <String, dynamic>{
      "sessionUpdate": "tool_call",
      "toolCallId": "native",
      "status": "completed",
      "rawInput": {"command": "pwd"},
      "rawOutput": {"stdout": "synthetic-output", "exit_code": 2},
    };
    live.emit(
      frame: {
        "method": "session/update",
        "params": {"sessionId": first.id, "update": update},
      },
    );
    await _settle();
    final liveTool = h.events.whereType<BridgeSseMessagePartUpdated>().last.part;
    for (var turn = 0; turn < 60; turn++) {
      replay.updates.add({
        "sessionUpdate": "user_message_chunk",
        "content": {"type": "text", "text": "question-$turn"},
      });
      replay.updates.add({
        "sessionUpdate": "agent_message_chunk",
        "content": {"type": "text", "text": "answer-$turn"},
      });
    }
    replay.updates.add(update);
    final before = h.events.whereType<BridgeSseMessagePartUpdated>().length;
    final history = await h.plugin.getSessionMessages(second.id);
    expect(history.length, 121);
    final replayAssistant =
        history.where((message) => message.info is PluginMessageAssistant).first.info as PluginMessageAssistant;
    expect((replayAssistant.modelID, replayAssistant.providerID), ("other", AntigravityIdentity.pluginId));
    expect(history.last.parts.last.state, liveTool.state);
    expect(h.events.whereType<BridgeSseMessagePartUpdated>().length, before);
    expect((await h.plugin.getProviders(projectId: "/launch")).providers.single.defaultModelID, "default");
    expect(live.kills, 0);
    expect(replay.kills, 1);
  });

  test(
    "question answer uses exact advertised ID and cancellation/delete clear connection-owned pending state",
    () async {
      final process = _Process();
      final h = await _harness(processes: [process]);
      await h.start();
      final first = await h.create();
      final second = await h.create();
      process.holdPrompts = true;
      await h.send(session: first.id, model: null);
      await process.frame(method: "session/prompt");
      final afterFirst = process.stdin.frames.length;
      await h.send(session: second.id, model: null);
      await process.frame(method: "session/prompt", after: afterFirst);
      _question(process: process, session: first.id, id: "answer");
      await _settle();
      final question = (await h.plugin.getPendingQuestions(sessionId: first.id)).single;
      await h.plugin.replyToQuestion(
        questionId: question.id,
        sessionId: first.id,
        answers: [
          ["Exact label"],
        ],
      );
      expect(process.stdin.frames.last["result"], {
        "outcome": {"outcome": "selected", "optionId": "yes-id"},
      });
      _question(process: process, session: first.id, id: "cancel");
      _question(process: process, session: second.id, id: "delete");
      await _settle();
      await h.plugin.abortSession(
        sessionId: first.id,
        subAgents: PluginAbortSubAgentPolicy.stop,
        useAtomicStop: false,
        knownSubAgentSessionIds: const {},
      );
      expect(await h.plugin.getPendingQuestions(sessionId: first.id), isEmpty);
      expect(await h.plugin.getPendingQuestions(sessionId: second.id), hasLength(1));
      expect(process.held, hasLength(1));
      await h.plugin.deleteSession(second.id);
      expect(process.held, isEmpty);
      expect(await h.plugin.getPendingQuestions(sessionId: second.id), isEmpty);
      for (final id in ["cancel", "delete"]) {
        expect(process.stdin.frames.singleWhere((f) => f["id"] == id)["result"], {
          "outcome": {"outcome": "cancelled"},
        });
      }
    },
  );

  test("crash clears catalog/pending input; reconnect resumes and global interruption settles held turns", () async {
    final old = _Process();
    final replacement = _Process()..holdPrompts = true;
    final h = await _harness(processes: [old, replacement]);
    await h.start();
    final first = await h.create();
    final second = await h.create();
    _question(process: old, session: first.id, id: "crash");
    await _settle();
    old.exit.complete(17);
    // Drive the existing reset explicitly; this fake does not include the host exit watch.
    await h.plugin.resetConnectionAfterExit();
    expect(await h.plugin.getPendingQuestions(sessionId: first.id), isEmpty);
    final rediscovered = await h.plugin.getProviders(projectId: "/launch");
    expect(rediscovered.providers.single.defaultModelID, "default");
    expect(replacement.stdin.frames.where((f) => f["method"] == "session/new"), hasLength(1));
    await h.send(session: first.id, model: (providerID: "antigravity", modelID: "other"));
    await replacement.frame(method: "session/prompt");
    final resumed = replacement.stdin.frames.where((f) => f["method"] == "session/resume").single;
    expect((resumed["params"] as Map)["sessionId"], first.id);
    final selection = replacement.stdin.frames.where((f) => f["method"] == "session/set_config_option").single;
    expect((selection["params"] as Map)["value"], "other");
    final after = replacement.stdin.frames.length;
    await h.send(session: second.id, model: null);
    await replacement.frame(method: "session/prompt", after: after);
    expect(replacement.held, hasLength(2));
    await h.plugin.interruptActiveWork(budget: const Duration(seconds: 2));
    expect(replacement.held, isEmpty);
    await h.plugin.dispose();
    await h.plugin.dispose();
    expect(replacement.kills, 1);
  });

  for (final replay in [false, true]) {
    test(
      "${replay ? 'replay' : 'live'} stale authentication preserves typed cause and cleanup without URL logging",
      () async {
        final logs = BufferingStdout();
        final previous = Log.level;
        Log.level = LogLevel.debug;
        addTearDown(() => Log.level = previous);
        await IOOverrides.runZoned(() async {
          final process = _Process()..auth = _Auth.challenge;
          final h = await _harness(processes: [process]);
          h.plugin.primeSessionDirectory(sessionId: _old, directory: "/known");
          final failure = replay ? null : h.plugin.onAuthenticationFailure.first;
          final Future<Object?> operation = replay ? h.plugin.getSessionMessages(_old) : h.create();
          await operation.then<void>(
            (_) => fail("Expected authentication failure"),
            onError: (Object error, StackTrace stack) {
              expect(
                error,
                isA<PluginAuthenticationRequiredException>().having(
                  (e) => e.cause,
                  "original wrapper",
                  isA<AcpOutputInterceptionException>(),
                ),
              );
              expect(stack.toString(), contains("AntigravityOutputComposer._consumeStdout"));
            },
          );
          if (failure != null) {
            expect(await failure, AntigravityOutputComposer.authenticationHint);
            expect(h.plugin.authenticationFailureActionHint, AntigravityOutputComposer.authenticationHint);
          }
          expect(process.kills, 1);
          expect(process.created, 0);
        }, stderr: () => logs);
        expect(logs.text, isNot(contains(_secret)));
        expect(logs.text, isNot(contains("accounts.google.com")));
      },
    );
  }

  test("dispose during a pending spawn fences initialization and reaps the late process", () async {
    final process = _Process();
    final h = await _harness(processes: [process]);
    final gate = Completer<void>();
    h.spawnGate = gate;
    final connecting = h.plugin.ensureConnected();
    await _settle();
    await h.plugin.dispose();
    gate.complete();
    expect(await connecting, isFalse);
    expect(process.kills, 1);
    expect(process.stdin.frames, isEmpty);
  });

  test("ordinary replay initialize failure remains a protocol cause, not authentication", () async {
    final process = _Process()..auth = _Auth.failure;
    final h = await _harness(processes: [process]);
    h.plugin.primeSessionDirectory(sessionId: _old, directory: "/known");
    await expectLater(
      h.plugin.getSessionMessages(_old),
      throwsA(isA<PluginOperationException>().having((e) => e.cause, "original RPC cause", isA<AcpRpcException>())),
    );
    expect(process.kills, 1);
    expect(h.plugin.authenticationFailureActionHint, isNull);
  });

  test("enterprise-only initialize cannot launch invisible login and non-auth failure remains non-auth", () async {
    for (final auth in [_Auth.enterprise, _Auth.failure]) {
      final process = _Process()..auth = auth;
      final h = await _harness(processes: [process]);
      expect(await h.plugin.ensureConnected(), isFalse);
      expect(process.stdin.frames.where((f) => f["method"] == "authenticate"), isEmpty);
      expect(process.kills, 1);
    }
    const error = FormatException("synthetic ordinary failure");
    final h = await _harness(processes: []);
    expect(h.plugin.mapInitializationFailure(error: error), same(error));
    final stock = composeTestAcpPlugin(processFactory: (_) async => _Process());
    expect(stock.mapInitializationFailure(error: error), same(error));
    await stock.dispose();
  });
}
