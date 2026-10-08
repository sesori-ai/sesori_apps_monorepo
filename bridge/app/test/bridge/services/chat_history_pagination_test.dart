import "package:sesori_bridge/src/repositories/models/history_window.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
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
        second.messages
            .map((message) => message.info.id)
            .toSet()
            .intersection(
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
      final page = await history.repository.getSessionMessages(
        sessionId: "ses_a",
        storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
        limit: 0,
      );

      expect(page.messages, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test("a session with no stored messages pages cleanly", () async {
      // ses_b was never backfilled, so the store holds nothing for it.
      final page = await history.repository.getSessionMessages(
        sessionId: "ses_b",
        storageScope: testAttachmentStorageScope(sessionId: "ses_b"),
        limit: 5,
      );

      expect(page.messages, isEmpty);
      expect(page.nextCursor, isNull);
    });
  });

  group("user messages before a page", () {
    late TestChatHistory history;

    // Users at m1, m3, m5, m7 and m9; m4 is automation, m8 an error.
    final transcript = [
      for (var index = 1; index <= 10; index++)
        switch (index) {
          1 || 3 || 5 || 7 || 9 => _messageWithParts(id: "m$index"),
          4 => _nonUserWithParts(
            message: _assistant(id: "m4", sender: MessageSender.system),
          ),
          8 => _nonUserWithParts(message: _error(id: "m8")),
          _ => _nonUserWithParts(
            message: _assistant(id: "m$index", sender: MessageSender.agent),
          ),
        },
    ];

    setUp(() async {
      history = createTestChatHistory(sessionRepository: _FakeSessionRepository(transcript: transcript));
      await history.service.backfillSession(sessionId: "ses_a");
    });

    test("the DAO counts only user rows below the given seq", () async {
      final dao = history.database.chatHistoryDao;
      // Rows come back oldest-first, so index i holds m(i + 1).
      final seqs = [for (final row in await dao.getMessages(sessionId: "ses_a")) row.seq];

      expect(await dao.countUserMessagesBefore(sessionId: "ses_a", seq: seqs[0]), 0);
      expect(
        await dao.countUserMessagesBefore(sessionId: "ses_a", seq: seqs[4]),
        2,
        reason: "m4 is automation",
      );
      expect(await dao.countUserMessagesBefore(sessionId: "ses_a", seq: seqs[9]), 5);
      expect(await dao.countUserMessagesBefore(sessionId: "ses_b", seq: 100), 0);
    });

    test("each page counts the user messages older than it", () async {
      final firstIds = <String>[];
      final counts = <int>[];
      int? cursor;
      do {
        final page = await history.service.getSessionMessages(sessionId: "ses_a", limit: 3, before: cursor);
        firstIds.add(page.messages.first.info.id);
        counts.add(page.userMessagesBefore);
        cursor = page.nextCursor;
      } while (cursor != null);

      expect(firstIds, ["m8", "m5", "m2", "m1"]);
      expect(counts, [4, 2, 1, 0], reason: "newest, middle, older and first page");
    });

    test("an unlimited read counts nothing before it", () async {
      final page = await history.service.getSessionMessages(sessionId: "ses_a");

      expect(page.messages, hasLength(10));
      expect(page.userMessagesBefore, 0);
    });

    test("an empty page counts nothing", () async {
      final full = await history.service.getSessionMessages(sessionId: "ses_a", limit: 10);
      final empty = await history.service.getSessionMessages(sessionId: "ses_a", limit: 10, before: full.nextCursor);

      expect(empty.messages, isEmpty);
      expect(empty.userMessagesBefore, 0);
    });

    test("a store-only page counts the users before it", () async {
      final storedOnly = await history.service.getSessionMessages(sessionId: "ses_a", limit: 3, storedOnly: true);
      expect(storedOnly.userMessagesBefore, 4);
    });

    group("loading through a prompt", () {
      late List<int> seqs;

      setUp(() async {
        // Index i holds m(i + 1).
        seqs = [for (final row in await history.database.chatHistoryDao.getMessages(sessionId: "ses_a")) row.seq];
      });

      for (final storedOnly in const [false, true]) {
        test("returns the whole range with the older pair (storedOnly: $storedOnly)", () async {
          final page = await history.service.getSessionMessages(
            sessionId: "ses_a",
            window: HistoryWindowThrough(throughSeq: seqs[2], before: seqs[7]),
            storedOnly: storedOnly,
          );

          expect(page.messages.map((message) => message.info.id), ["m3", "m4", "m5", "m6", "m7"]);
          expect(page.nextCursor, seqs[2], reason: "m1 and m2 are older");
          expect(page.userMessagesBefore, 1, reason: "only m1 is an older user message");
        });
      }

      test("ends the cursor when the range reaches the first message", () async {
        final page = await history.service.getSessionMessages(
          sessionId: "ses_a",
          window: HistoryWindowThrough(throughSeq: seqs[0], before: seqs[9]),
        );

        expect(page.messages.map((message) => message.info.id), [for (var index = 1; index <= 9; index++) "m$index"]);
        expect(page.nextCursor, isNull);
        expect(page.userMessagesBefore, 0);
      });

      test("the archived slice matches the stored one", () async {
        final window = HistoryWindowThrough(throughSeq: seqs[2], before: seqs[7]);
        final stored = await history.service.getSessionMessages(sessionId: "ses_a", window: window);
        final session = await _FakeSessionRepository(transcript: transcript).getStoredSession(sessionId: "ses_a");
        await history.service.exportSessionHistory(
          session: session!,
          title: null,
          createdAt: 1,
          updatedAt: 1,
          archivedAt: 1,
        );
        await history.service.purgeSessionHistory(sessionId: "ses_a");

        final archived = await history.service.getArchivedSessionMessages(sessionId: "ses_a", window: window);

        expect(archived?.messages, stored.messages);
        expect(archived?.nextCursor, stored.nextCursor);
        expect(archived?.userMessagesBefore, stored.userMessagesBefore);
      });
    });

    test("a session with only assistant messages counts no users", () async {
      final assistantsOnly = createTestChatHistory(
        sessionRepository: _FakeSessionRepository(
          transcript: [
            for (var index = 1; index <= 4; index++)
              _nonUserWithParts(
                message: _assistant(id: "a$index", sender: MessageSender.agent),
              ),
          ],
        ),
      );
      await assistantsOnly.service.backfillSession(sessionId: "ses_a");

      final page = await assistantsOnly.service.getSessionMessages(sessionId: "ses_a", limit: 2);
      expect(page.messages, hasLength(2));
      expect(page.userMessagesBefore, 0);
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

Message _message({required String id}) => Message.user(
  promptId: null,
  id: id,
  sessionID: "ses_a",
  agent: null,
  time: const MessageTime(created: 1, completed: null),
);

Message _assistant({required String id, required MessageSender sender}) => Message.assistant(
  id: id,
  sessionID: "ses_a",
  agent: null,
  modelID: null,
  providerID: null,
  sender: sender,
  time: const MessageTime(created: 1, completed: null),
);

Message _error({required String id}) => Message.error(
  id: id,
  sessionID: "ses_a",
  agent: null,
  modelID: null,
  providerID: null,
  errorName: "APIError",
  errorMessage: "failed",
  time: const MessageTime(created: 1, completed: null),
);

MessageWithParts _nonUserWithParts({required Message message}) => MessageWithParts(
  info: message,
  parts: [MessagePart.text(id: "${message.id}-p1", sessionID: "ses_a", messageID: message.id, text: "reply")],
);

MessageWithParts _messageWithParts({required String id}) => MessageWithParts(
  info: _message(id: id),
  parts: [
    MessagePart.text(
      id: "$id-p1",
      sessionID: "ses_a",
      messageID: id,
      text: "text of $id",
    ),
  ],
);

class _FakeSessionRepository({required final List<MessageWithParts> transcript}) implements SessionRepository {
  @override
  Future<SessionMessagesSnapshot> getSessionMessages({required String sessionId}) async => (
    messages: transcript,
    promptDefaults: null,
  );

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
