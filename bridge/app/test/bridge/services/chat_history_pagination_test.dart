import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("paging over stored history", () {
    late TestChatHistory history;

    setUp(() async {
      final repository = _FakeSessionRepository(
        transcript: [for (var index = 1; index <= 10; index++) _messageWithParts(id: "m$index")],
      );
      history = createTestChatHistory(sessionRepository: repository);
      await history.service.backfillSession(sessionId: "ses_a");
    });

    test("no limit returns the whole transcript with no cursor", () async {
      final page = await history.service.getSessionMessages(sessionId: "ses_a");

      expect(page.messages, hasLength(10));
      expect(page.messages.first.info.id, "m1");
      expect(page.nextCursor, isNull, reason: "an unpaged read is always complete");
    });

    test("a limit returns the newest page, oldest-first within it", () async {
      final page = await history.service.getSessionMessages(sessionId: "ses_a", limit: 3);

      expect(page.messages.map((message) => message.info.id), const ["m8", "m9", "m10"]);
      expect(page.nextCursor, isNotNull);
    });

    test("the cursor is exclusive, so pages do not overlap", () async {
      final first = await history.service.getSessionMessages(sessionId: "ses_a", limit: 3);
      final second = await history.service.getSessionMessages(
        sessionId: "ses_a",
        limit: 3,
        before: first.nextCursor,
      );

      expect(second.messages.map((message) => message.info.id), const ["m5", "m6", "m7"]);
      expect(
        second.messages.map((message) => message.info.id).toSet().intersection(
          first.messages.map((message) => message.info.id).toSet(),
        ),
        isEmpty,
      );
    });

    test("paging back reaches the start exactly once", () async {
      final seen = <String>[];
      int? cursor;
      var pages = 0;
      while (true) {
        final page = await history.service.getSessionMessages(sessionId: "ses_a", limit: 4, before: cursor);
        seen.insertAll(0, page.messages.map((message) => message.info.id));
        pages++;
        if (page.nextCursor == null) break;
        cursor = page.nextCursor;
        expect(pages, lessThan(10), reason: "paging must terminate");
      }

      expect(seen, [for (var index = 1; index <= 10; index++) "m$index"]);
    });

    test("a page carries the parts of its own messages only", () async {
      final page = await history.service.getSessionMessages(sessionId: "ses_a", limit: 2);

      expect(page.messages.every((message) => message.parts.length == 1), isTrue);
      expect(page.messages.last.parts.single.messageID, "m10");
    });

    test("an exact-fit page still reports a cursor, and the next page ends it", () async {
      final page = await history.service.getSessionMessages(sessionId: "ses_a", limit: 10);
      expect(page.messages, hasLength(10));
      expect(page.nextCursor, isNotNull, reason: "a full page cannot prove it is the last");

      final next = await history.service.getSessionMessages(
        sessionId: "ses_a",
        limit: 10,
        before: page.nextCursor,
      );
      expect(next.messages, isEmpty);
      expect(next.nextCursor, isNull);
    });

    test("an empty page never claims there is more", () async {
      // A page that returned nothing cannot point a cursor at anything older,
      // so it must terminate rather than invite another request.
      final page = await history.repository.getSessionMessages(sessionId: "ses_a", limit: 0);

      expect(page.messages, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test("a session with no stored messages pages cleanly", () async {
      // ses_b was never backfilled, so the store holds nothing for it.
      final page = await history.repository.getSessionMessages(sessionId: "ses_b", limit: 5);

      expect(page.messages, isEmpty);
      expect(page.nextCursor, isNull);
    });
  });

  group("wire compatibility", () {
    test("an older app's body decodes, meaning the full transcript", () {
      // What a pre-pagination client sends: sessionId only.
      final request = SessionMessagesRequest.fromJson(const {"sessionId": "ses_a"});

      expect(request.sessionId, "ses_a");
      expect(request.limit, isNull);
      expect(request.before, isNull);
    });

    test("an older bridge's response decodes as a complete transcript", () {
      // What a pre-pagination bridge returns: no nextCursor field at all.
      final response = MessageWithPartsResponse.fromJson(const {"messages": <Map<String, dynamic>>[]});

      expect(response.nextCursor, isNull, reason: "absence means complete, so no load-older affordance");
    });

    test("a paging request round-trips", () {
      const request = SessionMessagesRequest(sessionId: "ses_a", limit: 20, before: 40);

      expect(SessionMessagesRequest.fromJson(request.toJson()), request);
    });
  });
}

Message _message({required String id}) =>
    Message.user(id: id, sessionID: "ses_a", agent: null, time: const MessageTime(created: 1, completed: null));

MessageWithParts _messageWithParts({required String id}) => MessageWithParts(
  info: _message(id: id),
  parts: [
    MessagePart(
      id: "$id-p1",
      sessionID: "ses_a",
      messageID: id,
      type: MessagePartType.text,
      text: "text of $id",
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
      attachment: null,
    ),
  ],
);

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({required this.transcript});

  final List<MessageWithParts> transcript;

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async => transcript;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
