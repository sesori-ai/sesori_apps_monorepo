import "package:sesori_bridge/src/bridge/persistence/daos/hidden_projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("HiddenProjectsDao", () {
    late AppDatabase db;
    late HiddenProjectsDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.hiddenProjectsDao;
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
  });
}
