import "dart:convert";

import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/hide_project_handler.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("HideProjectHandler", () {
    late AppDatabase db;
    late ProjectsDao dao;
    late HideProjectHandler handler;

    setUp(() {
      db = createTestDatabase();
      dao = db.projectsDao;
      handler = HideProjectHandler(dao);
    });

    tearDown(() async {
      await db.close();
    });

    test("canHandle POST /project/hide", () {
      expect(handler.canHandle(makeRequest("POST", "/project/hide")), isTrue);
    });

    test("does not match DELETE /project/:id", () {
      expect(handler.canHandle(makeRequest("DELETE", "/project/p1")), isFalse);
    });

    test("returns 200 and stores hidden project id", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/hide", body: jsonEncode({"projectId": "p1"})),
        pathParams: {},
        queryParams: {},
      );

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(response.status, equals(200));
      expect(hiddenIds, contains("p1"));
    });

    test("handles project IDs containing slashes", () async {
      const projectId = "/Users/alex/projects/my-app";
      final response = await handler.handle(
        makeRequest("POST", "/project/hide", body: jsonEncode({"projectId": projectId})),
        pathParams: {},
        queryParams: {},
      );

      final hiddenIds = await dao.getHiddenProjectIds();
      expect(response.status, equals(200));
      expect(hiddenIds, contains(projectId));
    });

    test("returns 400 when body is missing projectId", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/hide", body: jsonEncode({})),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing or empty projectId"));
    });

    test("returns 400 when body is invalid JSON", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/hide", body: "not json"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });
  });
}
