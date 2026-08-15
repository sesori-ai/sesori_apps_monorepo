import "dart:async";
import "dart:convert";
import "dart:io";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/pi_rpc_client_test_factory.dart";

void main() {
  group("PiPlugin", () {
    late _Harness harness;

    setUp(() => harness = _Harness());
    tearDown(() => harness.dispose());

    test("creates a lazy session and buffers creation before any backend output", () async {
      final session = await harness.plugin.createSession(
        directory: harness.project.path,
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: "pi",
        model: null,
      );

      expect(harness.processes, isEmpty);
      expect((await harness.plugin.getSessions(harness.project.path)).single.id, session.id);
      expect(await harness.plugin.getSessionMessages(session.id), isEmpty);

      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      for (var attempt = 0; attempt < 50 && events.isEmpty; attempt++) {
        await pump();
      }
      expect(events.single, isA<BridgeSseSessionCreated>());
      await subscription.cancel();
    });

    test("buffers created before busy when the first turn starts", () async {
      await harness.plugin.createSession(
        directory: harness.project.path,
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "hello")],
        userVisibleText: "hello",
        variant: const PluginSessionVariant(id: "high"),
        agent: "pi",
        model: (providerID: "provider", modelID: "model"),
      );

      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      await pump();
      expect(events.first, isA<BridgeSseSessionCreated>());
      expect(events[1], isA<BridgeSseSessionStatus>());
      expect(harness.plugin.getActiveSessionsSummary().single.activeSessions.single.mainAgentRunning, isTrue);
      await subscription.cancel();
    });

    test("exposes one coherent project catalog and validates selections and commands", () async {
      expect((await harness.plugin.getAgents(projectId: harness.project.path)).single.name, "pi");
      expect((await harness.plugin.getProviders(projectId: harness.project.path)).providers.single.id, "provider");
      expect((await harness.plugin.getCommands(projectId: harness.project.path)).single.name, "review");
      final options = await harness.plugin.getSessionOptions(
        projectId: harness.project.path,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );
      expect(options, isA<PluginSessionOptionsDiscoveryObserved>());

      await expectLater(
        harness.plugin.createSession(
          directory: harness.project.path,
          parentSessionId: null,
          parts: const [],
          userVisibleText: null,
          variant: null,
          agent: "other",
          model: null,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 400)),
      );
      expect(harness.processes.map((entry) => entry.spec.launch), everyElement(isA<PiNoSession>()));
    });

    test("starts an empty session through command acceptance and rejects missing paths", () async {
      final session = await harness.plugin.createSession(
        directory: harness.project.path,
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );

      final accepted = harness.plugin.sendCommand(
        sessionId: session.id,
        command: "review",
        arguments: "src",
        userVisibleArguments: "src",
        variant: null,
        agent: "pi",
        model: null,
      );
      final process = await harness.nextSessionProcess();
      final prompt = await waitForCommand(process: process, type: "prompt");
      process.emitResponse(id: prompt["id"]! as String, command: "prompt");
      final state = await waitForCommand(process: process, type: "get_state");
      process.emitResponse(
        id: state["id"]! as String,
        command: "get_state",
        data: const {"isStreaming": false, "pendingMessageCount": 0},
      );
      await accepted;

      await expectLater(
        harness.plugin.sendPrompt(
          sessionId: "missing",
          parts: const [PluginPromptPart.text(text: "no")],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "not found", isTrue)),
      );
      expect(
        harness.processes.where((entry) => entry.spec.launch is! PiNoSession),
        hasLength(1),
      );
    });

    test("wrapped command failures retain the backend stack", () async {
      final session = await harness.plugin.createSession(
        directory: harness.project.path,
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final command = harness.plugin.sendCommand(
        sessionId: session.id,
        command: "review",
        arguments: "src",
        userVisibleArguments: "src",
        variant: null,
        agent: "pi",
        model: null,
      );
      final process = await harness.nextSessionProcess();
      final prompt = await waitForCommand(process: process, type: "prompt");
      process.emitFailure(id: prompt["id"]! as String, command: "prompt", error: "failed");

      try {
        await command;
        fail("command should fail");
      } on PluginOperationException catch (error, stackTrace) {
        expect(error.cause, isA<PiRpcCommandFailureException>());
        expect(stackTrace.toString(), contains("pi_rpc_client.dart"));
      }
    });

    test("maps questions and toasts while permissions remain unsupported", () async {
      final session = await harness.plugin.createSession(
        directory: harness.project.path,
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "hello")],
        userVisibleText: "hello",
        variant: null,
        agent: "pi",
        model: null,
      );
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      final process = await harness.nextSessionProcess();
      await waitForCommand(process: process, type: "prompt");
      process.emit(
        frame: {
          "type": "extension_ui_request",
          "id": "input",
          "method": "input",
          "title": "Value",
        },
      );
      process.emit(
        frame: {
          "type": "extension_ui_request",
          "id": "notify",
          "method": "notify",
          "message": "done",
          "notifyType": "warning",
        },
      );
      for (
        var attempt = 0;
        attempt < 50 &&
            (events.whereType<BridgeSseQuestionAsked>().isEmpty || events.whereType<BridgeSseTuiToastShow>().isEmpty);
        attempt++
      ) {
        await pump();
      }

      expect(events.whereType<BridgeSseQuestionAsked>().single.sessionID, session.id);
      expect(events.whereType<BridgeSseTuiToastShow>().single.variant, "warning");
      expect(await harness.plugin.getPendingPermissions(sessionId: session.id), isEmpty);
      await expectLater(
        harness.plugin.replyToPermission(
          requestId: "missing",
          sessionId: session.id,
          reply: PluginPermissionReply.once,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "not found", isTrue)),
      );
      await subscription.cancel();
    });

    test("deleting a root fences descendant dialogs but removes only the root file", () async {
      harness.writeSession(id: "root", parentPath: null);
      final rootPath = harness.sessionPath("root");
      harness.writeSession(id: "child", parentPath: rootPath);
      await harness.plugin.listAllSessions(knownDirectories: {harness.project.path});
      await harness.plugin.sendPrompt(
        sessionId: "child",
        parts: const [PluginPromptPart.text(text: "child work")],
        variant: null,
        agent: null,
        model: null,
      );
      final childProcess = await harness.nextSessionProcess();
      await waitForCommand(process: childProcess, type: "prompt");
      childProcess.emit(
        frame: {
          "type": "extension_ui_request",
          "id": "input",
          "method": "input",
        },
      );
      await pump();

      await harness.plugin.deleteSession("root");

      expect(File(rootPath).existsSync(), isFalse);
      expect(File(harness.sessionPath("child")).existsSync(), isTrue);
      expect(await harness.plugin.getPendingQuestions(sessionId: "root"), isEmpty);
      expect(await harness.plugin.getPendingQuestions(sessionId: "child"), isEmpty);
    });

    test("failed physical deletion does not emit a session-deleted event", () async {
      if (Platform.isWindows) return;
      harness.writeSession(id: "root", parentPath: null);
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      addTearDown(subscription.cancel);
      Process.runSync("chmod", ["500", harness.sessions.path]);
      try {
        await expectLater(
          harness.plugin.deleteSession("root"),
          throwsA(isA<PluginOperationException>()),
        );
      } finally {
        Process.runSync("chmod", ["700", harness.sessions.path]);
      }

      expect(events.whereType<BridgeSseSessionDeleted>(), isEmpty);
      expect(File(harness.sessionPath("root")).existsSync(), isTrue);
    });

    test("persisted cleanup uses nullable directory hints and is idempotent", () async {
      harness.writeSession(id: "persisted", parentPath: null);

      await harness.plugin.deletePersistedSession(backendSessionId: "persisted", directory: null);
      await harness.plugin.deletePersistedSession(backendSessionId: "persisted", directory: harness.project.path);

      expect(File(harness.sessionPath("persisted")).existsSync(), isFalse);
    });

    test("health is bounded and disposal rejects dialogs before closing events", () async {
      expect(await harness.plugin.healthCheck(), isTrue);
      expect(harness.commands.calls.single, ("pi", const ["--version"]));
      await harness.plugin.createSession(
        directory: harness.project.path,
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "dispose")],
        userVisibleText: "dispose",
        variant: null,
        agent: null,
        model: null,
      );
      final events = <BridgeSseEvent>[];
      var closed = false;
      harness.plugin.events.listen(events.add, onDone: () => closed = true);
      final process = await harness.nextSessionProcess();
      await waitForCommand(process: process, type: "prompt");
      process.emit(
        frame: {
          "type": "extension_ui_request",
          "id": "dispose-input",
          "method": "input",
        },
      );
      for (var attempt = 0; attempt < 50 && events.whereType<BridgeSseQuestionAsked>().isEmpty; attempt++) {
        await pump();
      }

      await harness.plugin.dispose();
      await harness.plugin.dispose();

      expect(events.whereType<BridgeSseQuestionRejected>(), hasLength(1));
      expect(closed, isTrue);
      expect(await harness.plugin.healthCheck(), isFalse);
    });

    test("shutdown bounds stalled process teardown by its caller budget", () async {
      final bounded = _Harness(stdinCloseCompletes: false);
      addTearDown(bounded.dispose);
      await bounded.plugin.createSession(
        directory: bounded.project.path,
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "bounded")],
        userVisibleText: "bounded",
        variant: null,
        agent: null,
        model: null,
      );
      final process = await bounded.nextSessionProcess();
      final stopwatch = Stopwatch()..start();

      await bounded.plugin.shutdown(shutdownBudget: const Duration(milliseconds: 30));

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(process.killed, isTrue);
    });

    test("API disposal cannot lock in a longer lifecycle shutdown budget", () async {
      final bounded = _Harness(stdinCloseCompletes: false);
      addTearDown(bounded.dispose);
      await bounded.plugin.createSession(
        directory: bounded.project.path,
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "bounded")],
        userVisibleText: "bounded",
        variant: null,
        agent: null,
        model: null,
      );
      final process = await bounded.nextSessionProcess();
      final stopwatch = Stopwatch()..start();

      await bounded.plugin.dispose();
      await bounded.plugin.shutdown(shutdownBudget: const Duration(milliseconds: 30));

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(process.killed, isTrue);
    });
  });
}

final class _Harness({bool stdinCloseCompletes = true}) {
  this {
    root = Directory.systemTemp.createTempSync("pi-plugin-");
    project = Directory("${root.path}/project")..createSync();
    sessions = Directory("${root.path}/sessions")..createSync();
    final environment = {"PI_CODING_AGENT_SESSION_DIR": sessions.path};
    plugin = PiPlugin(
      binaryPath: "pi",
      storageEnvironment: environment,
      processEnvironment: const {},
      processFactory: ({required spec}) async {
        final process = FakePiProcess(stdinCloseCompletes: stdinCloseCompletes);
        processes.add((spec: spec, process: process));
        unawaited(_answerProcess(process: process, spec: spec));
        return process;
      },
      commandExecutor: commands,
      clock: const _Clock(),
      launchDirectory: project.path,
      startupExitTimeout: const Duration(milliseconds: 100),
      historyRpcTimeout: const Duration(seconds: 2),
      catalogTimeout: const Duration(seconds: 2),
      healthTimeout: const Duration(seconds: 1),
      idleTimeout: const Duration(minutes: 5),
      editorTimeout: const Duration(minutes: 1),
      maxCatalogModels: 10,
    );
  }

  late final Directory root;
  late final Directory project;
  late final Directory sessions;
  late final PiPlugin plugin;
  final List<({PiLaunchSpec spec, FakePiProcess process})> processes = [];
  final _CommandExecutor commands = _CommandExecutor();

  Future<FakePiProcess> nextSessionProcess() async {
    for (var attempt = 0; attempt < 100; attempt++) {
      final sessions = processes.where((entry) => entry.spec.launch is! PiNoSession);
      if (sessions.isNotEmpty) return sessions.last.process;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    throw StateError("Pi session process was not started");
  }

  String sessionPath(String id) => "${sessions.path}/$id.jsonl";

  void writeSession({required String id, required String? parentPath}) {
    File(sessionPath(id)).writeAsStringSync(
      "${jsonEncode({
        "type": "session",
        "version": 3,
        "id": id,
        "timestamp": "2026-08-15T12:00:00Z",
        "cwd": project.path,
        "parentSession": parentPath,
      })}\n",
    );
  }

  Future<void> dispose() async {
    await plugin.dispose();
    for (final entry in processes) {
      await entry.process.close();
    }
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

Future<void> _answerProcess({required FakePiProcess process, required PiLaunchSpec spec}) async {
  final answered = <String>{};
  while (!process.killed && !process.stdinClosed) {
    for (final command in process.written.toList()) {
      final id = command["id"] as String?;
      if (id == null || !answered.add(id)) continue;
      final type = command["type"]! as String;
      switch (type) {
        case "get_entries":
          process.emitResponse(
            id: id,
            command: type,
            data: const {"entries": <Object?>[], "leafId": null},
          );
        case "get_state" when spec.launch is PiNoSession:
          process.emitResponse(
            id: id,
            command: type,
            data: const {
              "model": {"provider": "provider", "id": "model", "name": "Model", "reasoning": true},
            },
          );
        case "get_available_models":
          process.emitResponse(
            id: id,
            command: type,
            data: const {
              "models": [
                {"provider": "provider", "id": "model", "name": "Model", "reasoning": true},
              ],
            },
          );
        case "set_model":
          process.emitResponse(id: id, command: type);
        case "get_available_thinking_levels":
          process.emitResponse(
            id: id,
            command: type,
            data: const {
              "levels": ["high"],
            },
          );
        case "get_commands":
          process.emitResponse(
            id: id,
            command: type,
            data: const {
              "commands": [
                {"name": "review", "source": "extension"},
              ],
            },
          );
      }
    }
    await pump();
  }
}

final class _CommandExecutor() implements CommandExecutor {
  final List<(String, List<String>)> calls = [];

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    calls.add((executable, arguments));
    return const CommandResult(exitCode: 0, stdout: "pi 0.84.1", stderr: "");
  }
}

final class const _Clock() extends ServerClock {
  @override
  DateTime now() => DateTime.utc(2026, 8, 15, 12);

  @override
  Future<void> delay({required Duration duration}) => Completer<void>().future;
}
