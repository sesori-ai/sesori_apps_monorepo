import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/dao_interfaces.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/pr/gh_cli_service.dart";
import "package:sesori_bridge/src/bridge/pr/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/pr/pr_sync_service.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("PrSyncService", () {
    test("emits project id when a new matched PR is found", () async {
      final gh = _FakeGhCliService(
        listOpenPrsResult: const <GhPullRequest>[
          GhPullRequest(
            number: 11,
            url: "https://github.com/org/repo/pull/11",
            title: "New PR",
            state: "OPEN",
            headRefName: "feature/new-pr",
            mergeable: "MERGEABLE",
            reviewDecision: null,
            statusCheckRollup: "SUCCESS",
          ),
        ],
      );
      final prDao = _FakePullRequestDao();
      final sessionDao = _FakeSessionDao(
        sessionsByProject: <String, List<SessionDto>>{
          "project-1": <SessionDto>[
            _session(sessionId: "session-1", projectId: "project-1", branchName: "feature/new-pr"),
          ],
        },
      );
      final service = PrSyncService(
        ghCli: gh,
        prDao: prDao,
        sessionDao: sessionDao,
        processRunner: _githubRemoteProcessRunner,
        debounceWindow: const Duration(milliseconds: 1),
      );
      addTearDown(service.dispose);

      final emittedProjectIds = <String>[];
      final sub = service.prChanges.listen(emittedProjectIds.add);
      addTearDown(sub.cancel);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prDao.upsertCalls == 1);

      final prs = await prDao.getPrsByProjectId(projectId: "project-1");
      expect(prs, hasLength(1));
      expect(prs.single.prNumber, equals(11));
      expect(prs.single.branchName, equals("feature/new-pr"));
      expect(emittedProjectIds, equals(<String>["project-1"]));
    });

    test("does not emit when PR data is unchanged", () async {
      final gh = _FakeGhCliService(
        listOpenPrsResult: const <GhPullRequest>[
          GhPullRequest(
            number: 33,
            url: "https://github.com/org/repo/pull/33",
            title: "No changes",
            state: "OPEN",
            headRefName: "feature/no-change",
            mergeable: "MERGEABLE",
            reviewDecision: "APPROVED",
            statusCheckRollup: "SUCCESS",
          ),
        ],
      );
      final prDao = _FakePullRequestDao(
        seed: <PullRequestDto>[
          _prData(
            projectId: "project-1",
            branchName: "feature/no-change",
            prNumber: 33,
            title: "No changes",
            state: "OPEN",
            mergeableStatus: "MERGEABLE",
            reviewDecision: "APPROVED",
            checkStatus: "SUCCESS",
          ),
        ],
      );
      final sessionDao = _FakeSessionDao(
        sessionsByProject: <String, List<SessionDto>>{
          "project-1": <SessionDto>[
            _session(sessionId: "session-1", projectId: "project-1", branchName: "feature/no-change"),
          ],
        },
      );
      final service = PrSyncService(
        ghCli: gh,
        prDao: prDao,
        sessionDao: sessionDao,
        processRunner: _githubRemoteProcessRunner,
      );
      addTearDown(service.dispose);

      final emittedProjectIds = <String>[];
      final sub = service.prChanges.listen(emittedProjectIds.add);
      addTearDown(sub.cancel);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prDao.upsertCalls == 1);

      expect(emittedProjectIds, isEmpty);
    });

    test("fetches final PR state for disappeared active PR", () async {
      final gh = _FakeGhCliService(
        listOpenPrsResult: const <GhPullRequest>[],
        prByNumber: <int, GhPullRequest>{
          22: const GhPullRequest(
            number: 22,
            url: "https://github.com/org/repo/pull/22",
            title: "Merged PR",
            state: "MERGED",
            headRefName: "feature/merged",
            mergeable: "UNKNOWN",
            reviewDecision: "APPROVED",
            statusCheckRollup: "SUCCESS",
          ),
        },
      );
      final prDao = _FakePullRequestDao(
        seed: <PullRequestDto>[
          _prData(
            projectId: "project-1",
            branchName: "feature/merged",
            prNumber: 22,
            title: "Merged PR",
            state: "OPEN",
            mergeableStatus: "MERGEABLE",
            reviewDecision: "",
            checkStatus: "PENDING",
          ),
        ],
      );
      final sessionDao = _FakeSessionDao(
        sessionsByProject: <String, List<SessionDto>>{
          "project-1": <SessionDto>[
            _session(sessionId: "session-1", projectId: "project-1", branchName: "feature/merged"),
          ],
        },
      );
      final service = PrSyncService(
        ghCli: gh,
        prDao: prDao,
        sessionDao: sessionDao,
        processRunner: _githubRemoteProcessRunner,
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prDao.upsertCalls == 1);

      final prs = await prDao.getPrsByProjectId(projectId: "project-1");
      expect(prs.single.state, equals("MERGED"));
      expect(gh.getPrByNumberCalls, contains(22));
    });

    test("caches gh availability and skips refresh when unavailable", () async {
      final gh = _FakeGhCliService(
        listOpenPrsResult: const <GhPullRequest>[],
        isAvailableResult: false,
      );
      final service = PrSyncService(
        ghCli: gh,
        prDao: _FakePullRequestDao(),
        sessionDao: _FakeSessionDao(sessionsByProject: const <String, List<SessionDto>>{}),
        processRunner: _unusedProcessRunner,
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");

      expect(gh.isAvailableCallCount, equals(1));
      expect(gh.isAuthenticatedCallCount, equals(0));
      expect(gh.listOpenPrsCallCount, equals(0));
    });

    test("debounces repeated refreshes for same project", () async {
      final gh = _FakeGhCliService(listOpenPrsResult: const <GhPullRequest>[]);
      final service = PrSyncService(
        ghCli: gh,
        prDao: _FakePullRequestDao(),
        sessionDao: _FakeSessionDao(sessionsByProject: const <String, List<SessionDto>>{}),
        processRunner: _githubRemoteProcessRunner,
        debounceWindow: const Duration(hours: 1),
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => gh.listOpenPrsCallCount == 1);
      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(gh.listOpenPrsCallCount, equals(1));
    });

    test("skips concurrent refresh while one is already active", () async {
      final block = Completer<void>();
      final gh = _FakeGhCliService(
        listOpenPrsResult: const <GhPullRequest>[],
        onListOpenPrs: () => block.future,
      );
      final service = PrSyncService(
        ghCli: gh,
        prDao: _FakePullRequestDao(),
        sessionDao: _FakeSessionDao(sessionsByProject: const <String, List<SessionDto>>{}),
        processRunner: _githubRemoteProcessRunner,
        debounceWindow: Duration.zero,
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => gh.listOpenPrsCallCount == 1);
      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(gh.listOpenPrsCallCount, equals(1));

      block.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final timeout = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(timeout)) {
      fail("Timed out waiting for condition");
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<ProcessResult> _githubRemoteProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  return ProcessResult(1, 0, "https://github.com/org/repo.git", "");
}

Future<ProcessResult> _unusedProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError("process runner should not be called");
}

SessionDto _session({required String sessionId, required String projectId, required String branchName}) {
  return SessionDto(
    sessionId: sessionId,
    projectId: projectId,
    worktreePath: null,
    branchName: branchName,
    isDedicated: true,
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
    createdAt: 1,
  );
}

PullRequestDto _prData({
  required String projectId,
  required String branchName,
  required int prNumber,
  required String title,
  required String state,
  required String mergeableStatus,
  required String reviewDecision,
  required String checkStatus,
}) {
  return PullRequestDto(
    projectId: projectId,
    prNumber: prNumber,
    branchName: branchName,
    url: "https://github.com/org/repo/pull/$prNumber",
    title: title,
    state: state,
    mergeableStatus: mergeableStatus,
    reviewDecision: reviewDecision,
    checkStatus: checkStatus,
    lastCheckedAt: 1,
    createdAt: 1,
  );
}

class _FakeGhCliService extends GhCliService {
  final List<GhPullRequest> listOpenPrsResult;
  final Map<int, GhPullRequest> prByNumber;
  final Future<void> Function()? onListOpenPrs;
  final bool isAvailableResult;

  int isAvailableCallCount = 0;
  int isAuthenticatedCallCount = 0;
  int listOpenPrsCallCount = 0;
  final List<int> getPrByNumberCalls = <int>[];

  _FakeGhCliService({
    required this.listOpenPrsResult,
    this.prByNumber = const <int, GhPullRequest>{},
    this.onListOpenPrs,
    this.isAvailableResult = true,
  }) : super();

  @override
  Future<bool> isAvailable() async {
    isAvailableCallCount++;
    return isAvailableResult;
  }

  @override
  Future<bool> isAuthenticated() async {
    isAuthenticatedCallCount++;
    return true;
  }

  @override
  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async {
    listOpenPrsCallCount++;
    if (onListOpenPrs case final callback?) {
      await callback();
    }
    return listOpenPrsResult;
  }

  @override
  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory}) async {
    getPrByNumberCalls.add(number);
    final pr = prByNumber[number];
    if (pr == null) {
      throw Exception("PR #$number not found");
    }
    return pr;
  }
}

class _FakeSessionDao implements SessionDaoLike {
  final Map<String, List<SessionDto>> sessionsByProject;

  _FakeSessionDao({required this.sessionsByProject});

  @override
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds}) async {
    final result = <String, SessionDto>{};
    for (final sessions in sessionsByProject.values) {
      for (final session in sessions) {
        if (sessionIds.contains(session.sessionId)) {
          result[session.sessionId] = session;
        }
      }
    }
    return result;
  }

  @override
  Future<List<SessionDto>> getSessionsByProject({required String projectId}) async {
    return sessionsByProject[projectId] ?? const <SessionDto>[];
  }
}

class _FakePullRequestDao extends PullRequestDao {
  final Map<String, PullRequestDto> _byPrimaryKey = <String, PullRequestDto>{};
  int upsertCalls = 0;

  _FakePullRequestDao({List<PullRequestDto> seed = const <PullRequestDto>[]}) : super(createTestDatabase()) {
    for (final pr in seed) {
      _byPrimaryKey[_key(projectId: pr.projectId, prNumber: pr.prNumber)] = pr;
    }
  }

  @override
  Future<void> upsertPr({
    required String projectId,
    required String branchName,
    required int prNumber,
    required String url,
    required String title,
    required String state,
    required String mergeableStatus,
    required String reviewDecision,
    required String checkStatus,
    required int lastCheckedAt,
    required int createdAt,
  }) async {
    upsertCalls++;
    _byPrimaryKey[_key(projectId: projectId, prNumber: prNumber)] = PullRequestDto(
      projectId: projectId,
      prNumber: prNumber,
      branchName: branchName,
      url: url,
      title: title,
      state: state,
      mergeableStatus: mergeableStatus,
      reviewDecision: reviewDecision,
      checkStatus: checkStatus,
      lastCheckedAt: lastCheckedAt,
      createdAt: createdAt,
    );
  }

  @override
  Future<List<PullRequestDto>> getPrsByProjectId({required String projectId}) async {
    return _byPrimaryKey.values.where((PullRequestDto pr) => pr.projectId == projectId).toList();
  }

  @override
  Future<Map<String, PullRequestDto>> getPrsBySessionIds({required List<String> sessionIds}) async {
    return const <String, PullRequestDto>{};
  }

  @override
  Future<List<PullRequestDto>> getActivePrsByProjectId({required String projectId}) async {
    return _byPrimaryKey.values
        .where((PullRequestDto pr) => pr.projectId == projectId && pr.state.toUpperCase() == "OPEN")
        .toList();
  }

  @override
  Future<void> deletePr({required String projectId, required int prNumber}) async {
    _byPrimaryKey.remove(_key(projectId: projectId, prNumber: prNumber));
  }

  String _key({required String projectId, required int prNumber}) {
    return "$projectId::$prNumber";
  }
}
