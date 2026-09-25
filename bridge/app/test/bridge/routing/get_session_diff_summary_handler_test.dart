import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/repositories/mappers/git_diff_output_mapper.dart";
import "package:sesori_bridge/src/repositories/session_diff_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/get_session_diff_summary_handler.dart";
import "package:sesori_bridge/src/services/session_diff_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "get_session_diffs_handler_test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionDiffSummaryHandler", () {
    late AppDatabase db;
    late FakeProcessRunner processRunner;
    late GetSessionDiffSummaryHandler handler;

    setUp(() {
      db = createTestDatabase();
      processRunner = FakeProcessRunner();
      handler = GetSessionDiffSummaryHandler(
        sessionDiffService: SessionDiffService(
          sessionRepository: singlePluginSessionRepository(
            plugin: FakeBridgePlugin(),
            sessionDao: db.sessionDao,
            projectsDao: db.projectsDao,
            pullRequestDao: db.pullRequestDao,
            unseenCalculator: const SessionUnseenCalculator(),
          ),
          sessionDiffRepository: SessionDiffRepository(
            gitCliApi: GitCliApi(
              streamingProcessRunner: const StreamingProcessRunner(),
              processRunner: processRunner,
              gitPathExists: ({required String gitPath}) => true,
            ),
            outputMapper: const GitDiffOutputMapper(),
          ),
          filesystemRepository: FilesystemRepository(
            filesystemApi: const FilesystemApi(),
            permissionValidator: const FilesystemPermissionValidator(),
          ),
        ),
      );
    });

    tearDown(() => db.close());

    test("canHandle accepts only POST /session/diff-summary", () {
      expect(handler.canHandle(makeRequest("POST", "/session/diff-summary")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/diff-summary")), isFalse);
      expect(handler.canHandle(makeRequest("POST", "/session/diffs")), isFalse);
    });

    test("a missing session is a 404 with a body, unlike an unknown route", () async {
      final response = await handler.routeForTest(
        makeRequest("POST", "/session/diff-summary", body: jsonEncode(const SessionIdRequest(sessionId: "missing"))),
      );

      expect(response.status, 404);
      expect(
        SessionDiffSummaryErrorResponse.fromJson(jsonDecodeMap(response.body ?? "")).code,
        SessionDiffSummaryErrorCode.sessionNotFound,
      );
      expect(processRunner.invocations, isEmpty);
    });

    test("a session with nothing to compare has zero totals", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]);
      await db.sessionDao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        preservePullRequestScope: false,
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: null,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",
        lastAgent: null,
        lastAgentModel: null,
      );

      final response = await handler.routeForTest(
        makeRequest("POST", "/session/diff-summary", body: jsonEncode(const SessionIdRequest(sessionId: "s1"))),
      );

      expect(response.status, 200);
      expect(response.body, '{"additions":0,"deletions":0}');
      expect(processRunner.invocations, isEmpty);
    });
  });
}
