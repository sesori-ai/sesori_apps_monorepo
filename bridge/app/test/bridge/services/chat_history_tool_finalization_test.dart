import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("open tool part finalization", () {
    test("rewrites stored pending and running tool parts to error", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t1", messageId: "m1", status: ToolStatus.running),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t2", messageId: "m1", status: ToolStatus.pending),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t3", messageId: "m1", status: ToolStatus.completed, output: "done"),
      );

      final finalized = await history.service.finalizeOpenToolParts(sessionId: "ses_a");

      expect(finalized, hasLength(2));
      final stored = await _storedParts(history: history, sessionId: "ses_a");
      expect(stored["t1"]!.state!.status, ToolStatus.error);
      expect(stored["t1"]!.state!.error, "The turn ended before this tool reported a result.");
      expect(stored["t2"]!.state!.status, ToolStatus.error);
      expect(stored["t3"]!.state!.status, ToolStatus.completed);
      expect(stored["t3"]!.state!.output, "done", reason: "terminal parts stay untouched");
    });

    test("keeps title and output of a finalized part", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t1", messageId: "m1", status: ToolStatus.running, title: "Edit", output: "partial"),
      );

      await history.service.finalizeOpenToolParts(sessionId: "ses_a");

      final stored = await _storedParts(history: history, sessionId: "ses_a");
      expect(stored["t1"]!.state!.title, "Edit");
      expect(stored["t1"]!.state!.output, "partial");
    });

    test("returns both delivery shapes for each finalized part", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t1", messageId: "m1", status: ToolStatus.running),
      );

      final finalized = await history.service.finalizeOpenToolParts(sessionId: "ses_a");

      final shapes = finalized.single;
      expect(shapes.inlinePart.state!.status, ToolStatus.error);
      expect(shapes.storedReferencePart.state!.status, ToolStatus.error);
      expect(shapes.inlinePart.id, "t1");
    });

    test("ignores non-tool parts and sessions with nothing open", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _textPart(id: "p1", messageId: "m1", text: "running"),
      );

      expect(await history.service.finalizeOpenToolParts(sessionId: "ses_a"), isEmpty);
      final stored = await _storedParts(history: history, sessionId: "ses_a");
      expect(stored["p1"]!.text, "running");
    });

    test("does not advance the session's freshness marks", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t1", messageId: "m1", status: ToolStatus.running),
      );
      final before = await history.repository.getSyncState(sessionId: "ses_a");

      await history.service.finalizeOpenToolParts(sessionId: "ses_a");

      final after = await history.repository.getSyncState(sessionId: "ses_a");
      expect(after!.watermark, before!.watermark);
      expect(after.backendActivityAt, before.backendActivityAt);
      expect(after.syncedAt, before.syncedAt);
    });

    test("a backfill read finalizes imported open tool parts when the session is not busy", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          MessageWithParts(
            info: _message(id: "m1"),
            parts: [_toolPart(id: "t1", messageId: "m1", status: ToolStatus.pending)],
          ),
        ],
        status: const SessionStatus.idle(),
      );
      final history = createTestChatHistory(sessionRepository: repository);

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(served.single.parts.single.state!.status, ToolStatus.error);
    });

    test("a backfill read leaves open tool parts alone while the session is busy", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          MessageWithParts(
            info: _message(id: "m1"),
            parts: [_toolPart(id: "t1", messageId: "m1", status: ToolStatus.running)],
          ),
        ],
        status: const SessionStatus.busy(),
      );
      final history = createTestChatHistory(sessionRepository: repository);

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(served.single.parts.single.state!.status, ToolStatus.running);
    });

    test("a fresh store still finalizes open tool parts left by an abrupt death", () async {
      // Live captures keep the store fresh, so no backfill runs. A bridge that
      // died mid-turn never saw an idle event; the stranded part must still be
      // finalized when the transcript is served from the store.
      final repository = _FakeSessionRepository(transcript: const [], status: const SessionStatus.idle());
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.backfillSession(sessionId: "ses_a");
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t1", messageId: "m1", status: ToolStatus.running),
      );

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(served.single.parts.single.state!.status, ToolStatus.error);
    });

    test("a fresh store with a busy session keeps its running tool", () async {
      final repository = _FakeSessionRepository(transcript: const [], status: const SessionStatus.busy());
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.backfillSession(sessionId: "ses_a");
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t1", messageId: "m1", status: ToolStatus.running),
      );

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(served.single.parts.single.state!.status, ToolStatus.running);
    });

    test("a fresh store without open tool parts is served without a status read", () async {
      final repository = _FakeSessionRepository(transcript: const [], status: null);
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.backfillSession(sessionId: "ses_a");
      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "m1"));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _toolPart(id: "t1", messageId: "m1", status: ToolStatus.completed, output: "done"),
      );

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(served.single.parts.single.state!.status, ToolStatus.completed);
      expect(repository.statusReads, isZero, reason: "a page with no open tool needs no status query");
    });

    test("an unobservable session status sweeps: a stopped backend hosts no live tool", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          MessageWithParts(
            info: _message(id: "m1"),
            parts: [_toolPart(id: "t1", messageId: "m1", status: ToolStatus.running)],
          ),
        ],
        status: null,
      );
      final history = createTestChatHistory(sessionRepository: repository);

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(served.single.parts.single.state!.status, ToolStatus.error);
    });
  });
}

Future<Map<String, MessagePart>> _storedParts({
  required TestChatHistory history,
  required String sessionId,
}) async {
  final page = await history.repository.getSessionMessages(
    sessionId: sessionId,
    storageScope: testAttachmentStorageScope(sessionId: sessionId),
  );
  return {
    for (final message in page.messages)
      for (final part in message.parts) part.id: part,
  };
}

Message _message({required String id}) => Message.user(
  id: id,
  sessionID: "ses_a",
  agent: null,
  promptId: null,
  time: const MessageTime(created: 1, completed: null),
);

MessagePart _toolPart({
  required String id,
  required String messageId,
  required ToolStatus status,
  String? title,
  String? output,
}) => MessagePart(
  id: id,
  sessionID: "ses_a",
  messageID: messageId,
  type: MessagePartType.tool,
  text: null,
  tool: "Edit",
  state: ToolState(status: status, title: title, output: output, error: null),
  prompt: null,
  description: null,
  agent: null,
  childSessionID: null,
  agentName: null,
  attempt: null,
  retryError: null,
  attachment: null,
);

MessagePart _textPart({required String id, required String messageId, required String text}) => MessagePart(
  id: id,
  sessionID: "ses_a",
  messageID: messageId,
  type: MessagePartType.text,
  text: text,
  tool: null,
  state: null,
  prompt: null,
  description: null,
  agent: null,
  childSessionID: null,
  agentName: null,
  attempt: null,
  retryError: null,
  attachment: null,
);

class _FakeSessionRepository({
  required final List<MessageWithParts> transcript,
  required final SessionStatus? status,
}) implements SessionRepository {
  int statusReads = 0;

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async => transcript;

  @override
  Future<SessionStatus?> getSessionStatus({required String sessionId}) async {
    statusReads++;
    return status;
  }

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => StoredSession(
    id: sessionId,
    backendSessionId: sessionId,
    pluginId: "opencode",
    projectId: "project-1",
    parentSessionId: null,
    directory: "/tmp/project-1",
    worktreePath: null,
    branchName: null,
    isDedicated: false,
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
