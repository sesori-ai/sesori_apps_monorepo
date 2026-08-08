import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("serving session messages", () {
    test("first read backfills from the plugin and matches it exactly", () async {
      final repository = _FakeSessionRepository(
        transcript: [_messageWithParts(id: "m1"), _messageWithParts(id: "m2")],
      );
      final history = createTestChatHistory(sessionRepository: repository);

      final served = await history.service.getSessionMessages(sessionId: "ses_a");

      expect(served, equals(repository.transcript), reason: "store-served output must equal plugin-served output");
      expect(repository.fetchCount, 1);
    });

    test("a second read is served from the store without touching the plugin", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.getSessionMessages(sessionId: "ses_a");

      final served = await history.service.getSessionMessages(sessionId: "ses_a");

      expect(repository.fetchCount, 1, reason: "a synced store must not cold-start the backend");
      expect(served.map((message) => message.info.id), const ["m1"]);
    });

    test("observed backend activity forces one re-read, then settles", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.getSessionMessages(sessionId: "ses_a");
      final synced = (await history.repository.getSyncState(sessionId: "ses_a"))!;

      await history.service.observeBackendActivity(
        sessionId: "ses_a",
        activityAt: synced.watermark + 5000,
      );
      repository.transcript = [_messageWithParts(id: "m1"), _messageWithParts(id: "m2")];

      expect(
        (await history.service.getSessionMessages(sessionId: "ses_a")).map((message) => message.info.id),
        const ["m1", "m2"],
        reason: "a session advanced outside Sesori must be re-read",
      );
      expect(repository.fetchCount, 2);

      await history.service.getSessionMessages(sessionId: "ses_a");
      expect(repository.fetchCount, 2, reason: "the refreshed store is current again");
    });

    test("live capture alone keeps serving from the plugin", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);

      await history.service.captureMessage(sessionId: "ses_a", message: _message(id: "live"));
      await history.service.getSessionMessages(sessionId: "ses_a");

      expect(
        repository.fetchCount,
        1,
        reason: "a capture-created row is not a complete transcript, so the first read must still backfill",
      );
    });

    test("an empty transcript is served without re-fetching", () async {
      final repository = _FakeSessionRepository(transcript: const []);
      final history = createTestChatHistory(sessionRepository: repository);

      expect(await history.service.getSessionMessages(sessionId: "ses_a"), isEmpty);
      expect(await history.service.getSessionMessages(sessionId: "ses_a"), isEmpty);
      expect(repository.fetchCount, 1, reason: "empty is a valid synced state, not a cache miss");
    });

    test("a fetch failure propagates instead of looking like an empty thread", () async {
      final repository = _FakeSessionRepository(transcript: const [], error: StateError("backend down"));
      final history = createTestChatHistory(sessionRepository: repository);

      await expectLater(history.service.getSessionMessages(sessionId: "ses_a"), throwsStateError);
    });
  });
}

Message _message({required String id}) =>
    Message.user(id: id, sessionID: "ses_a", agent: null, time: const MessageTime(created: 1, completed: null));

MessagePart _part({required String id, required String messageId}) => MessagePart(
  id: id,
  sessionID: "ses_a",
  messageID: messageId,
  type: MessagePartType.text,
  text: "text of $messageId",
  tool: null,
  state: null,
  prompt: null,
  description: null,
  agent: null,
  agentName: null,
  attempt: null,
  retryError: null,
  attachment: null,
);

MessageWithParts _messageWithParts({required String id}) =>
    MessageWithParts(info: _message(id: id), parts: [_part(id: "$id-p1", messageId: id)]);

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({required this.transcript, this.error});

  List<MessageWithParts> transcript;
  final Object? error;
  int fetchCount = 0;

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    fetchCount++;
    final failure = error;
    if (failure != null) throw failure;
    return transcript;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
