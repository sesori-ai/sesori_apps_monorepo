import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/persistence/dao_interfaces.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/pr/gh_cli_service.dart";
import "package:sesori_bridge/src/bridge/pr/pr_refresh_coordinator.dart";
import "package:sesori_bridge/src/bridge/pr/pr_sync_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PrRefreshCoordinator", () {
    test("triggers refresh when gh is ready and repo has GitHub remote", () async {
      final ghCli = _FakeGhCliService(isAvailableResult: true, isAuthenticatedResult: true);
      final prSyncService = _SpyPrSyncService();
      final emittedEvents = <SesoriSseEvent>[];
      final coordinator = PrRefreshCoordinator(
        ghCli: ghCli,
        prSyncService: prSyncService,
        processRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
            }) async {
              return ProcessResult(1, 0, "https://github.com/org/repo.git", "");
            },
        emitBridgeEvent: emittedEvents.add,
      );

      await coordinator.onSessionListRequested(projectId: "p1", projectPath: "/tmp/p1");

      expect(prSyncService.calls, equals([(projectId: "p1", projectPath: "/tmp/p1")]));
      expect(ghCli.isAvailableCallCount, equals(1));
      expect(ghCli.isAuthenticatedCallCount, equals(1));

      coordinator.onPrDataChanged(projectId: "p1");
      expect(emittedEvents, hasLength(1));
      final eventJson = emittedEvents.single.toJson();
      expect(eventJson["type"], equals("sessions.updated"));
      expect(eventJson["projectID"], equals("p1"));
    });

    test("skips refresh when gh is unavailable", () async {
      final ghCli = _FakeGhCliService(isAvailableResult: false, isAuthenticatedResult: true);
      final prSyncService = _SpyPrSyncService();
      final coordinator = PrRefreshCoordinator(
        ghCli: ghCli,
        prSyncService: prSyncService,
        processRunner: _unusedProcessRunner,
        emitBridgeEvent: (SesoriSseEvent _) {},
      );

      await coordinator.onSessionListRequested(projectId: "p1", projectPath: "/tmp/p1");
      await coordinator.onSessionListRequested(projectId: "p1", projectPath: "/tmp/p1");

      expect(prSyncService.calls, isEmpty);
      expect(ghCli.isAvailableCallCount, equals(1));
      expect(ghCli.isAuthenticatedCallCount, equals(1));
    });

    test("skips refresh when project has no GitHub remote", () async {
      var processCallCount = 0;
      final ghCli = _FakeGhCliService(isAvailableResult: true, isAuthenticatedResult: true);
      final prSyncService = _SpyPrSyncService();
      final coordinator = PrRefreshCoordinator(
        ghCli: ghCli,
        prSyncService: prSyncService,
        processRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
            }) async {
              processCallCount++;
              return ProcessResult(1, 0, "https://gitlab.com/org/repo.git", "");
            },
        emitBridgeEvent: (SesoriSseEvent _) {},
      );

      await coordinator.onSessionListRequested(projectId: "p1", projectPath: "/tmp/p1");
      await coordinator.onSessionListRequested(projectId: "p1", projectPath: "/tmp/p1");

      expect(prSyncService.calls, isEmpty);
      expect(processCallCount, equals(1));
    });
  });
}

Future<ProcessResult> _unusedProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError("process runner should not be called");
}

class _FakeGhCliService extends GhCliService {
  final bool isAvailableResult;
  final bool isAuthenticatedResult;
  int isAvailableCallCount = 0;
  int isAuthenticatedCallCount = 0;

  _FakeGhCliService({required this.isAvailableResult, required this.isAuthenticatedResult}) : super();

  @override
  Future<bool> isAvailable() async {
    isAvailableCallCount++;
    return isAvailableResult;
  }

  @override
  Future<bool> isAuthenticated() async {
    isAuthenticatedCallCount++;
    return isAuthenticatedResult;
  }
}

class _SpyPrSyncService extends PrSyncService {
  final List<({String projectId, String projectPath})> calls = <({String projectId, String projectPath})>[];

  _SpyPrSyncService()
    : super(
        ghCli: _FakeGhCliService(isAvailableResult: true, isAuthenticatedResult: true),
        prDao: _NoopPullRequestDao(),
        sessionDao: _NoopSessionDao(),
        onPrDataChanged: (String _) {},
      );

  @override
  void triggerRefreshForProject({required String projectId, required String projectPath}) {
    calls.add((projectId: projectId, projectPath: projectPath));
  }
}

class _NoopSessionDao implements SessionDaoLike {
  @override
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds}) async => {};

  @override
  Future<List<SessionDto>> getSessionsByProject({required String projectId}) async => const <SessionDto>[];
}

class _NoopPullRequestDao implements PullRequestDaoLike {
  @override
  Future<void> upsertPr({
    required String projectId,
    required String branchName,
    required int prNumber,
    required String url,
    required String title,
    required String state,
    required String? mergeableStatus,
    required String? reviewDecision,
    required String? checkStatus,
    required String? sessionId,
    required int lastCheckedAt,
    required int createdAt,
  }) async {}

  @override
  Future<List<PullRequestsTableData>> getPrsByProjectId({required String projectId}) async {
    return const <PullRequestsTableData>[];
  }

  @override
  Future<Map<String, PullRequestsTableData>> getPrsBySessionIds({required List<String> sessionIds}) async {
    return const <String, PullRequestsTableData>{};
  }

  @override
  Future<List<PullRequestsTableData>> getActivePrsByProjectId({required String projectId}) async {
    return const <PullRequestsTableData>[];
  }

  @override
  Future<void> deletePr({required String projectId, required String branchName}) async {}
}
