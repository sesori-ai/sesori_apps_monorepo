import "dart:async";

import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/pr_sync_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PrSyncService", () {
    test("emits project id when a new matched PR is found", () async {
      final prSource = _FakePrSource(
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
        prSource: prSource,
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
      final prSource = _FakePrSource(
        listOpenPrsResult: <GhPullRequest>[
          _ghPr(
            number: 33,
            branch: "feature/no-change",
            title: "No changes",
            reviewDecision: PrReviewDecision.approved,
          ),
        ],
      );
      final pullRequestRepository = _FakePullRequestRepository(
        seed: <PullRequestDto>[
          _dto(
            projectId: "project-1",
            branchName: "feature/no-change",
            prNumber: 33,
            title: "No changes",
            state: PrState.open,
            mergeableStatus: PrMergeableStatus.mergeable,
            reviewDecision: PrReviewDecision.approved,
            checkStatus: PrCheckStatus.success,
          ),
        ],
      );
      final sessionRepository = _FakeSessionRepository(
        sessionsByProject: <String, List<StoredSession>>{
          "project-1": const <StoredSession>[StoredSession(id: "session-1", branchName: "feature/no-change")],
        },
      );
      final service = PrSyncService(
        prSource: prSource,
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
      final prSource = _FakePrSource(
        listOpenPrsResult: <GhPullRequest>[],
        prByNumber: <int, GhPullRequest>{
          22: _ghPr(number: 22, branch: "feature/merged", title: "Merged PR", state: PrState.merged),
        },
      );
      final pullRequestRepository = _FakePullRequestRepository(
        seed: <PullRequestDto>[
          _dto(
            projectId: "project-1",
            branchName: "feature/merged",
            prNumber: 22,
            title: "Merged PR",
            state: PrState.open,
            mergeableStatus: PrMergeableStatus.mergeable,
            reviewDecision: PrReviewDecision.unknown,
            checkStatus: PrCheckStatus.pending,
          ),
        ],
      );
      final sessionRepository = _FakeSessionRepository(
        sessionsByProject: <String, List<StoredSession>>{
          "project-1": const <StoredSession>[StoredSession(id: "session-1", branchName: "feature/merged")],
        },
      );
      final service = PrSyncService(
        prSource: prSource,
        pullRequestRepository: pullRequestRepository,
        sessionRepository: sessionRepository,
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => pullRequestRepository.upsertCalls == 1);

      final prs = pullRequestRepository.getByProjectId(projectId: "project-1");
      expect(prs.single.state, equals(PrState.merged));
      expect(prSource.getPrByNumberCalls, contains(22));
    });

    test("re-checks gh availability and skips refresh when unavailable", () async {
      final prSource = _FakePrSource(
        listOpenPrsResult: <GhPullRequest>[],
        isAvailableResult: false,
      );
      final service = PrSyncService(
        prSource: prSource,
        pullRequestRepository: _FakePullRequestRepository(),
        sessionRepository: _FakeSessionRepository(sessionsByProject: const <String, List<StoredSession>>{}),
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");

      expect(prSource.isAvailableCallCount, equals(2));
      expect(prSource.isAuthenticatedCallCount, equals(0));
      expect(prSource.listOpenPrsCallCount, equals(0));
    });

    test("debounces repeated refreshes for same project", () async {
      final prSource = _FakePrSource(listOpenPrsResult: <GhPullRequest>[]);
      final service = PrSyncService(
        prSource: prSource,
        pullRequestRepository: _FakePullRequestRepository(),
        sessionRepository: _FakeSessionRepository(sessionsByProject: const <String, List<StoredSession>>{}),
        debounceWindow: const Duration(hours: 1),
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prSource.listOpenPrsCallCount == 1);
      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(prSource.listOpenPrsCallCount, equals(1));
    });

    test("skips concurrent refresh while one is already active", () async {
      final block = Completer<void>();
      final prSource = _FakePrSource(
        listOpenPrsResult: <GhPullRequest>[],
        onListOpenPrs: () => block.future,
      );
      final service = PrSyncService(
        prSource: prSource,
        pullRequestRepository: _FakePullRequestRepository(),
        sessionRepository: _FakeSessionRepository(sessionsByProject: const <String, List<StoredSession>>{}),
        debounceWindow: Duration.zero,
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");
      await _waitFor(() => prSource.listOpenPrsCallCount == 1);
      await service.triggerRefresh(projectId: "project-1", projectPath: "/tmp/project-1");

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(prSource.listOpenPrsCallCount, equals(1));

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
  PrState state = PrState.open,
  PrMergeableStatus mergeable = PrMergeableStatus.mergeable,
  PrReviewDecision? reviewDecision,
  PrCheckStatus statusCheckRollup = PrCheckStatus.success,
}) {
  return GhPullRequest(
    number: number,
    url: "https://github.com/org/repo/pull/$number",
    title: title,
    state: state,
    headRefName: branch,
    mergeable: mergeable,
    reviewDecision: reviewDecision ?? PrReviewDecision.unknown,
    statusCheckRollup: statusCheckRollup,
  );
}

PullRequestDto _dto({
  required String projectId,
  required String branchName,
  required int prNumber,
  required String title,
  required PrState state,
  required PrMergeableStatus mergeableStatus,
  required PrReviewDecision reviewDecision,
  required PrCheckStatus checkStatus,
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

class _FakePrSource implements PrSourceRepository {
  final List<GhPullRequest> listOpenPrsResult;
  final Map<int, GhPullRequest> prByNumber;
  final Future<void> Function()? onListOpenPrs;
  final bool isAvailableResult;

  int isAvailableCallCount = 0;
  int isAuthenticatedCallCount = 0;
  int listOpenPrsCallCount = 0;
  final List<int> getPrByNumberCalls = <int>[];

  _FakePrSource({
    required this.listOpenPrsResult,
    this.prByNumber = const <int, GhPullRequest>{},
    this.onListOpenPrs,
    this.isAvailableResult = true,
  });

  @override
  Future<bool> isGithubCliAvailable() async {
    isAvailableCallCount++;
    return isAvailableResult;
  }

  @override
  Future<bool> isGithubCliAuthenticated() async {
    isAuthenticatedCallCount++;
    return true;
  }

  @override
  Future<bool> hasGitHubRemote({required String projectPath}) async => true;

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

class _FakePullRequestRepository implements PullRequestRepository {
  final Map<String, List<PullRequestDto>> _recordsByProject = <String, List<PullRequestDto>>{};
  int upsertCalls = 0;

  _FakePullRequestRepository({List<PullRequestDto> seed = const <PullRequestDto>[]}) {
    for (final record in seed) {
      _recordsByProject.putIfAbsent(record.projectId, () => <PullRequestDto>[]).add(record);
    }
  }

  @override
  Future<List<PullRequestDto>> getActivePullRequestsByProjectId({required String projectId}) async {
    return List<PullRequestDto>.from(_recordsByProject[projectId] ?? const <PullRequestDto>[]);
  }

  @override
  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({required List<String> sessionIds}) async {
    return <String, List<PullRequestDto>>{};
  }

  @override
  bool hasChangedFromExisting({required PullRequestDto? existing, required GhPullRequest pr}) {
    if (existing == null) return true;
    return existing.prNumber != pr.number ||
        existing.url != pr.url ||
        existing.title != pr.title ||
        existing.branchName != pr.headRefName ||
        existing.state != pr.state ||
        existing.mergeableStatus != pr.mergeable ||
        existing.reviewDecision != pr.reviewDecision ||
        existing.checkStatus != pr.statusCheckRollup;
  }

  @override
  Future<void> upsertFromGhPr({
    required String projectId,
    required GhPullRequest pr,
    required int createdAt,
    required int lastCheckedAt,
  }) async {
    await upsertPullRequest(
      record: PullRequestDto(
        projectId: projectId,
        prNumber: pr.number,
        branchName: pr.headRefName,
        url: pr.url,
        title: pr.title,
        state: pr.state,
        mergeableStatus: pr.mergeable,
        reviewDecision: pr.reviewDecision,
        checkStatus: pr.statusCheckRollup,
        lastCheckedAt: lastCheckedAt,
        createdAt: createdAt,
      ),
    );
  }

  @override
  Future<void> upsertPullRequest({required PullRequestDto record}) async {
    upsertCalls++;
    final records = _recordsByProject.putIfAbsent(record.projectId, () => <PullRequestDto>[]);
    final existingIndex = records.indexWhere(
      (existing) => existing.projectId == record.projectId && existing.prNumber == record.prNumber,
    );
    if (existingIndex == -1) {
      records.add(record);
    } else {
      records[existingIndex] = record;
    }
  }

  List<PullRequestDto> getByProjectId({required String projectId}) {
    return List<PullRequestDto>.from(_recordsByProject[projectId] ?? const <PullRequestDto>[]);
  }

  @override
  Future<void> deletePr({required String projectId, required int prNumber}) async {
    final records = _recordsByProject[projectId];
    if (records != null) {
      records.removeWhere((r) => r.prNumber == prNumber);
    }
    upsertCalls++;
  }
}

class _FakeSessionRepository implements SessionRepository {
  final Map<String, List<StoredSession>> sessionsByProject;

  _FakeSessionRepository({required this.sessionsByProject});

  @override
  Future<Session> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async => const Session(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
    pullRequest: null,
  );

  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async => const <Session>[];

  @override
  Future<Session> enrichSession({required Session session}) async => session;

  @override
  Future<Session> enrichPluginSession({required PluginSession pluginSession}) async =>
      Session.fromJson(pluginSession.toJson());

  @override
  Future<Session> enrichSessionJson({required Map<String, dynamic> sessionJson}) async => Session.fromJson(sessionJson);

  @override
  Future<List<Session>> enrichSessions({required List<Session> sessions}) async => sessions;

  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async => const <Session>[];

  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    return sessionsByProject[projectId] ?? const <StoredSession>[];
  }

  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async => false;

  @override
  Future<String?> getProjectPath({required String projectId}) async => null;

  @override
  Future<SessionDto?> getStoredSession({required String sessionId}) async => null;

  @override
  Future<String?> findProjectIdForSession({required String sessionId}) async => null;

  @override
  Future<Session?> getSessionForProject({required String projectId, required String sessionId}) async => null;

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<void> notifySessionArchived({required String sessionId}) async {}

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<CommandListResponse> getCommands({required String? projectId}) async => const CommandListResponse(items: []);

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<Session> renameSession({required String sessionId, required String title}) async => const Session(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
    pullRequest: null,
  );
}
