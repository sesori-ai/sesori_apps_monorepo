import "package:drift/drift.dart" show Value;
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/mappers/session_catalog_mapper.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    for (final projectId in ["p1", "p2"]) {
      await db
          .into(db.projectsTable)
          .insert(ProjectsTableCompanion.insert(projectId: projectId, path: "/$projectId", projectionUpdatedAt: 1));
    }
  });

  tearDown(() => db.close());

  Future<void> insert({
    required String id,
    String projectId = "p1",
    String? parentId,
    int updatedAt = 1,
    int? userMessageAt,
    int? activityAt,
    int? seenAt,
    int? archivedAt,
    String? title,
    String? catalogTitle,
  }) {
    return db
        .into(db.sessionTable)
        .insert(
          SessionTableCompanion.insert(
            sessionId: id,
            backendSessionId: "backend-$id",
            projectId: projectId,
            parentSessionId: Value(parentId),
            directory: "/$projectId",
            isDedicated: false,
            archivedAt: Value(archivedAt),
            createdAt: 1,
            updatedAt: updatedAt,
            projectionUpdatedAt: 1,
            lastActivityAt: Value(activityAt),
            lastSeenAt: Value(seenAt),
            lastUserMessageAt: Value(userMessageAt),
            pluginId: "claude",
            title: Value(title),
            catalogTitle: Value(catalogTitle),
          ),
        );
  }

  Future<SessionPageRows> page({
    SessionPageMode mode = SessionPageMode.active,
    List<String> projectIds = const ["p1", "p2"],
    List<SessionPageWord> words = const [],
    SessionPageFilter filter = SessionPageFilter.all,
    Set<String> runningIds = const {},
    SessionPageKey? after,
    int limit = 100,
  }) => db.sessionDao.getSessionPage(
    mode: mode,
    projectIds: projectIds,
    words: words,
    filter: filter,
    runningIds: runningIds,
    after: after,
    limit: limit,
  );

  List<String> ids({required SessionPageRows rows}) => [for (final row in rows.rows) row.sessionId];

  test("orders active roots by displayed time, then id, newest first", () async {
    await insert(id: "a", updatedAt: 10);
    await insert(id: "b", updatedAt: 5, userMessageAt: 20);
    await insert(id: "c", updatedAt: 10);
    await insert(id: "child", parentId: "a", updatedAt: 99);
    await insert(id: "archived", updatedAt: 99, archivedAt: 100);

    expect(ids(rows: await page()), ["b", "c", "a"]);
  });

  test("the SQL displayed time matches the time the mapper sends", () async {
    final cases = [
      (updatedAt: 10, userMessageAt: null),
      (updatedAt: 10, userMessageAt: 5),
      (updatedAt: 10, userMessageAt: 10),
      (updatedAt: 10, userMessageAt: 15),
      (updatedAt: 0, userMessageAt: 3),
    ];
    for (final (index, entry) in cases.indexed) {
      await insert(id: "s$index", updatedAt: entry.updatedAt, userMessageAt: entry.userMessageAt);
    }
    const mapper = SessionCatalogMapper();
    final rows = (await page()).rows;
    final displayed = [for (final row in rows) mapper.map(row: row, unseen: false).time?.updated ?? -1];
    expect(displayed, [15, 10, 10, 10, 3]);
    // Equal times fall back to the id, newest first.
    expect([for (final row in rows) row.sessionId], ["s3", "s2", "s1", "s0", "s4"]);
    final cursorAfterFirst = await page(limit: 1);
    expect(cursorAfterFirst.nextKey, (sortAt: 15, sessionId: "s3"));
  });

  test("the SQL unseen rule matches SessionUnseenCalculator", () async {
    const values = [null, 1, 2, 3];
    const calculator = SessionUnseenCalculator();
    final expected = <String>{};
    var index = 0;
    for (final activity in values) {
      for (final userMessage in values) {
        for (final seen in values) {
          final id = "s${index++}";
          await insert(id: id, activityAt: activity, userMessageAt: userMessage, seenAt: seen);
          if (calculator.isUnseen(activity: activity, userMessage: userMessage, seen: seen)) expected.add(id);
        }
      }
    }
    expect(expected, isNotEmpty);

    final unread = await page(filter: SessionPageFilter.unread);
    expect(ids(rows: unread).toSet(), expected);
    expect(unread.counts, (all: 64, running: 0, unread: expected.length));
  });

  test("keyset pages continue after their cursor across inserts", () async {
    for (var index = 0; index < 5; index++) {
      await insert(id: "s$index", updatedAt: index * 10);
    }
    final first = await page(limit: 2);
    expect(ids(rows: first), ["s4", "s3"]);
    expect(first.nextKey, (sortAt: 30, sessionId: "s3"));

    // A newer row and a row that sorts inside the already-sent range do not
    // shift the next page.
    await insert(id: "new", updatedAt: 100);
    await insert(id: "s3b", updatedAt: 30);
    final second = await page(limit: 2, after: first.nextKey);
    expect(ids(rows: second), ["s2", "s1"]);
    final third = await page(limit: 2, after: second.nextKey);
    expect(ids(rows: third), ["s0"]);
    expect(third.nextKey, isNull);
  });

  test("archived pages hold archived roots ordered by archive time", () async {
    await insert(id: "live", updatedAt: 50);
    await insert(id: "old", updatedAt: 90, archivedAt: 10);
    await insert(id: "recent", updatedAt: 1, archivedAt: 20);

    final archived = await page(mode: SessionPageMode.archived, limit: 1);
    expect(ids(rows: archived), ["recent"]);
    expect(archived.nextKey, (sortAt: 20, sessionId: "recent"));
    expect(
      ids(
        rows: await page(mode: SessionPageMode.archived, after: archived.nextKey),
      ),
      ["old"],
    );
    expect(archived.counts.all, 2);
  });

  test("lists only the given projects", () async {
    await insert(id: "one", projectId: "p1");
    await insert(id: "two", projectId: "p2");

    expect(ids(rows: await page(projectIds: ["p2"])), ["two"]);
    expect((await page(projectIds: [])).counts, (all: 0, running: 0, unread: 0));
  });

  test("every word matches the displayed title or a matching project, literally", () async {
    await insert(id: "fix", title: "Fix the Header", catalogTitle: "ignored");
    await insert(id: "catalog", catalogTitle: "fix the footer");
    await insert(id: "percent", title: r"100% done_now \ path");
    await insert(id: "plain", title: "1000 doneXnow path");
    await insert(id: "other", projectId: "p2", title: "Unrelated");

    List<SessionPageWord> words({required List<String> values, List<String> projectIds = const []}) => [
      for (final word in values) (word: word, projectIds: projectIds),
    ];
    expect(
      ids(
        rows: await page(words: words(values: ["fix"])),
      ).toSet(),
      {"fix", "catalog"},
    );
    expect(
      ids(
        rows: await page(words: words(values: ["fix", "header"])),
      ),
      ["fix"],
    );
    expect(
      ids(
        rows: await page(words: words(values: ["ignored"])),
      ),
      isEmpty,
    );
    expect(
      ids(
        rows: await page(words: words(values: ["0%"])),
      ),
      ["percent"],
    );
    expect(
      ids(
        rows: await page(words: words(values: ["e_n"])),
      ),
      ["percent"],
    );
    expect(
      ids(
        rows: await page(words: words(values: [r"\"])),
      ),
      ["percent"],
    );
    expect(
      ids(
        rows: await page(
          words: [
            (word: "fix", projectIds: const []),
            (word: "app", projectIds: const ["p2"]),
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      ids(
        rows: await page(
          words: words(values: ["unrelated", "p2name"], projectIds: ["p2"]),
        ),
      ),
      ["other"],
    );
  });

  test("counts ignore the chip and running narrows to the given ids", () async {
    await insert(id: "a", updatedAt: 3, activityAt: 9);
    await insert(id: "b", updatedAt: 2);
    await insert(id: "c", updatedAt: 1);

    final running = await page(filter: SessionPageFilter.running, runningIds: {"b", "c", "elsewhere"});
    expect(ids(rows: running), ["b", "c"]);
    expect(running.counts, (all: 3, running: 2, unread: 1));
  });

  test("a limit of 0 reads the counts only", () async {
    await insert(id: "a");

    final counts = await page(limit: 0);
    expect(counts.rows, isEmpty);
    expect(counts.nextKey, isNull);
    expect(counts.counts.all, 1);
  });
}
