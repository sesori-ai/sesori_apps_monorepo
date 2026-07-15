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

    test("unhideProject creates row with hidden=false when project does not exist", () async {
      await dao.unhideProject(projectId: "brand-new");

      final rows = await (db.select(db.projectsTable)..where((t) => t.projectId.equals("brand-new"))).get();
      expect(rows, hasLength(1));
      expect(rows.first.hidden, isFalse);
      expect(rows.first.baseBranch, isNull);
    });

    test("unhideProject on existing hidden=true project sets hidden=false", () async {
      await dao.hideProject(projectId: "proj-hidden");

      await dao.unhideProject(projectId: "proj-hidden");

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(hiddenIds, isEmpty);
    });

    test("unhideProject preserves baseBranch on existing row", () async {
      await dao.setBaseBranch(projectId: "proj-p", baseBranch: "main");
      await dao.hideProject(projectId: "proj-p");

      await dao.unhideProject(projectId: "proj-p");

      final rows = await (db.select(db.projectsTable)..where((t) => t.projectId.equals("proj-p"))).get();
      expect(rows, hasLength(1));
      expect(rows.first.hidden, isFalse);
      expect(rows.first.baseBranch, equals("main"));
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

    });

    group("recordOpenedProject", () {
      test("creates a row with the opened path and timestamps", () async {
        await dao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/projects/a",
          createdAt: 111,
          updatedAt: 222,
        );

        final row = await dao.getProject(projectId: "/projects/a");
        expect(row, isNotNull);
        expect(row!.path, equals("/projects/a"));
        expect(row.createdAt, equals(111));
        expect(row.updatedAt, equals(222));
      });

      test("updates path and updatedAt when re-opening a moved folder", () async {
        await dao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/projects/a",
          createdAt: 111,
          updatedAt: 111,
        );

        await dao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 111,
          updatedAt: 222,
        );

        final row = await dao.getProject(projectId: "/projects/a");
        expect(row!.path, equals("/moved/a"));
        expect(row.createdAt, equals(111));
        expect(row.updatedAt, equals(222));
      });

      test("preserves hidden, baseBranch and displayName on conflict", () async {
        await dao.hideProject(projectId: "/projects/a");
        await dao.setBaseBranch(projectId: "/projects/a", baseBranch: "develop");
        await dao.setDisplayName(projectId: "/projects/a", displayName: "My App");

        await dao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 111,
          updatedAt: 333,
        );

        final row = await dao.getProject(projectId: "/projects/a");
        expect(row!.hidden, isTrue);
        expect(row.baseBranch, equals("develop"));
        expect(row.displayName, equals("My App"));
        expect(row.path, equals("/moved/a"));
        expect(row.createdAt, equals(111));
        expect(row.updatedAt, equals(333));
      });
    });

    group("getResolvedPath", () {
      test("returns null when no row exists", () async {
        final path = await dao.getResolvedPath(projectId: "/projects/a");
        expect(path, isNull);
      });

      test("returns the stored non-null path", () async {
        await dao.insertProjectsIfMissing(projectIds: ["/projects/a"]);

        final path = await dao.getResolvedPath(projectId: "/projects/a");
        expect(path, equals("/projects/a"));
      });

      test("returns the recorded path when a moved folder was re-opened", () async {
        await dao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 0,
          updatedAt: 1,
        );

        final path = await dao.getResolvedPath(projectId: "/projects/a");
        expect(path, equals("/moved/a"));
      });

      test("other writers do not clobber a recorded path", () async {
        await dao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 0,
          updatedAt: 1,
        );

        await dao.hideProject(projectId: "/projects/a");
        await dao.unhideProject(projectId: "/projects/a");
        await dao.setBaseBranch(projectId: "/projects/a", baseBranch: "main");
        await dao.setDisplayName(projectId: "/projects/a", displayName: "My App");
        await dao.insertProjectsIfMissing(projectIds: ["/projects/a"]);

        final path = await dao.getResolvedPath(projectId: "/projects/a");
        expect(path, equals("/moved/a"));
      });
    });

    group("insertProjectsIfMissing", () {
      test("insertProjectsIfMissing inserts all missing projects in one batch", () async {
        await dao.insertProjectsIfMissing(projectIds: ["p1", "p2", "p3"]);

        final rows = await db.select(db.projectsTable).get();
        expect(rows, hasLength(3));
        expect(rows.map((r) => r.projectId).toSet(), equals({"p1", "p2", "p3"}));
        for (final row in rows) {
          expect(row.hidden, isFalse);
          expect(row.baseBranch, isNull);
        }
      });

      test("insertProjectsIfMissing is no-op for empty list", () async {
        await dao.insertProjectsIfMissing(projectIds: []);

        final rows = await db.select(db.projectsTable).get();
        expect(rows, isEmpty);
      });

      test("insertProjectsIfMissing preserves existing hidden/baseBranch fields for each id", () async {
        await dao.hideProject(projectId: "p1");
        await dao.setBaseBranch(projectId: "p2", baseBranch: "develop");

        // Batch insert — p1 and p2 already exist, p3 is new.
        await dao.insertProjectsIfMissing(projectIds: ["p1", "p2", "p3"]);

        // p1 must still be hidden.
        final hiddenIds = await dao.getHiddenProjectIds();
        expect(hiddenIds, contains("p1"));

        // p2 must still have baseBranch=develop.
        final branch = await dao.getBaseBranch(projectId: "p2");
        expect(branch, equals("develop"));

        // p3 is newly inserted with defaults.
        final rows = await (db.select(db.projectsTable)..where((t) => t.projectId.equals("p3"))).get();
        expect(rows, hasLength(1));
        expect(rows.first.hidden, isFalse);
        expect(rows.first.baseBranch, isNull);
      });
    });
  });
}
