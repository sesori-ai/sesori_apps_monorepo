import "dart:async";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

const _testIds = [
  "99999999-8888-4777-8666-555555555555",
  "11111111-2222-4333-8444-555555555555",
  "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
];

void main() {
  group("ClaudePlugin", () {
    late _PluginHarness harness;

    setUp(() {
      harness = _PluginHarness();
    });

    tearDown(() => harness.close());

    test("discovers and caches a complete global catalog outside the selected project", () async {
      final options = await harness.plugin.getSessionOptions(
        projectId: "/tmp/project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );

      final observed = options as PluginSessionOptionsDiscoveryObserved;
      expect(observed.options.agents.map((agent) => agent.name), ["Default", "Plan"]);
      expect(observed.options.providers.providers.single.models, hasLength(2));
      expect(observed.options.commands.single.name, "review");
      expect(harness.processes, hasLength(1));
      expect(harness.specs.single.workingDirectory, harness.temporary.path);
      expect(_controlSubtypes(harness.processes.single), ["initialize"]);
      expect(harness.processes.single.killed, isTrue);
      expect(await harness.plugin.listAllSessions(knownDirectories: const {}), isEmpty);

      // A cached read is served without spawning a second probe.
      await harness.plugin.getCommands(projectId: null);
      expect(harness.processes, hasLength(1));

      await harness.plugin.getSessionOptions(
        projectId: "/tmp/other-project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      );
      expect(harness.processes, hasLength(2));
      expect(harness.specs.map((spec) => spec.workingDirectory), everyElement(harness.temporary.path));
      expect(_controlSubtypes(harness.processes.last), contains("list_models"));
    });

    test("shares one catalog probe across concurrent reads", () async {
      final results = await Future.wait([
        harness.plugin.getAgents(projectId: "/tmp/project"),
        harness.plugin.getProviders(projectId: "/tmp/other-project"),
        harness.plugin.getCommands(projectId: null),
      ]);

      expect(results, hasLength(3));
      expect(harness.processes, hasLength(1));
    });

    test("shares one cached catalog across project ids", () async {
      final first = await harness.plugin.getSessionOptions(
        projectId: "/tmp/project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );
      final second = await harness.plugin.getSessionOptions(
        projectId: "/tmp/other-project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );

      expect(second, first);
      expect(harness.processes, hasLength(1));
      expect(harness.specs.single.workingDirectory, harness.temporary.path);
    });

    test("creates under the generated id and buffers creation before listening", () async {
      final session = await harness.createSession();
      expect(session.id, testSessionId);
      expect(session.directory, "/tmp/project");

      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      await pump();
      expect(events.first, isA<BridgeSseSessionCreated>());
      expect(events.whereType<BridgeSseSessionStatus>().single.sessionID, testSessionId);

      final process = harness.processes.single;
      final user = await waitForFrame(process, "user");
      expect(user["session_id"], testSessionId);
      expect((user["message"]! as Map)["content"], [
        {"type": "text", "text": "hello"},
      ]);

      final statuses = await harness.plugin.getSessionStatuses();
      expect(statuses[testSessionId], isA<PluginSessionStatusBusy>());
      final summary = harness.plugin.getActiveSessionsSummary().single;
      expect(summary.id, "/tmp/project");
      expect(summary.activeSessions.single.id, testSessionId);
      expect(summary.activeSessions.single.mainAgentRunning, isTrue);
      await subscription.cancel();
    });

    test("shows only the user-authored text from a replayed execution context", () async {
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);

      await harness.plugin.createSession(
        directory: "/tmp/project",
        parentSessionId: null,
        parts: const [
          PluginPromptPart.text(text: _worktreeContext),
          PluginPromptPart.text(text: "visible prompt"),
        ],
        userVisibleText: "visible prompt",
        variant: null,
        agent: "Default",
        model: (providerID: "anthropic", modelID: "default"),
      );
      final process = harness.processes.single;
      final written = await waitForFrame(process, "user");
      final executionText = _userTexts(process).join("\n");
      expect(executionText, contains("private-branch"));
      process.emit(_replayOf(written, uuid: "replay-user-1"));
      await pump();

      final visibleParts = events.whereType<BridgeSseMessagePartUpdated>().where(
        (event) => event.part.type == PluginMessagePartType.text,
      );
      expect(visibleParts.single.part.text, "visible prompt");
      expect(visibleParts.single.part.messageID, "replay-user-1");
      final user = events.whereType<BridgeSseMessageUpdated>().where(
        (event) => event.info["role"] == "user",
      );
      expect(user.single.info["id"], "replay-user-1");
      await subscription.cancel();
    });

    test("fails closed when init violates the pre-bound session identity", () async {
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      await harness.createSession();
      final process = harness.processes.single;
      await waitForFrame(process, "user");

      process.emit(sampleInit(sessionId: otherTestSessionId));
      for (var attempt = 0; attempt < 50 && !process.killed; attempt++) {
        await pump();
      }

      expect(process.killed, isTrue);
      expect(events.whereType<BridgeSseSessionError>().single.sessionID, testSessionId);
      expect(await harness.plugin.getSessionStatuses(), isEmpty);
      await subscription.cancel();
    });

    test("dispatches a slash command as an accepted queued turn", () async {
      await harness.createSession();
      final first = harness.processes.single;
      await waitForFrame(first, "user");
      first.emit(_result());
      await pump();
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);

      await harness.plugin.sendCommand(
        promptId: "prompt-1",
        sessionId: testSessionId,
        command: "review",
        arguments: "${_worktreeContext.trimRight()}\n\nsrc",
        userVisibleArguments: "src",
        variant: null,
        agent: "Plan",
        model: (providerID: "anthropic", modelID: "small"),
      );
      final permission = await _waitForControl(first, "set_permission_mode");
      expect(_request(permission)["mode"], "plan");
      await _waitForUserText(first, "/review ${_worktreeContext.trimRight()}\n\nsrc");
      await pump();
      final visible = events.whereType<BridgeSseMessagePartUpdated>().where(
        (event) => event.part.text == "/review src",
      );
      expect(visible, hasLength(1));
      await subscription.cancel();
    });

    test("creates an empty session and reports command initialization failure", () async {
      await harness.close();
      harness = _PluginHarness(failInitialize: true);
      final session = await harness.plugin.createSession(
        directory: "/tmp/project",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: "Default",
        model: (providerID: "anthropic", modelID: "default"),
      );

      await expectLater(
        harness.plugin.sendCommand(
          promptId: "prompt-1",
          sessionId: session.id,
          command: "review",
          arguments: "src",
          userVisibleArguments: "src",
          variant: null,
          agent: "Default",
          model: (providerID: "anthropic", modelID: "default"),
        ),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.operation, "operation", "sendCommand")
              .having((error) => error.cause, "cause", isNotNull),
        ),
      );
    });

    test("renders a follow-up prompt from its replayed user frame", () async {
      await harness.createSession();
      final first = harness.processes.single;
      await waitForFrame(first, "user");
      first.emit(_result());
      await pump();
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);

      await harness.plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: testSessionId,
        parts: const [PluginPromptPart.text(text: "follow-up")],
        variant: null,
        agent: "Default",
        model: (providerID: "anthropic", modelID: "default"),
      );
      await _waitForUserText(first, "follow-up");
      final written = first.written.lastWhere((frame) => frame["type"] == "user");
      first.emit(_replayOf(written, uuid: "replay-user-2"));
      await pump();

      final visible = events.whereType<BridgeSseMessagePartUpdated>().where(
        (event) => event.part.text == "follow-up",
      );
      expect(visible.single.part.messageID, "replay-user-2");
      final message = events.whereType<BridgeSseMessageUpdated>().where(
        (event) => event.info["id"] == "replay-user-2" && event.info["role"] == "user",
      );
      expect(message, hasLength(1));
      await subscription.cancel();
    });

    test("respawns between turns when launch-only effort changes", () async {
      await harness.createSession();
      final first = harness.processes.single;
      await waitForFrame(first, "user");
      first.emit(_result());
      await pump();

      await harness.plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: testSessionId,
        parts: const [PluginPromptPart.text(text: "deeper")],
        variant: const PluginSessionVariant(id: "high"),
        agent: "Default",
        model: (providerID: "anthropic", modelID: "default"),
      );
      for (var attempt = 0; attempt < 50 && harness.processes.length < 2; attempt++) {
        await pump();
      }

      expect(harness.processes, hasLength(2));
      expect(harness.specs.last.launch, isA<ClaudeResumedSession>());
      expect(harness.specs.last.effort, ClaudeEffortLevel.high);
      await waitForFrame(harness.processes.last, "user");
    });

    test("throws not found instead of creating a process for an unknown session", () async {
      await expectLater(
        harness.plugin.sendPrompt(
          promptId: "prompt-1",
          sessionId: otherTestSessionId,
          parts: const [PluginPromptPart.text(text: "hello")],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "not found", isTrue)),
      );
      await expectLater(
        harness.plugin.getSessionMessages(otherTestSessionId),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "not found", isTrue)),
      );
      expect(harness.processes, isEmpty);
    });

    test("delete fences the turn, reaps the process, and forgets the session", () async {
      final session = await harness.createSession();
      final process = harness.processes.single;
      await waitForFrame(process, "user");

      await harness.plugin.deleteSession(session.id);

      expect(process.killed, isTrue);
      expect(await harness.plugin.getSessions("/tmp/project"), isEmpty);
      expect(await harness.plugin.getSessionStatuses(), isEmpty);
      await expectLater(
        harness.plugin.deleteSession(session.id),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "not found", isTrue)),
      );
    });

    test("finishes in-memory deletion when transcript cleanup fails", () async {
      await harness.close();
      harness = _PluginHarness(failTranscriptDelete: true);
      final session = await harness.createSession();

      await expectLater(
        harness.plugin.deleteSession(session.id),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.operation, "operation", "deleteSession")
              .having((error) => error.cause, "cause", isA<StateError>()),
        ),
      );

      expect(await harness.plugin.getSessions("/tmp/project"), isEmpty);
      expect(await harness.plugin.getSessionStatuses(), isEmpty);
    });

    test("preserves API retry status for snapshots and activity", () async {
      await harness.createSession();
      final process = harness.processes.single;
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      process.emit({
        "type": "system",
        "subtype": "api_retry",
        "session_id": testSessionId,
        "uuid": "retry-1",
        "attempt": 2,
        "max_retries": 5,
        "retry_delay_ms": 1000,
        "error_status": 429,
        "error": "rate_limit",
      });
      await pump();

      final retry = (await harness.plugin.getSessionStatuses())[testSessionId]! as PluginSessionStatusRetry;
      expect(retry.attempt, 2);
      expect(retry.next, DateTime.utc(2026, 8, 11, 12).millisecondsSinceEpoch + 1000);
      expect(events.whereType<BridgeSseSessionStatus>().last.status["next"], retry.next);
      expect(harness.plugin.getActiveSessionsSummary().single.activeSessions.single.isRetrying, isTrue);
      await subscription.cancel();
    });

    test("preserves an error result after a handled permission denial", () async {
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      await harness.createSession();
      final process = harness.processes.single;
      await waitForFrame(process, "user");
      harness.processRepository.recordAppliedSelection(
        sessionId: testSessionId,
        model: "default",
        effort: null,
        permissionMode: ClaudePermissionMode.plan,
      );
      process.emit({
        "type": "control_request",
        "request_id": "permission-1",
        "request": {
          "subtype": "can_use_tool",
          "tool_name": "Write",
          "tool_use_id": "toolu-1",
          "input": {"file_path": "a.dart"},
        },
      });
      await pump();
      await harness.plugin.replyToPermission(
        requestId: "br-1",
        sessionId: testSessionId,
        reply: PluginPermissionReply.reject,
      );

      process.emit({
        "type": "result",
        "subtype": "success",
        "session_id": testSessionId,
        "uuid": "result-error",
        "is_error": true,
        "terminal_reason": "api_error",
        "api_error_status": 500,
        "permission_denials": [
          {"tool_name": "Write", "tool_use_id": "toolu-1"},
        ],
      });
      await pump();

      final errorEvent = events.whereType<BridgeSseMessageUpdated>().last;
      final error = shared.Message.fromJson(errorEvent.info) as shared.MessageError;
      expect(error.errorName, "api_error");
      expect(error.errorMessage, "Claude Code could not complete the API request (HTTP 500).");
      expect(
        harness.approvals.consumeHandledPermissionDenials(
          sessionId: testSessionId,
          denials: const [
            {"tool_use_id": "toolu-1"},
          ],
        ),
        isFalse,
      );
      await subscription.cancel();
    });

    test("publishes Default prompt defaults after approving ExitPlanMode", () async {
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      await harness.createSession();
      final process = harness.processes.single;
      await waitForFrame(process, "user");
      process.emit({
        "type": "control_request",
        "request_id": "exit-plan-1",
        "request": {
          "subtype": "can_use_tool",
          "tool_name": "ExitPlanMode",
          "tool_use_id": "toolu-exit-plan",
          "requires_user_interaction": true,
          "input": const <String, Object?>{},
        },
      });
      await pump();

      await harness.plugin.replyToQuestion(
        questionId: "br-1",
        sessionId: testSessionId,
        answers: const [[]],
      );
      await pump();

      final defaults = events.whereType<BridgeSseSessionPromptDefaultsChanged>().single;
      expect(defaults.sessionID, testSessionId);
      expect(defaults.agent, "Default");
      expect(defaults.model, isNull);

      process.emit(_result());
      await pump();
      final permissionModeControlsBefore = _controlSubtypes(
        process,
      ).where((subtype) => subtype == "set_permission_mode").length;
      await harness.plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: testSessionId,
        parts: const [PluginPromptPart.text(text: "plan again")],
        variant: null,
        agent: "Plan",
        model: (providerID: "anthropic", modelID: "default"),
      );
      final permissionMode = await _waitForControl(process, "set_permission_mode");
      expect(_request(permissionMode)["mode"], "plan");
      expect(
        _controlSubtypes(process).where((subtype) => subtype == "set_permission_mode"),
        hasLength(permissionModeControlsBefore + 1),
      );
      await subscription.cancel();
    });

    test("suppresses the terminal result after an explicit interruption", () async {
      final events = <BridgeSseEvent>[];
      final subscription = harness.plugin.events.listen(events.add);
      await harness.createSession();
      final process = harness.processes.single;
      await waitForFrame(process, "user");

      await harness.plugin.abortSession(sessionId: testSessionId);
      process.emit({
        "type": "result",
        "subtype": "error_during_execution",
        "session_id": testSessionId,
        "uuid": "interrupted-result",
        "is_error": true,
        "terminal_reason": "other",
      });
      await pump();

      final errors = events
          .whereType<BridgeSseMessageUpdated>()
          .map((event) => shared.Message.fromJson(event.info))
          .whereType<shared.MessageError>();
      expect(errors, isEmpty);
      await subscription.cancel();
    });

    test("persisted cleanup is idempotent for an absent transcript", () async {
      await harness.plugin.deletePersistedSession(backendSessionId: testSessionId);
      await harness.plugin.deletePersistedSession(backendSessionId: testSessionId);
    });
  });
}

final class _PluginHarness({final bool failInitialize = false, bool failTranscriptDelete = false}) {
  this {
    temporary = Directory.systemTemp.createTempSync("claude-plugin-test-");
    final eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();
    processRepository = ClaudeSessionProcessRepository(
      processFactory: (spec) async {
        final process = FakeClaudeProcess();
        specs.add(spec);
        processes.add(process);
        unawaited(_answerControls(process, failInitialize: failInitialize));
        return process;
      },
      binaryPath: "claude",
      environment: const {},
    );
    approvals = ClaudeApprovalRegistry(
      emit: eventBuffer.add,
      respond: processRepository.answerControlRequest,
    );
    sessionService = ClaudeSessionService(
      processes: processRepository,
      approvals: approvals,
      clock: const _NeverIdleClock(),
      idleTimeout: const Duration(minutes: 5),
    );
    const content = ClaudeContentMapper();
    final transcripts = ClaudeTranscriptCatalogRepository(
      transcriptApi: failTranscriptDelete
          ? _ThrowingDeleteTranscriptApi()
          : ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": temporary.path}),
    );
    plugin = ClaudePlugin(
      processes: processRepository,
      transcripts: transcripts,
      sessions: sessionService,
      catalogService: ClaudeCatalogService(
        catalog: const ClaudeBackendCatalogRepository(),
        processes: processRepository,
        probeSessionId: _nextId(),
        discoveryDirectory: temporary.path,
      ),
      approvals: approvals,
      eventDispatcher: ClaudeEventDispatcher(content: content, tools: ClaudeToolTracker()),
      history: const ClaudeHistoryMapper(content: content),
      eventBuffer: eventBuffer,
      clock: const _NeverIdleClock(),
      generateSessionId: _nextId,
      launchDirectory: "/tmp/project",
    );
  }

  late final Directory temporary;
  late final ClaudeSessionProcessRepository processRepository;
  late final ClaudeApprovalRegistry approvals;
  late final ClaudeSessionService sessionService;
  late final ClaudePlugin plugin;
  final List<ClaudeLaunchSpec> specs = [];
  final List<FakeClaudeProcess> processes = [];
  var _idIndex = 0;

  String _nextId() => _testIds[_idIndex++];

  Future<PluginSession> createSession() => plugin.createSession(
    directory: "/tmp/project",
    parentSessionId: null,
    parts: const [PluginPromptPart.text(text: "hello")],
    userVisibleText: "hello",
    variant: null,
    agent: "Default",
    model: (providerID: "anthropic", modelID: "default"),
  );

  Future<void> close() async {
    await plugin.dispose();
    for (final process in processes) {
      await process.close();
    }
    temporary.deleteSync(recursive: true);
  }
}

final class const _NeverIdleClock() extends ServerClock {
  @override
  DateTime now() => DateTime.utc(2026, 8, 11, 12);

  @override
  Future<void> delay({required Duration duration}) => Completer<void>().future;
}

Future<void> _answerControls(FakeClaudeProcess process, {required bool failInitialize}) async {
  final answered = <String>{};
  while (!process.killed) {
    for (final frame in process.written) {
      if (frame["type"] != "control_request") continue;
      final requestId = frame["request_id"]! as String;
      if (!answered.add(requestId)) continue;
      final subtype = _request(frame)["subtype"];
      if (subtype == "initialize" && failInitialize) {
        process.emit({
          "type": "control_response",
          "response": {"subtype": "error", "request_id": requestId, "error": "probe failure"},
        });
        continue;
      }
      process.emitControlResponse(
        requestId: requestId,
        payload: subtype == "initialize" || subtype == "list_models" ? sampleHandshake : const {},
      );
    }
    await pump();
  }
}

Future<Map<String, Object?>> _waitForControl(FakeClaudeProcess process, String subtype) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    for (final frame in process.written) {
      if (frame["type"] == "control_request" && _request(frame)["subtype"] == subtype) return frame;
    }
    await pump();
  }
  throw StateError("no '$subtype' control request written");
}

Future<void> _waitForUserText(FakeClaudeProcess process, String text) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (_userTexts(process).contains(text)) return;
    await pump();
  }
  throw StateError("no user turn containing '$text' written");
}

Map<String, Object?> _request(Map<String, Object?> frame) => (frame["request"]! as Map).cast<String, Object?>();

Iterable<String?> _controlSubtypes(FakeClaudeProcess process) => process.written
    .where((frame) => frame["type"] == "control_request")
    .map((frame) => _request(frame)["subtype"] as String?);

List<String> _userTexts(FakeClaudeProcess process) => [
  for (final frame in process.written)
    if (frame["type"] == "user")
      for (final block in ((frame["message"]! as Map)["content"]! as List))
        if (block is Map && block["type"] == "text") block["text"]! as String,
];

Map<String, Object?> _result() => {
  "type": "result",
  "subtype": "success",
  "session_id": testSessionId,
  "is_error": false,
};

/// The CLI's `--replay-user-messages` echo of a stdin user frame [written],
/// stamped with its transcript [uuid].
Map<String, Object?> _replayOf(Map<String, Object?> written, {required String uuid}) => {
  ...written,
  "uuid": uuid,
  "isReplay": true,
  "timestamp": "2026-08-11T12:00:00.000Z",
};

final class _ThrowingDeleteTranscriptApi() extends ClaudeTranscriptApi {
  this : super(environment: const {});

  bool deleteAttempted = false;

  @override
  List<String> listTranscriptPaths() => deleteAttempted ? const [] : ["/tmp/$testSessionId.jsonl"];

  @override
  void deleteTranscript({required String transcriptPath}) {
    deleteAttempted = true;
    throw StateError("delete failed");
  }
}

const _worktreeContext = """
[SYSTEM CONTEXT \u2014 IMPORTANT]
A dedicated git worktree and branch have been created for this session:
- Branch: private-branch
- Worktree path: /private/worktree
- Based on: main

IMPORTANT: Do NOT create new worktrees.

---
""";
