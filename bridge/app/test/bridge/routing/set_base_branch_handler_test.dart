import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/set_base_branch_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
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

    test("valid body returns 200 with empty success response", () async {
      final response = await handler.handle(
        makeRequest("PUT", "/project/base-branch"),
        body: const SetBaseBranchRequest(projectId: "proj-1", baseBranch: "develop"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("stores baseBranch in DB after successful PUT", () async {
      await handler.handle(
        makeRequest("PUT", "/project/base-branch"),
        body: const SetBaseBranchRequest(projectId: "proj-2", baseBranch: "main"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final stored = await dao.getBaseBranch(projectId: "proj-2");
      expect(stored, equals("main"));
    });

    test("empty project id returns 400", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("PUT", "/project/base-branch"),
          body: const SetBaseBranchRequest(projectId: "", baseBranch: "main"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("empty base branch returns 400", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("PUT", "/project/base-branch"),
          body: const SetBaseBranchRequest(projectId: "proj-4", baseBranch: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
