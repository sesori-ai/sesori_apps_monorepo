import "dart:convert";

import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/set_base_branch_handler.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("SetBaseBranchHandler", () {
    late AppDatabase db;
    late ProjectsDao dao;
    late SetBaseBranchHandler handler;

    setUp(() {
      db = createTestDatabase();
      dao = db.projectsDao;
      handler = SetBaseBranchHandler(dao);
    });

    tearDown(() async {
      await db.close();
    });

    test("canHandle PUT /project/base-branch", () {
      expect(handler.canHandle(makeRequest("PUT", "/project/base-branch")), isTrue);
    });

    test("does not match GET /project/base-branch", () {
      expect(handler.canHandle(makeRequest("GET", "/project/base-branch")), isFalse);
    });

    test("does not match POST /project/base-branch", () {
      expect(handler.canHandle(makeRequest("POST", "/project/base-branch")), isFalse);
    });

    test("valid body returns 200 with success true", () async {
      final response = await handler.handle(
        makeRequest(
          "PUT",
          "/project/base-branch",
          body: jsonEncode({"projectId": "proj-1", "baseBranch": "develop"}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["success"], isTrue);
    });

    test("stores baseBranch in DB after successful PUT", () async {
      await handler.handle(
        makeRequest(
          "PUT",
          "/project/base-branch",
          body: jsonEncode({"projectId": "proj-2", "baseBranch": "main"}),
        ),
        pathParams: {},
        queryParams: {},
      );

      final stored = await dao.getBaseBranch(projectId: "proj-2");
      expect(stored, equals("main"));
    });

    test("body with baseBranch null returns 200 (reset to default)", () async {
      await dao.setBaseBranch(projectId: "proj-3", baseBranch: "develop");

      final response = await handler.handle(
        makeRequest(
          "PUT",
          "/project/base-branch",
          body: jsonEncode({"projectId": "proj-3", "baseBranch": null}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      final stored = await dao.getBaseBranch(projectId: "proj-3");
      expect(stored, isNull);
    });

    test("invalid JSON body returns 400", () async {
      final response = await handler.handle(
        makeRequest("PUT", "/project/base-branch", body: "not json"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("JSON array body returns 400", () async {
      final response = await handler.handle(
        makeRequest("PUT", "/project/base-branch", body: jsonEncode([])),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("missing required projectId field returns 400", () async {
      final response = await handler.handle(
        makeRequest(
          "PUT",
          "/project/base-branch",
          body: jsonEncode({"baseBranch": "develop"}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });

    test("null body is treated as empty object and returns 400", () async {
      final response = await handler.handle(
        makeRequest("PUT", "/project/base-branch"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });
  });
}
