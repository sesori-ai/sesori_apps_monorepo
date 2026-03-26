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
  });
}
