import "dart:convert";

import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/get_base_branch_handler.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetBaseBranchHandler", () {
    late AppDatabase db;
    late ProjectsDao dao;
    late GetBaseBranchHandler handler;

    setUp(() {
      db = createTestDatabase();
      dao = db.projectsDao;
      handler = GetBaseBranchHandler(dao);
    });

    tearDown(() async {
      await db.close();
    });

    test("canHandle GET /project/base-branch", () {
      expect(handler.canHandle(makeRequest("GET", "/project/base-branch")), isTrue);
    });

    test("does not match POST /project/base-branch", () {
      expect(handler.canHandle(makeRequest("POST", "/project/base-branch")), isFalse);
    });

    test("does not match GET /project/base-branch/extra", () {
      expect(handler.canHandle(makeRequest("GET", "/project/base-branch/extra")), isFalse);
    });

    test("returns 400 when x-project-id header is missing", () async {
      final response = await handler.handle(
        makeRequest("GET", "/project/base-branch"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("x-project-id"));
    });

    test("returns 400 when x-project-id header is empty", () async {
      final response = await handler.handle(
        makeRequest("GET", "/project/base-branch", headers: {"x-project-id": ""}),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("x-project-id"));
    });

    test("returns baseBranch null for unknown project", () async {
      final response = await handler.handle(
        makeRequest("GET", "/project/base-branch", headers: {"x-project-id": "unknown-project"}),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body.containsKey("baseBranch"), isTrue);
      expect(body["baseBranch"], isNull);
    });

    test("returns configured baseBranch after it has been set", () async {
      await dao.setBaseBranch(projectId: "/Users/dev/my-app", baseBranch: "develop");

      final response = await handler.handle(
        makeRequest("GET", "/project/base-branch", headers: {"x-project-id": "/Users/dev/my-app"}),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["baseBranch"], equals("develop"));
    });

    test("header lookup is case-insensitive", () async {
      await dao.setBaseBranch(projectId: "proj-1", baseBranch: "main");

      final response = await handler.handle(
        makeRequest("GET", "/project/base-branch", headers: {"X-Project-Id": "proj-1"}),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["baseBranch"], equals("main"));
    });
  });
}
