import "dart:async";
import "dart:convert";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:pi_plugin/src/api/models/pi_session_history_dto.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/mappers/pi_persisted_user_text_codec.dart";
import "package:pi_plugin/src/repositories/pi_session_process_repository.dart";
import "package:pi_plugin/src/services/pi_event_dispatcher.dart";
import "package:pi_plugin/src/services/pi_extension_ui_service.dart";
import "package:pi_plugin/src/services/pi_session_service.dart";
import "package:pi_plugin/src/trackers/pi_extension_ui_tracker.dart";
import "package:pi_plugin/src/trackers/pi_message_identity_tracker.dart";
import "package:pi_plugin/src/trackers/pi_tool_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/pi_rpc_client_test_factory.dart";

void main() {
  test("new session preparation generates a valid secure id and persists its marker", () async {
    final storage = _Storage(initialResolved: null);
    final fixture = _Fixture(processes: const [], storageOverride: storage);
    addTearDown(fixture.dispose);
    final service = fixture.service();

    final sessionId = await service.prepareNewSession(directory: "/project");
    final secondSessionId = await service.prepareNewSession(directory: "/project");

    expect(PiNewSession(sessionId: sessionId).sessionId, sessionId);
    expect(sessionId, matches(RegExp(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")));
    expect(secondSessionId, isNot(sessionId));
    expect(storage.pending?.id, secondSessionId);
    expect(storage.pending?.cwd, "/project");
  });

  test("prepared sessions retain their marker directory until deletion", () async {
    final storage = _Storage(initialResolved: null);
    final fixture = _Fixture(processes: const [], storageOverride: storage);
    addTearDown(fixture.dispose);
    final service = fixture.service();
    final sessionId = await service.prepareNewSession(directory: "/project");

    await service.forgetSession(sessionId: sessionId);

    expect(storage.pending, isNull);
    expect(storage.clearedDirectories, contains("/project"));
  });

  test("connect hydrates before exposing startup frames and shares one spawn", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final frames = <PiSessionProcessFrame>[];
    fixture.repository.frames.listen(frames.add);

    final first = fixture.repository.ensureResident(sessionId: "session", knownDirectories: const {"/project"});
    final second = fixture.repository.ensureResident(sessionId: "session", knownDirectories: const {"/project"});
    process.emit(frame: {"type": "agent_start"});
    await pump();
    expect(frames, isEmpty);

    await _answerEntries(process);
    expect((await first).generation, (await second).generation);
    await pump();
    expect(frames.where((frame) => frame.frame is PiEventFrame), hasLength(1));
    expect(fixture.spawned, hasLength(1));
  });

  test("persisted file wins over pending marker and marker resumes new when file is absent", () async {
    final resumed = FakePiProcess();
    final created = FakePiProcess();
    final storage = _Storage(
      initialResolved: _resolved(),
      initialPending: const PiPendingNewSession(id: "session", cwd: "/pending"),
    );
    final fixture = _Fixture(processes: [resumed, created], storageOverride: storage);
    addTearDown(fixture.dispose);

    final resident = fixture.repository.ensureResident(sessionId: "session", knownDirectories: const {"/project"});
    await _answerEntries(resumed);
    await resident;
    expect(fixture.spawned.single.launch, isA<PiResumedSession>());
    await fixture.repository.teardown(sessionId: "session");

    storage
      ..resolved = null
      ..pending = const PiPendingNewSession(id: "session", cwd: "/pending");
    final pending = fixture.repository.ensureResident(sessionId: "session", knownDirectories: const {"/pending"});
    await _answerEntries(created);
    await pending;
    expect(fixture.spawned.last.launch, isA<PiNewSession>());
  });

  test("teardown fences and reaps a process whose spawn completes late", () async {
    final process = FakePiProcess();
    final spawn = Completer<PiProcessHandle>();
    final storage = _Storage(initialResolved: _resolved());
    final identities = PiMessageIdentityTracker(pluginId: "pi");
    final repository = PiSessionProcessRepository(
      storageApi: storage,
      historyStorageApi: _HistoryStorage(storageApi: storage),
      binaryPath: "/runtime/pi",
      environment: const {},
      processFactory: ({required spec}) => spawn.future,
      historyMapper: PiHistoryMapper(pluginId: "pi"),
      identityTracker: identities,
      startupExitTimeout: const Duration(milliseconds: 50),
      historyRpcTimeout: const Duration(seconds: 2),
    );
    addTearDown(repository.dispose);

    final connecting = repository.ensureResident(sessionId: "session", knownDirectories: const {"/project"});
    await pump();
    await repository.teardown(sessionId: "session");
    spawn.complete(process);

    await expectLater(connecting, throwsStateError);
    expect(process.killed, isTrue);
    expect(repository.residentSessionIds, isEmpty);
  });

  test("resident history and rename reuse process while transient rename disposes its lease", () async {
    final resident = FakePiProcess();
    final transient = FakePiProcess();
    final fixture = _Fixture(processes: [resident, transient]);
    addTearDown(fixture.dispose);

    final connecting = fixture.repository.ensureResident(sessionId: "session", knownDirectories: const {"/project"});
    final history = fixture.repository.loadHistory(sessionId: "session", knownDirectories: const {"/project"});
    final rename = fixture.repository.renameSession(
      sessionId: "session",
      title: "Resident",
      knownDirectories: const {"/project"},
    );
    await pump();
    expect(fixture.spawned, hasLength(1));
    await _answerEntries(resident);
    await connecting;
    await _answerNthEntries(resident, count: 2);
    final residentRename = await waitForCommand(process: resident, type: "set_session_name");
    resident.emitResponse(id: residentRename["id"]! as String, command: "set_session_name");
    await history;
    await rename;
    expect(fixture.spawned, hasLength(1));

    await fixture.repository.teardown(sessionId: "session");
    final transientRename = fixture.repository.renameSession(
      sessionId: "session",
      title: "Transient",
      knownDirectories: const {"/project"},
    );
    final transientCommand = await waitForCommand(process: transient, type: "set_session_name");
    transient.emitResponse(id: transientCommand["id"]! as String, command: "set_session_name");
    await transientRename;
    expect(transient.killed, isTrue);
  });

  for (final operation in ["history", "rename"]) {
    test("$operation starting before residency never overlaps another process", () async {
      final transient = FakePiProcess();
      final resident = FakePiProcess();
      final gate = Completer<void>();
      final storage = _Storage(initialResolved: _resolved(), resolveGate: gate);
      final fixture = _Fixture(processes: [transient, resident], storageOverride: storage);
      addTearDown(fixture.dispose);

      final Future<void> firstOperation;
      if (operation == "history") {
        firstOperation = fixture.repository
            .loadHistory(sessionId: "session", knownDirectories: const {"/project"})
            .then<void>((_) {});
      } else {
        firstOperation = fixture.repository.renameSession(
          sessionId: "session",
          title: "Transient",
          knownDirectories: const {"/project"},
        );
      }
      await pump();
      final connecting = fixture.repository.ensureResident(
        sessionId: "session",
        knownDirectories: const {"/project"},
      );
      gate.complete();

      if (operation == "history") {
        await _answerEntries(transient);
      } else {
        final rename = await waitForCommand(process: transient, type: "set_session_name");
        transient.emitResponse(id: rename["id"]! as String, command: "set_session_name");
      }
      await firstOperation;
      expect(transient.killed, isTrue);
      expect(fixture.spawned, hasLength(1));

      await _answerEntries(resident);
      await connecting;
      expect(fixture.spawned, hasLength(2));
    });
  }

  test("selection completes before prompt dispatch", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();

    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "selected")],
      userVisibleText: "selected",
      variant: const PluginSessionVariant(id: "high"),
      model: (providerID: "provider", modelID: "model"),
    );
    await _answerEntries(process);
    final model = await waitForCommand(process: process, type: "set_model");
    expect(process.written.where((frame) => frame["type"] == "prompt"), isEmpty);
    process.emitResponse(id: model["id"]! as String, command: "set_model");
    final thinking = await waitForCommand(process: process, type: "set_thinking_level");
    expect(process.written.where((frame) => frame["type"] == "prompt"), isEmpty);
    process.emitResponse(id: thinking["id"]! as String, command: "set_thinking_level");
    final prompt = await waitForCommand(process: process, type: "prompt");
    expect(prompt["message"], "selected");
  });

  test("selection failure prevents prompt dispatch and settles the lane", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();
    final events = <BridgeSseEvent>[];
    service.events.listen(events.add);

    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "selected")],
      userVisibleText: "selected",
      variant: null,
      model: (providerID: "provider", modelID: "model"),
    );
    await _answerEntries(process);
    final model = await waitForCommand(process: process, type: "set_model");
    process.emitFailure(id: model["id"]! as String, command: "set_model", error: "unavailable");
    await _waitForIdle(service: service, sessionId: "session");

    expect(process.written.where((frame) => frame["type"] == "prompt"), isEmpty);
    expect(events.whereType<BridgeSseSessionError>(), hasLength(1));
  });

  test("prompt emits busy before live frames and idle status before idle event", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();
    final events = <BridgeSseEvent>[];
    service.events.listen(events.add);

    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "ordered")],
      userVisibleText: "ordered",
      variant: null,
      model: null,
    );
    await _answerEntries(process);
    final prompt = await waitForCommand(process: process, type: "prompt");
    process.emitResponse(id: prompt["id"]! as String, command: "prompt");
    process.emit(frame: {"type": "agent_start"});
    process.emit(frame: {"type": "agent_settled"});
    await _waitForEvent<BridgeSseSessionIdle>(events: events);

    final statuses = events.whereType<BridgeSseSessionStatus>().toList();
    final idleIndex = events.indexWhere((event) => event is BridgeSseSessionIdle);
    expect(statuses.first.status["type"], "busy");
    expect(statuses.last.status["type"], "idle");
    expect(events.indexOf(statuses.last), lessThan(idleIndex));
  });

  test("agent settlement waits for the correlated prompt response", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();

    final accepted = service.sendCommand(
      sessionId: "session",
      directory: "/project",
      command: "name",
      arguments: "first",
      userVisibleArguments: "first",
      variant: null,
      model: null,
    );
    var completed = false;
    unawaited(accepted.then((_) => completed = true));
    await _answerEntries(process);
    final firstPrompt = await waitForCommand(process: process, type: "prompt");
    process.emit(frame: {"type": "agent_start"});
    process.emit(frame: {"type": "agent_settled"});
    await pump();
    expect(completed, isFalse);
    process.emitResponse(id: firstPrompt["id"]! as String, command: "prompt");
    await accepted;
    await _waitForIdle(service: service, sessionId: "session");

    final failed = service.sendCommand(
      sessionId: "session",
      directory: "/project",
      command: "name",
      arguments: "second",
      userVisibleArguments: "second",
      variant: null,
      model: null,
    );
    final secondPrompt = await _waitForNthCommand(process: process, type: "prompt", count: 2);
    process.emit(frame: {"type": "agent_start"});
    process.emit(frame: {"type": "agent_settled"});
    process.emitFailure(id: secondPrompt["id"]! as String, command: "prompt", error: "rejected");

    await expectLater(failed, throwsA(isA<PiRpcCommandFailureException>()));
    await _waitForIdle(service: service, sessionId: "session");
  });

  test("prompt admission is immediate, same-session FIFO, and sessions run concurrently", () async {
    final first = FakePiProcess();
    final other = FakePiProcess();
    final fixture = _Fixture(processes: [first, other]);
    addTearDown(fixture.dispose);
    final service = fixture.service();

    await service.sendPrompt(
      sessionId: "one",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "first")],
      userVisibleText: "first",
      variant: null,
      model: null,
    );
    await service.sendPrompt(
      sessionId: "one",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "second")],
      userVisibleText: "second",
      variant: null,
      model: null,
    );
    await service.sendPrompt(
      sessionId: "two",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "other")],
      userVisibleText: "other",
      variant: null,
      model: null,
    );

    await Future.wait([_answerEntries(first), _answerEntries(other)]);
    final firstPrompt = await waitForCommand(process: first, type: "prompt");
    final otherPrompt = await waitForCommand(process: other, type: "prompt");
    expect(firstPrompt["message"], "first");
    expect(otherPrompt["message"], "other");
    expect(first.written.where((frame) => frame["type"] == "prompt"), hasLength(1));

    first.emitResponse(id: firstPrompt["id"]! as String, command: "prompt");
    first.emit(frame: {"type": "agent_settled"});
    final secondPrompt = await _waitForNthCommand(process: first, type: "prompt", count: 2);
    expect(secondPrompt["message"], "second");
  });

  test("command rejects busy, accepts dialog-first, and uses no-run state barrier", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();

    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "busy")],
      userVisibleText: "busy",
      variant: null,
      model: null,
    );
    await expectLater(
      service.sendCommand(
        sessionId: "session",
        directory: "/project",
        command: "name",
        arguments: "x",
        userVisibleArguments: "x",
        variant: null,
        model: null,
      ),
      throwsA(isA<PiSessionBusyException>()),
    );
    await _answerEntries(process);
    final busyPrompt = await waitForCommand(process: process, type: "prompt");
    process.emitResponse(id: busyPrompt["id"]! as String, command: "prompt");
    process.emit(frame: {"type": "agent_start"});
    process.emit(frame: {"type": "agent_settled"});
    await pump();

    final accepted = service.sendCommand(
      sessionId: "session",
      directory: "/project",
      command: "name",
      arguments: "private visible",
      userVisibleArguments: "visible",
      variant: null,
      model: null,
    );
    final commandPrompt = await _waitForNthCommand(process: process, type: "prompt", count: 2);
    var commandAccepted = false;
    unawaited(accepted.then((_) => commandAccepted = true));
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "notify",
        "method": "notify",
        "message": "still running",
      },
    );
    await pump();
    expect(commandAccepted, isFalse);
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "dialog",
        "method": "input",
        "title": "Input",
      },
    );
    await accepted;
    process.emitResponse(id: commandPrompt["id"]! as String, command: "prompt");
    final idle = service.events.firstWhere((event) => event is BridgeSseSessionIdle);
    final state = await waitForCommand(process: process, type: "get_state");
    process.emitResponse(
      id: state["id"]! as String,
      command: "get_state",
      data: {"isStreaming": false, "pendingMessageCount": 0},
    );
    await idle;
    await _waitForIdle(service: service, sessionId: "session");
    expect(service.sessionStatuses["session"], const PluginSessionStatus.idle());
  });

  test("startup no-model failure emits privacy-safe login guidance", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();
    final events = <BridgeSseEvent>[];
    service.events.listen(events.add);

    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "prompt")],
      userVisibleText: "prompt",
      variant: null,
      model: null,
    );
    await waitForCommand(process: process, type: "get_entries");
    process.emitStderrRaw(
      bytes: utf8.encode("${PiRpcClient.noModelsDiagnosticPrefix} /private/model/path\n"),
    );
    process.exit(code: 78);
    await _waitForEvent<BridgeSseTuiToastShow>(events: events);

    final toast = events.whereType<BridgeSseTuiToastShow>().single;
    expect(toast.message, contains("/login"));
    expect(toast.message, isNot(contains("/private")));
    expect(events.whereType<BridgeSseSessionError>(), hasLength(1));
  });

  test("command exit before response or dialog fails acceptance", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();

    final accepted = service.sendCommand(
      sessionId: "session",
      directory: "/project",
      command: "name",
      arguments: "value",
      userVisibleArguments: "value",
      variant: null,
      model: null,
    );
    await _answerEntries(process);
    await waitForCommand(process: process, type: "prompt");
    process.exit(code: 9);

    await expectLater(accepted, throwsA(isA<PiRpcProcessExitException>()));
    await _waitForIdle(service: service, sessionId: "session");
  });

  test("post-acceptance process exit fails the active turn", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();
    final events = <BridgeSseEvent>[];
    service.events.listen(events.add);

    final accepted = service.sendCommand(
      sessionId: "session",
      directory: "/project",
      command: "name",
      arguments: "value",
      userVisibleArguments: "value",
      variant: null,
      model: null,
    );
    await _answerEntries(process);
    await waitForCommand(process: process, type: "prompt");
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "dialog",
        "method": "input",
        "title": "Input",
      },
    );
    await accepted;
    process.exit(code: 9);

    await _waitForIdle(service: service, sessionId: "session");
    expect(events.whereType<BridgeSseSessionError>(), hasLength(1));
  });

  test("failed prompt response and process exit settle queued work", () async {
    final failed = FakePiProcess();
    final replacement = FakePiProcess();
    final fixture = _Fixture(processes: [failed, replacement]);
    addTearDown(fixture.dispose);
    final service = fixture.service();
    final events = <BridgeSseEvent>[];
    service.events.listen(events.add);

    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "first")],
      userVisibleText: "first",
      variant: null,
      model: null,
    );
    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "second")],
      userVisibleText: "second",
      variant: null,
      model: null,
    );
    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "third")],
      userVisibleText: "third",
      variant: null,
      model: null,
    );
    await _answerEntries(failed);
    final prompt = await waitForCommand(process: failed, type: "prompt");
    failed.emitFailure(id: prompt["id"]! as String, command: "prompt", error: "private failure");
    final second = await _waitForNthCommand(process: failed, type: "prompt", count: 2);
    failed.emitStderrRaw(bytes: utf8.encode("${PiRpcClient.noModelsDiagnosticPrefix}\n"));
    failed.exit(code: 9);
    await _answerEntries(replacement);
    final queued = await waitForCommand(process: replacement, type: "prompt");
    replacement.emitFailure(id: queued["id"]! as String, command: "prompt", error: "failed");
    await _waitForEvent<BridgeSseTuiToastShow>(events: events);
    await _waitForEventCount<BridgeSseSessionError>(events: events, count: 3);

    expect(second["message"], "second");
    expect(queued["message"], "third");
    expect(events.whereType<BridgeSseSessionError>(), hasLength(3));
    expect(
      events.whereType<BridgeSseTuiToastShow>(),
      contains(isA<BridgeSseTuiToastShow>().having((event) => event.message, "message", contains("/login"))),
    );
    expect(service.sessionStatuses["session"], const PluginSessionStatus.idle());
  });

  test("abort invalidates queue, sends abort, and tears down process", () async {
    final process = FakePiProcess();
    final fixture = _Fixture(processes: [process]);
    addTearDown(fixture.dispose);
    final service = fixture.service();

    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "first")],
      userVisibleText: "first",
      variant: null,
      model: null,
    );
    await service.sendPrompt(
      sessionId: "session",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "queued")],
      userVisibleText: "queued",
      variant: null,
      model: null,
    );
    await _answerEntries(process);
    final prompt = await waitForCommand(process: process, type: "prompt");
    process.emitResponse(id: prompt["id"]! as String, command: "prompt");
    process.emit(frame: {"type": "agent_start"});
    final abort = service.abort(sessionId: "session");
    final abortCommand = await waitForCommand(process: process, type: "abort");
    process.emitResponse(id: abortCommand["id"]! as String, command: "abort");
    await abort;

    expect(process.killed, isTrue);
    expect(process.written.where((frame) => frame["type"] == "prompt"), hasLength(1));
    expect(fixture.repository.residentSessionIds, isEmpty);
  });

  test("idle reap and disposal terminate residents", () async {
    final first = FakePiProcess();
    final second = FakePiProcess();
    final fixture = _Fixture(processes: [first, second]);
    final clock = _ManualClock();
    final service = fixture.service(clock: clock);

    await service.sendPrompt(
      sessionId: "one",
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "one")],
      userVisibleText: "one",
      variant: null,
      model: null,
    );
    await _answerEntries(first);
    final prompt = await waitForCommand(process: first, type: "prompt");
    first.emitResponse(id: prompt["id"]! as String, command: "prompt");
    first.emit(frame: {"type": "agent_settled"});
    await pump();
    clock.elapse();
    await pump();
    expect(first.killed, isTrue);

    final resident = fixture.repository.ensureResident(sessionId: "two", knownDirectories: const {"/project"});
    await _answerEntries(second);
    await resident;
    await service.dispose();
    expect(second.killed, isTrue);
  });

  test("idle reap preserves pending marker location for later deletion", () async {
    final process = FakePiProcess();
    final storage = _Storage(initialResolved: null);
    final fixture = _Fixture(processes: [process], storageOverride: storage);
    final clock = _ManualClock();
    final service = fixture.service(clock: clock);
    final sessionId = await service.prepareNewSession(directory: "/project");
    await service.sendPrompt(
      sessionId: sessionId,
      directory: "/project",
      parts: [const PluginPromptPart.text(text: "prompt")],
      userVisibleText: "prompt",
      variant: null,
      model: null,
    );
    await _answerEntries(process);
    final prompt = await waitForCommand(process: process, type: "prompt");
    process.emitResponse(id: prompt["id"]! as String, command: "prompt");
    process.emit(frame: {"type": "agent_settled"});
    await _waitForIdle(service: service, sessionId: sessionId);
    clock.elapse();
    await pump();

    await service.forgetSession(sessionId: sessionId);

    expect(storage.pending, isNull);
    expect(storage.clearedDirectories, contains("/project"));
    await fixture.dispose();
  });

  test("prompt mapper validates inline images and rejects every unsupported attachment", () {
    final fixture = _Fixture(processes: const []);
    addTearDown(fixture.dispose);

    final payload = fixture.repository.mapPrompt(
      parts: [
        const PluginPromptPart.text(text: "image"),
        PluginPromptPart.fileData(mime: "image/png", base64: base64Encode([1, 2, 3]), filename: "a.png"),
      ],
      userVisibleText: "image",
    );
    expect(payload.images.single["data"], "AQID");
    final context = fixture.repository.mapPrompt(
      parts: const [
        PluginPromptPart.text(text: "private context\n"),
        PluginPromptPart.text(text: "visible"),
      ],
      userVisibleText: "visible",
    );
    expect(context.message, startsWith(PiPersistedUserTextCodec.marker));
    for (final attachment in <PluginPromptPart>[
      const PluginPromptPart.filePath(mime: "image/png", path: "/private/a.png", filename: null),
      const PluginPromptPart.fileUrl(mime: "image/png", url: "https://private.invalid/a.png", filename: null),
      const PluginPromptPart.fileData(mime: "text/plain", base64: "YQ==", filename: null),
      const PluginPromptPart.fileData(mime: "image/png", base64: "not-base64", filename: null),
    ]) {
      expect(
        () => fixture.repository.mapPrompt(parts: [attachment], userVisibleText: null),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.statusCode, "status", 400)
              .having((error) => error.toString(), "privacy", isNot(contains("private.invalid"))),
        ),
      );
    }
  });
}

Future<void> _answerEntries(FakePiProcess process) => _answerNthEntries(process, count: 1);

Future<void> _answerNthEntries(FakePiProcess process, {required int count}) async {
  final command = await _waitForNthCommand(process: process, type: "get_entries", count: count);
  process.emitResponse(
    id: command["id"]! as String,
    command: "get_entries",
    data: const {"entries": <Object?>[], "leafId": null},
  );
}

Future<void> _waitForEventCount<T>({required List<BridgeSseEvent> events, required int count}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (events.whereType<T>().length >= count) return;
    await pump();
  }
  throw StateError("event $T count=$count did not arrive");
}

Future<void> _waitForEvent<T>({required List<BridgeSseEvent> events}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (events.whereType<T>().isNotEmpty) return;
    await pump();
  }
  throw StateError("event $T did not arrive");
}

Future<void> _waitForIdle({required PiSessionService service, required String sessionId}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (service.sessionStatuses[sessionId] == const PluginSessionStatus.idle()) return;
    await pump();
  }
  throw StateError("session did not become idle");
}

Future<Map<String, Object?>> _waitForNthCommand({
  required FakePiProcess process,
  required String type,
  required int count,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final matches = process.written.where((frame) => frame["type"] == type).toList();
    if (matches.length >= count) return matches[count - 1];
    await pump();
  }
  throw StateError("no command type=$type count=$count");
}

PiResolvedSession _resolved({String id = "session"}) => PiResolvedSession(
  metadata: PiSessionMetadata(
    id: id,
    cwd: "/project",
    parentId: null,
    title: null,
    createdAt: null,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  ),
  path: "/sessions/$id.jsonl",
);

final class _Fixture({required List<FakePiProcess> processes, final _Storage? storageOverride}) {
  final List<FakePiProcess> _processes = List.of(processes);
  late final _Storage storage = storageOverride ?? _Storage(initialResolved: _resolved());
  final List<PiLaunchSpec> spawned = [];
  late final PiMessageIdentityTracker identities = PiMessageIdentityTracker(pluginId: "pi");
  late final PiHistoryMapper historyMapper = PiHistoryMapper(pluginId: "pi");
  final List<PiSessionService> _services = [];
  late final PiSessionProcessRepository repository = PiSessionProcessRepository(
    storageApi: storage,
    historyStorageApi: _HistoryStorage(storageApi: storage),
    binaryPath: "/runtime/pi",
    environment: const {},
    processFactory: ({required spec}) async {
      spawned.add(spec);
      return _processes.removeAt(0);
    },
    historyMapper: historyMapper,
    identityTracker: identities,
    startupExitTimeout: const Duration(milliseconds: 50),
    historyRpcTimeout: const Duration(seconds: 2),
  );

  PiSessionService service({ServerClock clock = const ServerClock()}) {
    late final PiExtensionUiService extension;
    extension = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(storageApi: storage),
      processRepository: repository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: const Duration(minutes: 1),
    );
    final service = PiSessionService(
      processRepository: repository,
      eventDispatcher: PiEventDispatcher(
        historyMapper: historyMapper,
        identityTracker: identities,
        toolTracker: PiToolTracker(),
      ),
      extensionUiService: extension,
      clock: clock,
      idleTimeout: const Duration(minutes: 5),
    );
    _services.add(service);
    return service;
  }

  Future<void> dispose() async {
    for (final service in _services) {
      await service.dispose();
    }
    await repository.dispose();
    for (final process in _processes) {
      await process.close();
    }
  }
}

final class _Storage({
  required final PiResolvedSession? initialResolved,
  final PiPendingNewSession? initialPending,
  final Completer<void>? resolveGate,
}) implements PiSessionStorageApi {
  PiResolvedSession? resolved = initialResolved;
  PiPendingNewSession? pending = initialPending;
  Set<String>? clearedDirectories;
  @override
  Future<PiResolvedSession?> resolveSession({required String sessionId, required Set<String> knownDirectories}) async {
    await resolveGate?.future;
    return resolved == null || resolved?.metadata.id == sessionId ? resolved : _resolved(id: sessionId);
  }

  @override
  Future<PiPendingNewSession?> readPendingNewSession({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async => pending;

  @override
  Future<void> clearPendingNewSession({required String sessionId, required Set<String> knownDirectories}) async {
    clearedDirectories = Set.of(knownDirectories);
    pending = null;
  }

  @override
  Future<void> writePendingNewSession({required String sessionId, required String cwd}) async {
    pending = PiPendingNewSession(id: sessionId, cwd: cwd);
  }

  @override
  Future<List<PiSessionMetadata>> listSessionMetadata({required Set<String> knownDirectories}) async => [
    if (resolved case PiResolvedSession(:final metadata)) metadata,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _HistoryStorage({required super.storageApi}) extends PiSessionHistoryStorageApi {
  @override
  Future<PiSessionFileHistoryDto> readSessionHistory({required String path}) =>
      Future.error(StateError("file fallback not expected"));
}

final class _ManualClock() implements ServerClock {
  Completer<void>? _delay;

  @override
  Future<void> delay({required Duration duration}) => (_delay = Completer<void>()).future;

  void elapse() => _delay?.complete();

  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
