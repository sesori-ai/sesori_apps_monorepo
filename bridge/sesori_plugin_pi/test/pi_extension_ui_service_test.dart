import "dart:async";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/src/services/pi_extension_ui_service.dart";
import "package:pi_plugin/src/trackers/pi_extension_ui_tracker.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late List<PiExtensionUiEvent> events;
  late List<_SentReply> replies;
  late PiExtensionUiService service;
  late String projectId;

  setUp(() {
    events = [];
    replies = [];
    projectId = normalizeProjectDirectory(directory: "/repo/worktree");
    service = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(
        storageApi: _FakeStorageApi(
          sessions: [
            _metadata(id: "root", cwd: "/repo", updated: 3),
            _metadata(id: "child", cwd: "/repo/worktree", updated: 2, parentId: "root"),
          ],
        ),
      ),
      tracker: PiExtensionUiTracker(),
      responseSender: ({required ownerSessionId, required requestId, required reply}) {
        replies.add(_SentReply(ownerSessionId: ownerSessionId, requestId: requestId, reply: reply));
        return true;
      },
      editorTimeout: const Duration(milliseconds: 20),
    );
    service.events.listen(events.add);
  });

  tearDown(() => service.dispose());

  test("maps dialogs, indexes imported scope, and sends exact reply variants", () async {
    await service.handleRequest(
      ownerSessionId: "child",
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
      sessionId: "child",
      answers: const [
        ["two"],
      ],
    );
    expect(replies.single.requestId, "select-wire");
    expect((replies.single.reply as PiExtensionUiValueReply).value, "two");
    expect(events.whereType<PiExtensionUiQuestionReplied>().single.requestId, select.id);

    await service.handleRequest(
      ownerSessionId: "child",
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
    expect((replies.last.reply as PiExtensionUiConfirmationReply).confirmed, isFalse);

    await service.handleRequest(
      ownerSessionId: "child",
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
    expect((replies.last.reply as PiExtensionUiValueReply).value, "line 1\nline 2");
  });

  test("editor exposes bounded prefill and sends complete replacement", () async {
    await service.handleRequest(
      ownerSessionId: "child",
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

    expect((replies.single.reply as PiExtensionUiValueReply).value, "replacement\n");
  });

  test("invalid and late replies do not consume pending state", () async {
    await service.handleRequest(
      ownerSessionId: "child",
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
        sessionId: "root",
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
    expect(replies.single.reply, isA<PiExtensionUiCancelledReply>());
    expect(
      () => service.rejectQuestion(questionId: question.id, sessionId: "child"),
      throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 404)),
    );
  });

  test("mirrors upstream timeout, owns editor expiry, and bounds notifications", () async {
    await service.handleRequest(
      ownerSessionId: "child",
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
      request: const PiEditorDialogRequest(id: "editor-timeout", title: null, prefill: null, raw: {}),
    );
    await service.handleRequest(
      ownerSessionId: "child",
      request: PiNotifyRequest(
        id: "notify",
        message: _repeat("n", 600),
        notifyType: PiNotificationType.warning,
        raw: const {},
      ),
    );
    await service.handleRequest(
      ownerSessionId: "child",
      request: const PiSetStatusRequest(id: "status", statusKey: "key", statusText: "secret", raw: {}),
    );

    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(service.getPendingQuestions(sessionId: "child"), isEmpty);
    expect(replies.map((reply) => reply.requestId), ["editor-timeout"]);
    expect(replies.single.reply, isA<PiExtensionUiCancelledReply>());
    expect(events.whereType<PiExtensionUiQuestionRejected>(), hasLength(2));
    final toast = events.whereType<PiExtensionUiToast>().single;
    expect(toast.message.runes.length, PiExtensionUiService.maxTextLength);
    expect(toast.variant, PiNotificationType.warning);
  });

  test("unknown owners are cancelled and owner cleanup rejects every card", () async {
    await service.handleRequest(
      ownerSessionId: "missing",
      request: const PiInputDialogRequest(id: "missing", title: null, placeholder: null, timeoutMs: null, raw: {}),
    );
    expect(replies.single.requestId, "missing");
    expect(service.getPendingQuestions(sessionId: "missing"), isEmpty);

    for (final id in ["one", "two"]) {
      await service.handleRequest(
        ownerSessionId: "child",
        request: PiInputDialogRequest(id: id, title: null, placeholder: null, timeoutMs: null, raw: const {}),
      );
    }
    service.cancelForOwner(sessionId: "child");

    expect(service.getPendingQuestions(sessionId: "root"), isEmpty);
    expect(replies.skip(1).map((reply) => reply.requestId), ["one", "two"]);
    expect(events.whereType<PiExtensionUiQuestionRejected>(), hasLength(2));
  });

  test("owner cleanup fences a dialog still resolving its catalog scope", () async {
    final gate = Completer<void>();
    final delayed = PiExtensionUiService(
      catalogRepository: PiSessionCatalogRepository(
        storageApi: _FakeStorageApi(
          sessions: [_metadata(id: "child", cwd: "/repo", updated: 1)],
          gate: gate,
        ),
      ),
      tracker: PiExtensionUiTracker(),
      responseSender: ({required ownerSessionId, required requestId, required reply}) {
        replies.add(_SentReply(ownerSessionId: ownerSessionId, requestId: requestId, reply: reply));
        return true;
      },
      editorTimeout: const Duration(minutes: 30),
    );
    final handling = delayed.handleRequest(
      ownerSessionId: "child",
      request: const PiInputDialogRequest(id: "late", title: null, placeholder: null, timeoutMs: null, raw: {}),
    );
    await Future<void>.delayed(Duration.zero);

    delayed.cancelForOwner(sessionId: "child");
    gate.complete();
    await handling;

    expect(delayed.getPendingQuestions(sessionId: "child"), isEmpty);
    expect(replies.single.requestId, "late");
    expect(replies.single.reply, isA<PiExtensionUiCancelledReply>());
    await delayed.dispose();
  });
}

final class const _SentReply({
  required final String ownerSessionId,
  required final String requestId,
  required final PiExtensionUiReply reply,
});

PiSessionMetadata _metadata({required String id, required String cwd, required int updated, String? parentId}) =>
    PiSessionMetadata(
      id: id,
      cwd: cwd,
      parentId: parentId,
      title: null,
      createdAt: null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true),
    );

final class _FakeStorageApi({required final List<PiSessionMetadata> sessions, final Completer<void>? gate})
    implements PiSessionStorageApi {
  @override
  Future<List<PiSessionMetadata>> listSessionMetadata({required Set<String> knownDirectories}) async {
    await gate?.future;
    return sessions;
  }

  @override
  Future<String?> resolveEffectiveSessionDirectory({required String directory}) async => null;

  @override
  Future<PiResolvedSession?> resolveSession({required String sessionId, required Set<String> knownDirectories}) async =>
      null;

  @override
  Future<String?> resolveSessionPath({required String sessionId, required Set<String> knownDirectories}) async => null;
}

String _repeat(String value, int count) => List.filled(count, value).join();
