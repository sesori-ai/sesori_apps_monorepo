import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("ProjectsDao", () {
    late AppDatabase db;
    late ProjectsDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.projectsDao;
    });

    tearDown(() async {
      await db.close();
    });

    test("returns empty set when database is fresh", () async {
      final hiddenIds = await dao.getHiddenProjectIds();
      expect(hiddenIds, isEmpty);
    });

    test("hideProject persists project id", () async {
      await dao.hideProject(projectId: "project-1");

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(hiddenIds, equals({"project-1"}));
    });

    test("hideProject is idempotent", () async {
      await dao.hideProject(projectId: "project-1");
      await dao.hideProject(projectId: "project-1");

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(hiddenIds, equals({"project-1"}));
    });

    test("unhideProject removes project id", () async {
      await dao.hideProject(projectId: "project-1");

      await dao.unhideProject(projectId: "project-1");

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(hiddenIds, isEmpty);
    });

    test("unhideProject is no-op for unknown id", () async {
      await dao.hideProject(projectId: "project-1");

      await dao.unhideProject(projectId: "project-2");

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(hiddenIds, equals({"project-1"}));
    });

    test("handles project IDs with slashes", () async {
      await dao.hideProject(projectId: "/Users/alex/projects/my-app");

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(hiddenIds, equals({"/Users/alex/projects/my-app"}));
    });

    test("hiddenProjectIdsStream emits when hide/unhide changes hidden set", () async {
      final expectation = expectLater(
        dao.hiddenProjectIdsStream.take(3),
        emitsInOrder([
          equals(<String>{}),
          equals({"project-1"}),
          equals(<String>{}),
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await dao.hideProject(projectId: "project-1");
      await dao.unhideProject(projectId: "project-1");

      await expectation;
    });

    group("incrementAndGetWorktreeCounter", () {
      test("returns 1 for a project with no existing row", () async {
        final counter = await dao.incrementAndGetWorktreeCounter(projectId: "proj-1");
        expect(counter, equals(1));
      });

      test("returns 2 on second increment", () async {
        await dao.incrementAndGetWorktreeCounter(projectId: "proj-1");
        final counter = await dao.incrementAndGetWorktreeCounter(projectId: "proj-1");
        expect(counter, equals(2));
      });

      test("preserves existing hidden=true flag when incrementing", () async {
        await dao.hideProject(projectId: "proj-hidden");

        await dao.incrementAndGetWorktreeCounter(projectId: "proj-hidden");

        final hiddenIds = await dao.getHiddenProjectIds();
        expect(hiddenIds, contains("proj-hidden"));
      });

      test("independent increments for different projects", () async {
        final a = await dao.incrementAndGetWorktreeCounter(projectId: "proj-a");
        final b = await dao.incrementAndGetWorktreeCounter(projectId: "proj-b");
        final a2 = await dao.incrementAndGetWorktreeCounter(projectId: "proj-a");

        expect(a, equals(1));
        expect(b, equals(1));
        expect(a2, equals(2));
      });
    });

    group("getBaseBranch", () {
      test("returns null for unknown project", () async {
        final result = await dao.getBaseBranch(projectId: "unknown");
        expect(result, isNull);
      });

      test("returns set value after setBaseBranch", () async {
        await dao.setBaseBranch(projectId: "proj-1", baseBranch: "main");

        final result = await dao.getBaseBranch(projectId: "proj-1");
        expect(result, equals("main"));
      });
    });

    group("setBaseBranch", () {
      test("sets base branch for a new project row", () async {
        await dao.setBaseBranch(projectId: "proj-new", baseBranch: "develop");

        final result = await dao.getBaseBranch(projectId: "proj-new");
        expect(result, equals("develop"));
      });

      test("updates base branch for an existing row", () async {
        await dao.setBaseBranch(projectId: "proj-1", baseBranch: "main");
        await dao.setBaseBranch(projectId: "proj-1", baseBranch: "develop");

        final result = await dao.getBaseBranch(projectId: "proj-1");
        expect(result, equals("develop"));
      });

      test("sets base branch to null (resets)", () async {
        await dao.setBaseBranch(projectId: "proj-1", baseBranch: "main");
        await dao.setBaseBranch(projectId: "proj-1", baseBranch: null);

        final result = await dao.getBaseBranch(projectId: "proj-1");
        expect(result, isNull);
      });

      test("preserves existing hidden flag", () async {
        await dao.hideProject(projectId: "proj-hidden");
        await dao.setBaseBranch(projectId: "proj-hidden", baseBranch: "feature");

        final hiddenIds = await dao.getHiddenProjectIds();
        expect(hiddenIds, contains("proj-hidden"));

        final branch = await dao.getBaseBranch(projectId: "proj-hidden");
        expect(branch, equals("feature"));
      });

      test("preserves existing worktreeCounter", () async {
        await dao.incrementAndGetWorktreeCounter(projectId: "proj-1");
        await dao.incrementAndGetWorktreeCounter(projectId: "proj-1");

        await dao.setBaseBranch(projectId: "proj-1", baseBranch: "main");

        // increment again and expect it continues from 2 → 3
        final counter = await dao.incrementAndGetWorktreeCounter(projectId: "proj-1");
        expect(counter, equals(3));
      });
    });

    group("insertProjectIfMissing", () {
      test("insertProjectIfMissing inserts new project with default fields", () async {
        await dao.insertProjectIfMissing(projectId: "proj-1");

        final rows = await (db.select(db.projectsTable)).get();
        expect(rows, hasLength(1));
        expect(rows.first.projectId, equals("proj-1"));
        expect(rows.first.hidden, isFalse);
        expect(rows.first.baseBranch, isNull);
        expect(rows.first.worktreeCounter, equals(0));
      });

      test("insertProjectIfMissing is no-op when project exists with hidden=true", () async {
        await dao.hideProject(projectId: "proj-1");

        await dao.insertProjectIfMissing(projectId: "proj-1");

        final hiddenIds = await dao.getHiddenProjectIds();
        expect(hiddenIds, contains("proj-1"));
      });

      test("insertProjectIfMissing is no-op when project exists with custom baseBranch", () async {
        await dao.setBaseBranch(projectId: "proj-1", baseBranch: "develop");

        await dao.insertProjectIfMissing(projectId: "proj-1");

        final branch = await dao.getBaseBranch(projectId: "proj-1");
        expect(branch, equals("develop"));

        final rows = await (db.select(db.projectsTable)..where((t) => t.projectId.equals("proj-1"))).get();
        expect(rows.first.worktreeCounter, equals(0));
      });
    });
  });
}
