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

    test("canHandle POST /project/base-branch", () {
      expect(handler.canHandle(makeRequest("POST", "/project/base-branch")), isTrue);
    });

    test("does not match GET /project/base-branch", () {
      expect(handler.canHandle(makeRequest("GET", "/project/base-branch")), isFalse);
    });

    test("does not match POST /project/base-branch/extra", () {
      expect(handler.canHandle(makeRequest("POST", "/project/base-branch/extra")), isFalse);
    });

    test("returns baseBranch null for unknown project", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/project/base-branch", body: jsonEncode({"projectId": "unknown-project"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
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

      final response = await handler.handleInternal(
        makeRequest("POST", "/project/base-branch", body: jsonEncode({"projectId": "/Users/dev/my-app"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["baseBranch"], equals("develop"));
    });

    test("returns baseBranch for another project", () async {
      await dao.setBaseBranch(projectId: "proj-1", baseBranch: "main");

      final response = await handler.handleInternal(
        makeRequest("POST", "/project/base-branch", body: jsonEncode({"projectId": "proj-1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
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
