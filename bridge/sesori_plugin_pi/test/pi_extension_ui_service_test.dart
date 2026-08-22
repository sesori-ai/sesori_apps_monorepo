import "dart:async";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:pi_plugin/src/api/models/pi_session_history_dto.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/pi_session_process_repository.dart";
import "package:pi_plugin/src/services/pi_extension_ui_service.dart";
import "package:pi_plugin/src/trackers/pi_extension_ui_tracker.dart";
import "package:pi_plugin/src/trackers/pi_message_identity_tracker.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/fake_pi_session_storage_api.dart";

void main() {
  late List<PiExtensionUiEvent> events;
  late PiExtensionUiService service;
  late _ProcessFixture processes;
  late String projectId;

  setUp(() async {
    events = [];
    projectId = normalizeProjectDirectory(directory: "/repo/worktree");
    final storage = FakePiExtensionSessionStorageApi(
      initialSessions: [
        _metadata(id: "root", cwd: "/repo", updated: 3),
        _metadata(id: "child", cwd: "/repo/worktree", updated: 2, parentId: "root"),
      ],
    );
    processes = _ProcessFixture(storage: storage);
    await processes.start(sessionId: "child", directory: "/repo/worktree");
    service = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(storageApi: storage),
      processRepository: processes.repository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: const Duration(milliseconds: 20),
    );
    service.events.listen(events.add);
  });

  tearDown(() async {
    await service.dispose();
    await processes.dispose();
  });

  test("maps dialogs, indexes imported scope, and sends exact reply variants", () async {
    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiSelectDialogRequest(
        id: "select-wire",
        title: "Choose",
        options: ["one", "two"],
        timeoutMs: null,
        raw: {},
      ),
    );
    final select = service.getPendingQuestions(sessionId: "root").single;
    expect(select.sessionID, "child");
    expect(select.displaySessionId, "root");
    expect(select.questions.single.options.map((option) => option.label), ["one", "two"]);
    expect(service.getProjectQuestions(projectId: projectId).single.id, select.id);

    service.replyToQuestion(
      questionId: select.id,
      sessionId: "root",
      answers: const [
        ["two"],
      ],
    );
    expect(processes.replies.single.requestId, "select-wire");
    expect((processes.replies.single.reply as PiExtensionUiValueReply).value, "two");
    expect(events.whereType<PiExtensionUiQuestionReplied>().single.requestId, select.id);

    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiConfirmDialogRequest(
        id: "confirm-wire",
        title: null,
        message: "Proceed?",
        timeoutMs: null,
        raw: {},
      ),
    );
    final confirm = service.getPendingQuestions(sessionId: "child").single;
    service.replyToQuestion(
      questionId: confirm.id,
      sessionId: "child",
      answers: const [
        ["No"],
      ],
    );
    expect((processes.replies.last.reply as PiExtensionUiConfirmationReply).confirmed, isFalse);

    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiInputDialogRequest(
        id: "input-wire",
        title: null,
        placeholder: "Value",
        timeoutMs: null,
        raw: {},
      ),
    );
    final input = service.getPendingQuestions(sessionId: "child").single;
    service.replyToQuestion(
      questionId: input.id,
      sessionId: "child",
      answers: const [
        ["line 1\nline 2"],
      ],
    );
    expect((processes.replies.last.reply as PiExtensionUiValueReply).value, "line 1\nline 2");
  });

  test("editor exposes bounded prefill and sends complete replacement", () async {
    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: PiEditorDialogRequest(
        id: "editor-wire",
        title: "Edit",
        prefill: _repeat("x", 600),
        raw: const {},
      ),
    );
    final editor = service.getPendingQuestions(sessionId: "child").single;
    final prompt = editor.questions.single.question;
    expect(prompt, contains("complete replacement"));
    expect(prompt, contains("Prefill was truncated"));
    expect(prompt, isNot(contains(_repeat("x", 501))));

    service.replyToQuestion(
      questionId: editor.id,
      sessionId: "child",
      answers: const [
        ["replacement\n"],
      ],
    );

    expect((processes.replies.single.reply as PiExtensionUiValueReply).value, "replacement\n");
  });

  test("invalid and late replies do not consume pending state", () async {
    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiSelectDialogRequest(
        id: "select-wire",
        title: null,
        options: ["one"],
        timeoutMs: null,
        raw: {},
      ),
    );
    final question = service.getPendingQuestions(sessionId: "child").single;

    expect(
      () => service.replyToQuestion(
        questionId: question.id,
        sessionId: "other",
        answers: const [
          ["one"],
        ],
      ),
      throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 404)),
    );
    expect(
      () => service.replyToQuestion(
        questionId: question.id,
        sessionId: "child",
        answers: const [
          ["other"],
        ],
      ),
      throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 400)),
    );
    expect(service.getPendingQuestions(sessionId: "child"), hasLength(1));

    service.rejectQuestion(questionId: question.id, sessionId: "child");
    expect(processes.replies.single.reply, isA<PiExtensionUiCancelledReply>());
    expect(
      () => service.rejectQuestion(questionId: question.id, sessionId: "child"),
      throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 404)),
    );
  });

  test("mirrors upstream timeout, owns editor expiry, and bounds notifications", () async {
    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiInputDialogRequest(
        id: "upstream-timeout",
        title: null,
        placeholder: null,
        timeoutMs: 5,
        raw: {},
      ),
    );
    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiEditorDialogRequest(id: "editor-timeout", title: null, prefill: null, raw: {}),
    );
    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: PiNotifyRequest(
        id: "notify",
        message: _repeat("n", 600),
        notifyType: PiNotificationType.warning,
        raw: const {},
      ),
    );
    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiSetStatusRequest(id: "status", statusKey: "key", statusText: "secret", raw: {}),
    );

    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(service.getPendingQuestions(sessionId: "child"), isEmpty);
    expect(processes.replies.map((reply) => reply.requestId), ["editor-timeout"]);
    expect(processes.replies.single.reply, isA<PiExtensionUiCancelledReply>());
    expect(events.whereType<PiExtensionUiQuestionRejected>(), hasLength(2));
    final toast = events.whereType<PiExtensionUiToast>().single;
    expect(toast.message.runes.length, PiExtensionUiService.maxTextLength);
    expect(toast.variant, PiNotificationType.warning);
  });

  test("unknown owners are cancelled and owner cleanup rejects every card", () async {
    await service.handleRequest(
      ownerSessionId: "missing",
      processGeneration: processes.generation,
      request: const PiInputDialogRequest(id: "missing", title: null, placeholder: null, timeoutMs: null, raw: {}),
    );
    expect(processes.replies, isEmpty);
    expect(service.getPendingQuestions(sessionId: "missing"), isEmpty);

    for (final id in ["one", "two"]) {
      await service.handleRequest(
        ownerSessionId: "child",
        processGeneration: processes.generation,
        request: PiInputDialogRequest(id: id, title: null, placeholder: null, timeoutMs: null, raw: const {}),
      );
    }
    service.cancelForOwner(sessionId: "child", processGeneration: null);

    expect(service.getPendingQuestions(sessionId: "root"), isEmpty);
    expect(processes.replies.map((reply) => reply.requestId), ["one", "two"]);
    expect(events.whereType<PiExtensionUiQuestionRejected>(), hasLength(2));
  });

  test("owner cleanup fences a dialog still resolving its catalog scope", () async {
    final gate = Completer<void>();
    final delayed = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(
        storageApi: FakePiExtensionSessionStorageApi(
          initialSessions: [_metadata(id: "child", cwd: "/repo", updated: 1)],
          listGate: gate,
        ),
      ),
      processRepository: processes.repository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: const Duration(minutes: 30),
    );
    final handling = delayed.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiInputDialogRequest(id: "late", title: null, placeholder: null, timeoutMs: null, raw: {}),
    );
    await Future<void>.delayed(Duration.zero);

    delayed.cancelForOwner(sessionId: "child", processGeneration: null);
    gate.complete();
    await handling;

    expect(delayed.getPendingQuestions(sessionId: "child"), isEmpty);
    expect(processes.replies.single.requestId, "late");
    expect(processes.replies.single.reply, isA<PiExtensionUiCancelledReply>());
    await delayed.dispose();
  });

  test("delayed old lookup cannot cancel through replacement process generation", () async {
    final gate = Completer<void>();
    final delayed = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(
        storageApi: FakePiExtensionSessionStorageApi(
          initialSessions: [_metadata(id: "child", cwd: "/repo", updated: 1)],
          listGate: gate,
        ),
      ),
      processRepository: processes.repository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: const Duration(minutes: 30),
    );
    final oldGeneration = processes.generation;
    final handling = delayed.handleRequest(
      ownerSessionId: "child",
      processGeneration: oldGeneration,
      request: const PiInputDialogRequest(id: "old-dialog", title: null, placeholder: null, timeoutMs: null, raw: {}),
    );
    await Future<void>.delayed(Duration.zero);

    await processes.reconnect();
    delayed.cancelForOwner(sessionId: "child", processGeneration: oldGeneration);
    gate.complete();
    await handling;

    expect(processes.processes.first.written.where((frame) => frame["type"] == "extension_ui_response"), isEmpty);
    expect(processes.processes.last.written.where((frame) => frame["type"] == "extension_ui_response"), isEmpty);
    expect(delayed.getPendingQuestions(sessionId: "child"), isEmpty);
    await delayed.dispose();
  });

  test("older process exit cannot lower the cancelled generation fence", () async {
    final oldGeneration = processes.generation;
    await processes.reconnect();
    final currentGeneration = processes.generation;
    service.cancelForOwner(sessionId: "child", processGeneration: currentGeneration);
    service.cancelForOwner(sessionId: "child", processGeneration: oldGeneration);

    await service.handleRequest(
      ownerSessionId: "child",
      processGeneration: currentGeneration,
      request: const PiInputDialogRequest(
        id: "cancelled-current-dialog",
        title: null,
        placeholder: null,
        timeoutMs: null,
        raw: {},
      ),
    );

    expect(service.getPendingQuestions(sessionId: "child"), isEmpty);
    expect(processes.replies.single.requestId, "cancelled-current-dialog");
    expect(processes.replies.single.reply, isA<PiExtensionUiCancelledReply>());
  });

  test("catalog failures cancel the unresolved Pi dialog", () async {
    final failing = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(
        storageApi: FakePiExtensionSessionStorageApi(
          initialSessions: const [],
          listError: StateError("catalog unavailable"),
        ),
      ),
      processRepository: processes.repository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: const Duration(minutes: 30),
    );

    await expectLater(
      failing.handleRequest(
        ownerSessionId: "child",
        processGeneration: processes.generation,
        request: const PiInputDialogRequest(
          id: "catalog-failure",
          title: null,
          placeholder: null,
          timeoutMs: null,
          raw: {},
        ),
      ),
      throwsStateError,
    );

    expect(processes.replies.single.requestId, "catalog-failure");
    expect(processes.replies.single.reply, isA<PiExtensionUiCancelledReply>());
    await failing.dispose();
  });

  test("catalog lookup time counts against the upstream dialog timeout", () async {
    final gate = Completer<void>();
    final delayed = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(
        storageApi: FakePiExtensionSessionStorageApi(
          initialSessions: [_metadata(id: "child", cwd: "/repo", updated: 1)],
          listGate: gate,
        ),
      ),
      processRepository: processes.repository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: const Duration(minutes: 30),
    );
    final handling = delayed.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiInputDialogRequest(
        id: "elapsed-timeout",
        title: null,
        placeholder: null,
        timeoutMs: 5,
        raw: {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    await handling;

    expect(delayed.getPendingQuestions(sessionId: "child"), isEmpty);
    expect(processes.replies, isEmpty);
    await delayed.dispose();
  });

  test("failed response writes retire pending questions", () async {
    await processes.repository.teardown(sessionId: "child");
    final unavailable = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(
        storageApi: FakePiExtensionSessionStorageApi(
          initialSessions: [_metadata(id: "child", cwd: "/repo", updated: 1)],
        ),
      ),
      processRepository: processes.repository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: const Duration(minutes: 30),
    );
    final unavailableEvents = <PiExtensionUiEvent>[];
    unavailable.events.listen(unavailableEvents.add);
    await unavailable.handleRequest(
      ownerSessionId: "child",
      processGeneration: processes.generation,
      request: const PiInputDialogRequest(
        id: "unavailable",
        title: null,
        placeholder: null,
        timeoutMs: null,
        raw: {},
      ),
    );
    final question = unavailable.getPendingQuestions(sessionId: "child").single;

    expect(
      () => unavailable.replyToQuestion(
        questionId: question.id,
        sessionId: "child",
        answers: const [
          ["answer"],
        ],
      ),
      throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 404)),
    );
    expect(unavailable.getPendingQuestions(sessionId: "child"), isEmpty);
    expect(unavailableEvents.whereType<PiExtensionUiQuestionRejected>(), hasLength(1));
    await unavailable.dispose();
  });
}

final class const _SentReply({
  required final String ownerSessionId,
  required final String requestId,
  required final PiExtensionUiReply reply,
});

final class _ProcessFixture({required final FakePiExtensionSessionStorageApi storage}) {
  final List<FakePiProcess> processes = [FakePiProcess()];
  late int generation;
  late final PiSessionProcessRepository repository = PiSessionProcessRepository(
    storageApi: storage,
    historyStorageApi: _FakeHistoryStorage(storageApi: storage),
    binaryPath: "/runtime/pi",
    environment: const {},
    processFactory: ({required spec}) async => processes.last,
    historyMapper: PiHistoryMapper(pluginId: "pi"),
    identityTracker: PiMessageIdentityTracker(pluginId: "pi"),
    startupExitTimeout: const Duration(milliseconds: 50),
    historyRpcTimeout: const Duration(seconds: 2),
  );

  List<_SentReply> get replies => [
    for (final process in processes)
      for (final frame in process.written)
        if (frame["type"] == "extension_ui_response")
          _SentReply(
            ownerSessionId: "child",
            requestId: frame["id"]! as String,
            reply: switch (frame) {
              {"value": final String value} => PiExtensionUiValueReply(value: value),
              {"confirmed": final bool confirmed} => PiExtensionUiConfirmationReply(confirmed: confirmed),
              _ => const PiExtensionUiCancelledReply(),
            },
          ),
  ];

  Future<void> start({required String sessionId, required String directory}) async {
    final process = processes.last;
    final connecting = repository.ensureResident(sessionId: sessionId, knownDirectories: {directory});
    final command = await _waitForCommand(process: process, type: "get_entries");
    process.emitResponse(
      id: command["id"]! as String,
      command: "get_entries",
      data: const {"entries": <Object?>[], "leafId": null},
    );
    generation = (await connecting).generation;
  }

  Future<void> reconnect() async {
    await repository.teardown(sessionId: "child");
    processes.add(FakePiProcess());
    await start(sessionId: "child", directory: "/repo/worktree");
  }

  Future<Map<String, Object?>> _waitForCommand({
    required FakePiProcess process,
    required String type,
  }) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      for (final frame in process.written) {
        if (frame["type"] == type) return frame;
      }
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError("missing $type command");
  }

  Future<void> dispose() => repository.dispose();
}

final class _FakeHistoryStorage({required super.storageApi}) extends PiSessionHistoryStorageApi {
  @override
  Future<PiSessionFileHistoryDto> readSessionHistory({required String path}) =>
      Future.error(StateError("file fallback not expected"));
}

PiSessionMetadata _metadata({required String id, required String cwd, required int updated, String? parentId}) =>
    PiSessionMetadata(
      id: id,
      cwd: cwd,
      parentId: parentId,
      title: null,
      createdAt: null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true),
    );

String _repeat(String value, int count) => List.filled(count, value).join();
