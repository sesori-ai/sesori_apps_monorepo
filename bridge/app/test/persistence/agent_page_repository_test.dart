import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/agent_pages_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/agent_pages_table.dart";
import "package:sesori_bridge/src/repositories/agent_page_repository.dart";
import "package:sesori_bridge/src/repositories/models/agent_page.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";
import "../helpers/test_database.dart";

const _sections = [
  PageSection(
    heading: "Layout",
    body: "Pick **one**.",
    images: [PageImage(path: "/copies/s-1/a.png", width: 640, height: 480, caption: "Option A")],
    questions: [
      PageQuestion(
        id: "layout",
        title: "Which layout?",
        body: null,
        images: [],
        kind: PageQuestionKind.single(
          options: [
            PageOption(id: "a", label: "A", description: null, image: null, recommended: true),
            PageOption(id: "b", label: "B", description: "Denser", image: null, recommended: false),
          ],
        ),
        isRequired: true,
      ),
      PageQuestion(id: "why", title: "Why?", body: null, images: [], kind: PageQuestionKind.text(), isRequired: false),
    ],
  ),
];

const _answered = AgentPageOutcome.answered(
  answers: [
    PageAnswer(
      questionId: "layout",
      value: PageAnswerValue.choice(optionId: "a"),
      note: "Keep the margins",
    ),
    PageAnswer(
      questionId: "why",
      value: PageAnswerValue.text(text: "Clearer"),
      note: null,
    ),
  ],
  note: "Ship it",
);

void main() {
  late AppDatabase db;
  late AgentPagesDao dao;
  late AgentPageRepository repository;
  late List<AgentPageEvent> events;

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    dao = AgentPagesDao(database: db);
    repository = AgentPageRepository(dao: dao);
    addTearDown(repository.dispose);
    events = [];
    final subscription = repository.events.listen(events.add);
    addTearDown(subscription.cancel);
    for (final (sessionId, parentSessionId) in [("root", null), ("child", "root"), ("other", null)]) {
      await recordSessionBinding(
        database: db,
        sessionId: sessionId,
        backendSessionId: "backend-$sessionId",
        pluginId: "fake",
        projectId: "/repo",
        parentSessionId: parentSessionId,
      );
    }
  });

  Future<PendingPage> add({required String sessionId, required String? displaySessionId, int at = 100}) {
    return withClock(
      Clock.fixed(DateTime.fromMillisecondsSinceEpoch(at)),
      () => repository.add(
        sessionId: sessionId,
        displaySessionId: displaySessionId,
        title: "Pick a layout",
        intro: "Two options.",
        sections: _sections,
      ),
    );
  }

  test("adds a pending page and announces it", () async {
    final page = await add(sessionId: "child", displaySessionId: "root");
    await pumpEventQueue();

    expect(page.id, startsWith("sesori-page-"));
    expect(page.sessionId, "child");
    expect(page.displaySessionId, "root");
    final stored = await repository.find(id: page.id);
    expect(stored?.page, page);
    expect(stored?.outcome, isNull);
    expect(events.single, isA<AgentPageAsked>().having((event) => event.page, "page", page));
  });

  test("lists a session's own pending pages and those surfaced under it, oldest first", () async {
    final childPage = await add(sessionId: "child", displaySessionId: "root", at: 200);
    final rootPage = await add(sessionId: "root", displaySessionId: null, at: 100);
    await add(sessionId: "other", displaySessionId: null);
    final settled = await add(sessionId: "root", displaySessionId: null, at: 50);
    await repository.settle(id: settled.id, outcome: const AgentPageOutcome.dismissed());

    expect((await repository.pendingPages(sessionId: "root")).map((page) => page.id), [rootPage.id, childPage.id]);
    expect((await repository.pendingPages(sessionId: "child")).map((page) => page.id), [childPage.id]);
  });

  test("the first settle wins; a later one returns null and announces nothing", () async {
    final page = await add(sessionId: "child", displaySessionId: "root");
    await pumpEventQueue();
    events.clear();

    final winner = await withClock(
      Clock.fixed(DateTime.fromMillisecondsSinceEpoch(500)),
      () => repository.settle(id: page.id, outcome: _answered),
    );
    final loser = await repository.settle(id: page.id, outcome: const AgentPageOutcome.dismissed());
    await pumpEventQueue();

    expect(winner, page);
    expect(loser, isNull);
    expect(
      events.single,
      isA<AgentPageSettled>()
          .having((event) => event.page, "page", page)
          .having((e) => e.outcome, "outcome", _answered),
    );
    expect((await repository.find(id: page.id))?.outcome, _answered);
    final row = await dao.getPage(id: page.id);
    expect(row?.status, AgentPageStatus.answered);
    expect(row?.settledAt, 500);
    expect(await repository.pendingPages(sessionId: "root"), isEmpty);
  });

  test("concurrent settles have exactly one winner", () async {
    final page = await add(sessionId: "root", displaySessionId: null);
    await pumpEventQueue();
    events.clear();

    final results = await Future.wait([
      repository.settle(id: page.id, outcome: _answered),
      repository.settle(id: page.id, outcome: const AgentPageOutcome.dismissed()),
    ]);
    await pumpEventQueue();

    expect(results.nonNulls, [page]);
    expect(events, hasLength(1));
  });

  test("settling or finding a missing page returns null", () async {
    expect(await repository.settle(id: "sesori-page-missing", outcome: _answered), isNull);
    expect(await repository.find(id: "sesori-page-missing"), isNull);
  });

  test("a dismissed page keeps its content", () async {
    final page = await add(sessionId: "root", displaySessionId: null);
    await repository.settle(id: page.id, outcome: const AgentPageOutcome.dismissed());

    final stored = await repository.find(id: page.id);
    expect(stored?.page, page);
    expect(stored?.outcome, const AgentPageOutcome.dismissed());
  });

  test("awaiting roots are the distinct roots with a pending page", () async {
    await add(sessionId: "child", displaySessionId: "root");
    await add(sessionId: "root", displaySessionId: null);
    final settled = await add(sessionId: "other", displaySessionId: null);
    await repository.settle(id: settled.id, outcome: const AgentPageOutcome.dismissed());

    expect(await repository.awaitingRootSessionIds(), {"root"});
  });

  test("deleting the session deletes its pages", () async {
    final childPage = await add(sessionId: "child", displaySessionId: "root");
    final otherPage = await add(sessionId: "other", displaySessionId: null);

    await db.sessionDao.deleteSession(sessionId: "child");

    expect(await repository.find(id: childPage.id), isNull);
    expect(await repository.find(id: otherPage.id), isNotNull);
    expect(await repository.awaitingRootSessionIds(), {"other"});
  });

  test("adding a page for a missing session fails its foreign key", () async {
    await expectLater(() => add(sessionId: "missing", displaySessionId: null), throwsA(anything));
    await pumpEventQueue();
    expect(events, isEmpty);
  });
}
