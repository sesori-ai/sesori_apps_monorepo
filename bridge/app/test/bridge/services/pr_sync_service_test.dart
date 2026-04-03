import "dart:async";

import "package:sesori_bridge/src/bridge/api/gh_cli_api.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/api/git_remote_api.dart";
import "package:sesori_bridge/src/bridge/repositories/models/pull_request_record.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/pr_sync_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PrSyncService", () {
    test("emits project id when a new matched PR is found", () async {
      final gh = _FakeGhCliApi(
        listOpenPrsResult: <GhPullRequest>[
          _ghPr(number: 11, branch: "feature/new-pr", title: "New PR"),
        ],
      );
      final pullRequestRepository = _FakePullRequestRepository();
      final sessionRepository = _FakeSessionRepository(
        sessionsByProject: <String, List<StoredSession>>{
          "project-1": const <StoredSession>[StoredSession(id: "session-1", branchName: "feature/new-pr")],
        },
      );
      final service = PrSyncService(
        ghCli: gh,
        gitRemoteApi: _FakeGitRemoteApi(hasRemoteResult: true),
        pullRequestRepository: pullRequestRepository,
        sessionRepository: sessionRepository,
        debounceWindow: const Duration(milliseconds: 1),
      );
      addTearDown(service.dispose);

      final emittedProjectIds = <String>[];
      final sub = service.prChanges.listen(emittedProjectIds.add);
      addTearDown(sub.cancel);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => pullRequestRepository.upsertCalls == 1);

      final prs = pullRequestRepository.getByProjectId(projectId: "project-1");
      expect(prs, hasLength(1));
      expect(prs.single.prNumber, equals(11));
      expect(prs.single.branchName, equals("feature/new-pr"));
      expect(emittedProjectIds, equals(<String>["project-1"]));
    });

    test("does not emit when PR data is unchanged", () async {
      final gh = _FakeGhCliApi(
        listOpenPrsResult: <GhPullRequest>[
          _ghPr(number: 33, branch: "feature/no-change", title: "No changes", reviewDecision: "APPROVED"),
        ],
      );
      final pullRequestRepository = _FakePullRequestRepository(
        seed: <PullRequestRecord>[
          _record(
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
      final sessionRepository = _FakeSessionRepository(
        sessionsByProject: <String, List<StoredSession>>{
          "project-1": const <StoredSession>[StoredSession(id: "session-1", branchName: "feature/no-change")],
        },
      );
      final service = PrSyncService(
        ghCli: gh,
        gitRemoteApi: _FakeGitRemoteApi(hasRemoteResult: true),
        pullRequestRepository: pullRequestRepository,
        sessionRepository: sessionRepository,
      );
      addTearDown(service.dispose);

      final emittedProjectIds = <String>[];
      final sub = service.prChanges.listen(emittedProjectIds.add);
      addTearDown(sub.cancel);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => pullRequestRepository.upsertCalls == 1);

      expect(emittedProjectIds, isEmpty);
    });

    test("fetches final PR state for disappeared active PR", () async {
      final gh = _FakeGhCliApi(
        listOpenPrsResult: <GhPullRequest>[],
        prByNumber: <int, GhPullRequest>{
          22: _ghPr(number: 22, branch: "feature/merged", title: "Merged PR", state: "MERGED"),
        },
      );
      final pullRequestRepository = _FakePullRequestRepository(
        seed: <PullRequestRecord>[
          _record(
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
      final sessionRepository = _FakeSessionRepository(
        sessionsByProject: <String, List<StoredSession>>{
          "project-1": const <StoredSession>[StoredSession(id: "session-1", branchName: "feature/merged")],
        },
      );
      final service = PrSyncService(
        ghCli: gh,
        gitRemoteApi: _FakeGitRemoteApi(hasRemoteResult: true),
        pullRequestRepository: pullRequestRepository,
        sessionRepository: sessionRepository,
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => pullRequestRepository.upsertCalls == 1);

      final prs = pullRequestRepository.getByProjectId(projectId: "project-1");
      expect(prs.single.state, equals("MERGED"));
      expect(gh.getPrByNumberCalls, contains(22));
    });

    test("caches gh availability and skips refresh when unavailable", () async {
      final gh = _FakeGhCliApi(
        listOpenPrsResult: <GhPullRequest>[],
        isAvailableResult: false,
      );
      final service = PrSyncService(
        ghCli: gh,
        gitRemoteApi: _FakeGitRemoteApi(hasRemoteResult: true),
        pullRequestRepository: _FakePullRequestRepository(),
        sessionRepository: _FakeSessionRepository(sessionsByProject: const <String, List<StoredSession>>{}),
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");

      expect(gh.isAvailableCallCount, equals(1));
      expect(gh.isAuthenticatedCallCount, equals(0));
      expect(gh.listOpenPrsCallCount, equals(0));
    });

    test("debounces repeated refreshes for same project", () async {
      final gh = _FakeGhCliApi(listOpenPrsResult: <GhPullRequest>[]);
      final service = PrSyncService(
        ghCli: gh,
        gitRemoteApi: _FakeGitRemoteApi(hasRemoteResult: true),
        pullRequestRepository: _FakePullRequestRepository(),
        sessionRepository: _FakeSessionRepository(sessionsByProject: const <String, List<StoredSession>>{}),
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
      final gh = _FakeGhCliApi(
        listOpenPrsResult: <GhPullRequest>[],
        onListOpenPrs: () => block.future,
      );
      final service = PrSyncService(
        ghCli: gh,
        gitRemoteApi: _FakeGitRemoteApi(hasRemoteResult: true),
        pullRequestRepository: _FakePullRequestRepository(),
        sessionRepository: _FakeSessionRepository(sessionsByProject: const <String, List<StoredSession>>{}),
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

GhPullRequest _ghPr({
  required int number,
  required String branch,
  required String title,
  String state = "OPEN",
  String mergeable = "MERGEABLE",
  String? reviewDecision,
  String statusCheckRollup = "SUCCESS",
}) {
  return GhPullRequest(
    number: number,
    url: "https://github.com/org/repo/pull/$number",
    title: title,
    state: state,
    headRefName: branch,
    mergeable: mergeable,
    reviewDecision: reviewDecision,
    statusCheckRollup: statusCheckRollup,
  );
}

PullRequestRecord _record({
  required String projectId,
  required String branchName,
  required int prNumber,
  required String title,
  required String state,
  required String mergeableStatus,
  required String reviewDecision,
  required String checkStatus,
}) {
  return PullRequestRecord(
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

class _FakeGhCliApi implements GhCliApi {
  final List<GhPullRequest> listOpenPrsResult;
  final Map<int, GhPullRequest> prByNumber;
  final Future<void> Function()? onListOpenPrs;
  final bool isAvailableResult;

  int isAvailableCallCount = 0;
  int isAuthenticatedCallCount = 0;
  int listOpenPrsCallCount = 0;
  final List<int> getPrByNumberCalls = <int>[];

  _FakeGhCliApi({
    required this.listOpenPrsResult,
    this.prByNumber = const <int, GhPullRequest>{},
    this.onListOpenPrs,
    this.isAvailableResult = true,
  });

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

class _FakeGitRemoteApi implements GitRemoteApi {
  final bool hasRemoteResult;
  int callCount = 0;

  _FakeGitRemoteApi({required this.hasRemoteResult});

  @override
  Future<bool> hasGitHubRemote({required String projectPath}) async {
    callCount++;
    return hasRemoteResult;
  }
}

class _FakePullRequestRepository implements PullRequestRepositoryLike {
  final Map<String, List<PullRequestRecord>> _recordsByProject = <String, List<PullRequestRecord>>{};
  int upsertCalls = 0;

  _FakePullRequestRepository({List<PullRequestRecord> seed = const <PullRequestRecord>[]}) {
    for (final record in seed) {
      _recordsByProject.putIfAbsent(record.projectId, () => <PullRequestRecord>[]).add(record);
    }
  }

  @override
  Future<List<PullRequestRecord>> getActivePullRequestsByProjectId({required String projectId}) async {
    return List<PullRequestRecord>.from(_recordsByProject[projectId] ?? const <PullRequestRecord>[]);
  }

  @override
  Future<void> upsertPullRequest({required PullRequestRecord record}) async {
    upsertCalls++;
    final records = _recordsByProject.putIfAbsent(record.projectId, () => <PullRequestRecord>[]);
    final existingIndex = records.indexWhere(
      (existing) => existing.projectId == record.projectId && existing.prNumber == record.prNumber,
    );
    if (existingIndex == -1) {
      records.add(record);
    } else {
      records[existingIndex] = record;
    }
  }

  List<PullRequestRecord> getByProjectId({required String projectId}) {
    return List<PullRequestRecord>.from(_recordsByProject[projectId] ?? const <PullRequestRecord>[]);
  }
}

class _FakeSessionRepository implements SessionRepositoryLike {
  final Map<String, List<StoredSession>> sessionsByProject;

  _FakeSessionRepository({required this.sessionsByProject});

  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    return const <Session>[];
  }

  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async {
    return const <Session>[];
  }

  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    return sessionsByProject[projectId] ?? const <StoredSession>[];
  }

  @override
  Future<String?> getProjectPath({required String projectId}) async {
    return null;
  }
}
