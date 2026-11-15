import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/side_chat_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/side_chat_repository.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";
import "../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late SideChatRepository repository;

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    repository = SideChatRepository(dao: SideChatDao(database: db));
    for (final sessionId in ["s-1", "s-2"]) {
      await recordSessionBinding(
        database: db,
        sessionId: sessionId,
        backendSessionId: "backend-$sessionId",
        pluginId: "fake",
        projectId: "/repo",
        parentSessionId: null,
      );
    }
  });

  Future<({String sideChatId, String exchangeId})> record({
    required String sessionId,
    required String? sideChatId,
    required String question,
    required int answeredAt,
  }) async {
    final recorded = await withClock(
      Clock.fixed(DateTime.fromMillisecondsSinceEpoch(answeredAt)),
      () => repository.recordExchange(
        sessionId: sessionId,
        sideChatId: sideChatId,
        question: question,
        answer: "answer to $question",
        notice: null,
        askedAt: DateTime.fromMillisecondsSinceEpoch(answeredAt - 5),
      ),
    );
    return (sideChatId: recorded.sideChatId, exchangeId: recorded.exchange.id);
  }

  test("a null side chat id mints a new chat; a given one continues it", () async {
    final first = await record(sessionId: "s-1", sideChatId: null, question: "q1", answeredAt: 100);
    final followUp = await record(sessionId: "s-1", sideChatId: first.sideChatId, question: "q2", answeredAt: 200);
    final other = await record(sessionId: "s-1", sideChatId: null, question: "q3", answeredAt: 150);

    expect(followUp.sideChatId, first.sideChatId);
    expect(other.sideChatId, isNot(first.sideChatId));
    expect(first.exchangeId, isNot(followUp.exchangeId));
  });

  test("lists one session's chats newest first by last answer, exchanges oldest first", () async {
    final older = await record(sessionId: "s-1", sideChatId: null, question: "a1", answeredAt: 100);
    final newer = await record(sessionId: "s-1", sideChatId: null, question: "b1", answeredAt: 150);
    await record(sessionId: "s-1", sideChatId: older.sideChatId, question: "a2", answeredAt: 200);
    await record(sessionId: "s-2", sideChatId: null, question: "elsewhere", answeredAt: 300);

    final response = await repository.listForSession(sessionId: "s-1");

    expect(response.sideChats.map((chat) => chat.id), [older.sideChatId, newer.sideChatId]);
    final chat = response.sideChats.first;
    expect(chat.exchanges.map((exchange) => exchange.question), ["a1", "a2"]);
    expect(chat.exchanges.first.answer, "answer to a1");
    expect(chat.exchanges.first.askedAt, 95);
    expect(chat.exchanges.first.answeredAt, 100);
  });

  test("history is the chat's exchanges oldest first, and empty for a new chat", () async {
    final chat = await record(sessionId: "s-1", sideChatId: null, question: "q1", answeredAt: 100);
    await record(sessionId: "s-1", sideChatId: chat.sideChatId, question: "q2", answeredAt: 200);
    await record(sessionId: "s-1", sideChatId: null, question: "unrelated", answeredAt: 150);

    final history = await repository.historyFor(sessionId: "s-1", sideChatId: chat.sideChatId);

    expect(history.map((exchange) => exchange.question), ["q1", "q2"]);
    expect(history.map((exchange) => exchange.answer), ["answer to q1", "answer to q2"]);
    expect(await repository.historyFor(sessionId: "s-1", sideChatId: null), isEmpty);
    expect(await repository.historyFor(sessionId: "s-2", sideChatId: chat.sideChatId), isEmpty);
  });

  test("keeps the answer notice", () async {
    final recorded = await repository.recordExchange(
      sessionId: "s-1",
      sideChatId: null,
      question: "q",
      answer: "a",
      notice: "answered by a fallback model",
      askedAt: DateTime.fromMillisecondsSinceEpoch(1),
    );

    final listed = (await repository.listForSession(sessionId: "s-1")).sideChats.single.exchanges.single;
    expect(recorded.exchange.answerNotice, "answered by a fallback model");
    expect(listed.answerNotice, "answered by a fallback model");
  });

  test("deleting the session deletes its side chats", () async {
    await record(sessionId: "s-1", sideChatId: null, question: "q1", answeredAt: 100);
    await record(sessionId: "s-2", sideChatId: null, question: "q2", answeredAt: 100);

    await db.sessionDao.deleteSession(sessionId: "s-1");

    expect((await repository.listForSession(sessionId: "s-1")).sideChats, isEmpty);
    expect((await repository.listForSession(sessionId: "s-2")).sideChats, hasLength(1));
  });

  test("recording for a deleted session fails its foreign key", () async {
    await db.sessionDao.deleteSession(sessionId: "s-1");

    await expectLater(
      () => record(sessionId: "s-1", sideChatId: null, question: "q", answeredAt: 100),
      throwsA(anything),
    );
  });
}
