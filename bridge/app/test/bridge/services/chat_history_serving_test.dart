import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("serving session messages", () {
    test("first read backfills from the plugin and matches it exactly", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          _messageWithParts(id: "m1"),
          _messageWithParts(id: "m2"),
        ],
      );
      final history = createTestChatHistory(sessionRepository: repository);

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(served, equals(repository.transcript), reason: "store-served output must equal plugin-served output");
      expect(repository.fetchCount, 1);
    });

    test("a second read is served from the store without touching the plugin", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.getSessionMessages(sessionId: "ses_a");

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

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
        (await history.service.getSessionMessages(sessionId: "ses_a")).messages.map((message) => message.info.id),
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

      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "live"),
      );
      await history.service.getSessionMessages(sessionId: "ses_a");

      expect(
        repository.fetchCount,
        1,
        reason: "a capture-created row is not a complete transcript, so the first read must still backfill",
      );
    });

    test("a read reflects captures that raced the backfill fetch", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          _messageWithParts(id: "m1"),
          _messageWithParts(id: "m2"),
        ],
      );
      final history = createTestChatHistory(sessionRepository: repository);
      // Several captures land while the fetch is in flight, so they queue
      // behind the backfill. Queue depth keeps the assertion about ordering
      // rather than about microtask luck.
      repository.onFetch = () {
        for (var index = 0; index < 25; index++) {
          unawaited(
            history.service.captureMessage(
              sessionId: "ses_a",
              message: _message(id: "filler-$index"),
            ),
          );
        }
        unawaited(
          history.service.captureMessageRemoved(
            sessionId: "ses_a",
            messageId: "m2",
            shouldCapture: () => true,
          ),
        );
      };

      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

      expect(
        served.map((message) => message.info.id),
        isNot(contains("m2")),
        reason: "the queued removal is newer than the fetched snapshot",
      );
      expect(served.map((message) => message.info.id), contains("filler-24"));
    });

    test("activity queued before a read still forces the re-read", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.getSessionMessages(sessionId: "ses_a");
      final synced = (await history.repository.getSyncState(sessionId: "ses_a"))!;
      repository.transcript = [_messageWithParts(id: "m1"), _messageWithParts(id: "m2")];

      // Not awaited: the staleness write is merely queued when the read is
      // issued, which is what happens when an import commits concurrently.
      final observed = history.service.observeBackendActivity(
        sessionId: "ses_a",
        activityAt: synced.watermark + 5000,
      );
      final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;
      await observed;

      expect(
        served.map((message) => message.info.id),
        const ["m1", "m2"],
        reason: "the freshness decision must see writes already queued for the session",
      );
    });

    test("a staleness update enqueued during a read commits after it", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.getSessionMessages(sessionId: "ses_a");
      final synced = (await history.repository.getSyncState(sessionId: "ses_a"))!;

      // Issue the read, then enqueue the staleness update while it is still
      // running. The read must not observe a half-applied state, and the
      // update must still land.
      final reading = history.service.getSessionMessages(sessionId: "ses_a");
      final observing = history.service.observeBackendActivity(
        sessionId: "ses_a",
        activityAt: synced.watermark + 5000,
      );
      final served = (await reading).messages;
      await observing;

      expect(served.map((message) => message.info.id), const ["m1"]);
      final state = (await history.repository.getSyncState(sessionId: "ses_a"))!;
      expect(state.backendActivityAt, greaterThan(state.watermark), reason: "the update still applied");

      repository.transcript = [_messageWithParts(id: "m1"), _messageWithParts(id: "m2")];
      expect(
        (await history.service.getSessionMessages(sessionId: "ses_a")).messages.map((message) => message.info.id),
        const ["m1", "m2"],
        reason: "the next read sees the staleness recorded during the previous one",
      );
    });

    test("an empty transcript is served without re-fetching", () async {
      final repository = _FakeSessionRepository(transcript: const []);
      final history = createTestChatHistory(sessionRepository: repository);

      expect((await history.service.getSessionMessages(sessionId: "ses_a")).messages, isEmpty);
      expect((await history.service.getSessionMessages(sessionId: "ses_a")).messages, isEmpty);
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

MessageWithParts _messageWithParts({required String id}) => MessageWithParts(
  info: _message(id: id),
  parts: [_part(id: "$id-p1", messageId: id)],
);

class _FakeSessionRepository({required this.transcript, this.error}) implements SessionRepository {
  List<MessageWithParts> transcript;
  final Object? error;
  int fetchCount = 0;

  /// Runs while the fetch is in flight, so a test can interleave live events.
  void Function()? onFetch;

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    fetchCount++;
    onFetch?.call();
    await Future<void>.delayed(Duration.zero);
    final failure = error;
    if (failure != null) throw failure;
    return transcript;
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
