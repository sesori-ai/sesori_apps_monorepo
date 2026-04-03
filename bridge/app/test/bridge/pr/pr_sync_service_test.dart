import "dart:async";

import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/persistence/dao_interfaces.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/pr/gh_cli_service.dart";
import "package:sesori_bridge/src/bridge/pr/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/pr/pr_sync_service.dart";
import "package:test/test.dart";

void main() {
  group("PrSyncService", () {
    test("calls callback when new matched PR is found", () async {
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
      var callbackCount = 0;

      final service = PrSyncService(
        ghCli: gh,
        prDao: prDao,
        sessionDao: sessionDao,
        onPrDataChanged: (String _) => callbackCount++,
        debounceWindow: const Duration(milliseconds: 1),
      );

      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prDao.upsertCalls == 1);

      final prs = await prDao.getPrsByProjectId(projectId: "project-1");
      expect(prs, hasLength(1));
      expect(prs.single.prNumber, equals(11));
      expect(prs.single.sessionId, equals("session-1"));
      expect(callbackCount, equals(1));
    });

    test("calls callback when PR metadata changes", () async {
      final gh = _FakeGhCliService(
        listOpenPrsResult: const <GhPullRequest>[
          GhPullRequest(
            number: 11,
            url: "https://github.com/org/repo/pull/11",
            title: "Updated PR title",
            state: "OPEN",
            headRefName: "feature/updated",
            mergeable: "MERGEABLE",
            reviewDecision: "APPROVED",
            statusCheckRollup: "SUCCESS",
          ),
        ],
      );
      final prDao = _FakePullRequestDao(
        seed: <PullRequestsTableData>[
          _prData(
            projectId: "project-1",
            branchName: "feature/updated",
            prNumber: 11,
            title: "Old title",
            state: "OPEN",
            sessionId: "session-1",
            mergeableStatus: "MERGEABLE",
            reviewDecision: null,
            checkStatus: "SUCCESS",
          ),
        ],
      );
      final sessionDao = _FakeSessionDao(
        sessionsByProject: <String, List<SessionDto>>{
          "project-1": <SessionDto>[
            _session(sessionId: "session-1", projectId: "project-1", branchName: "feature/updated"),
          ],
        },
      );
      var callbackCount = 0;

      final service = PrSyncService(
        ghCli: gh,
        prDao: prDao,
        sessionDao: sessionDao,
        onPrDataChanged: (String _) => callbackCount++,
      );

      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prDao.upsertCalls == 1);

      final prs = await prDao.getPrsByProjectId(projectId: "project-1");
      expect(prs.single.title, equals("Updated PR title"));
      expect(prs.single.reviewDecision, equals("APPROVED"));
      expect(callbackCount, equals(1));
    });

    test("calls callback when active PR disappears and final state is fetched", () async {
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
        seed: <PullRequestsTableData>[
          _prData(
            projectId: "project-1",
            branchName: "feature/merged",
            prNumber: 22,
            title: "Merged PR",
            state: "OPEN",
            sessionId: "session-1",
            mergeableStatus: "MERGEABLE",
            reviewDecision: null,
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
      var callbackCount = 0;

      final service = PrSyncService(
        ghCli: gh,
        prDao: prDao,
        sessionDao: sessionDao,
        onPrDataChanged: (String _) => callbackCount++,
      );

      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prDao.upsertCalls == 1);

      final prs = await prDao.getPrsByProjectId(projectId: "project-1");
      expect(prs.single.state, equals("MERGED"));
      expect(gh.getPrByNumberCalls, contains(22));
      expect(callbackCount, equals(1));
    });

    test("does not call callback when no data changed", () async {
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
        seed: <PullRequestsTableData>[
          _prData(
            projectId: "project-1",
            branchName: "feature/no-change",
            prNumber: 33,
            title: "No changes",
            state: "OPEN",
            sessionId: "session-1",
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
      var callbackCount = 0;

      final service = PrSyncService(
        ghCli: gh,
        prDao: prDao,
        sessionDao: sessionDao,
        onPrDataChanged: (String _) => callbackCount++,
      );

      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prDao.upsertCalls == 1);

      expect(callbackCount, equals(0));
    });

    test("debounces repeated refreshes for same project", () async {
      final gh = _FakeGhCliService(listOpenPrsResult: const <GhPullRequest>[]);
      final service = PrSyncService(
        ghCli: gh,
        prDao: _FakePullRequestDao(),
        sessionDao: _FakeSessionDao(sessionsByProject: const <String, List<SessionDto>>{}),
        onPrDataChanged: (String _) {},
        debounceWindow: const Duration(hours: 1),
      );

      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => gh.listOpenPrsCallCount == 1);
      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");

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
        onPrDataChanged: (String _) {},
        debounceWindow: Duration.zero,
      );

      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => gh.listOpenPrsCallCount == 1);
      service.triggerRefreshForProject(projectId: "project-1", projectPath: "/tmp/project-1");

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

PullRequestsTableData _prData({
  required String projectId,
  required String branchName,
  required int prNumber,
  required String title,
  required String state,
  required String? sessionId,
  required String? mergeableStatus,
  required String? reviewDecision,
  required String? checkStatus,
}) {
  return PullRequestsTableData(
    projectId: projectId,
    branchName: branchName,
    prNumber: prNumber,
    url: "https://github.com/org/repo/pull/$prNumber",
    title: title,
    state: state,
    mergeableStatus: mergeableStatus,
    reviewDecision: reviewDecision,
    checkStatus: checkStatus,
    sessionId: sessionId,
    lastCheckedAt: 1,
    createdAt: 1,
  );
}

class _FakeGhCliService extends GhCliService {
  final List<GhPullRequest> listOpenPrsResult;
  final Map<int, GhPullRequest> prByNumber;
  final Future<void> Function()? onListOpenPrs;
  int listOpenPrsCallCount = 0;
  final List<int> getPrByNumberCalls = <int>[];

  _FakeGhCliService({
    required this.listOpenPrsResult,
    this.prByNumber = const <int, GhPullRequest>{},
    this.onListOpenPrs,
  }) : super();

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

class _FakePullRequestDao implements PullRequestDaoLike {
  final Map<String, PullRequestsTableData> _byCompositeKey = <String, PullRequestsTableData>{};
  int upsertCalls = 0;

  _FakePullRequestDao({List<PullRequestsTableData> seed = const <PullRequestsTableData>[]}) {
    for (final pr in seed) {
      _byCompositeKey[_key(projectId: pr.projectId, branchName: pr.branchName)] = pr;
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
    required String? mergeableStatus,
    required String? reviewDecision,
    required String? checkStatus,
    required String? sessionId,
    required int lastCheckedAt,
    required int createdAt,
  }) async {
    upsertCalls++;
    _byCompositeKey[_key(projectId: projectId, branchName: branchName)] = PullRequestsTableData(
      projectId: projectId,
      branchName: branchName,
      prNumber: prNumber,
      url: url,
      title: title,
      state: state,
      mergeableStatus: mergeableStatus,
      reviewDecision: reviewDecision,
      checkStatus: checkStatus,
      sessionId: sessionId,
      lastCheckedAt: lastCheckedAt,
      createdAt: createdAt,
    );
  }

  @override
  Future<List<PullRequestsTableData>> getPrsByProjectId({required String projectId}) async {
    return _byCompositeKey.values.where((PullRequestsTableData pr) => pr.projectId == projectId).toList();
  }

  @override
  Future<Map<String, PullRequestsTableData>> getPrsBySessionIds({required List<String> sessionIds}) async {
    return <String, PullRequestsTableData>{
      for (final pr in _byCompositeKey.values)
        if (pr.sessionId != null && sessionIds.contains(pr.sessionId)) pr.sessionId!: pr,
    };
  }

  @override
  Future<List<PullRequestsTableData>> getActivePrsByProjectId({required String projectId}) async {
    return _byCompositeKey.values
        .where((PullRequestsTableData pr) => pr.projectId == projectId && pr.state.toUpperCase() == "OPEN")
        .toList();
  }

  @override
  Future<void> deletePr({required String projectId, required String branchName}) async {
    _byCompositeKey.remove(_key(projectId: projectId, branchName: branchName));
  }

  String _key({required String projectId, required String branchName}) {
    return "$projectId::$branchName";
  }
}
