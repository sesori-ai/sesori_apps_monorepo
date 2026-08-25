import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_target.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/repositories/session_metadata_repository.dart";

class FakeSessionMetadataRepository() implements SessionMetadataRepository {
  String? generateResult = "Generated title";
  String generatedBranchName = "generated-branch";
  String? lastGenerateMessage;

  @override
  void beginShutdown() {}

  @override
  Future<GeneratedSessionMetadata> generateMetadata({required String firstMessage}) async {
    lastGenerateMessage = firstMessage;
    return (
      title: generateResult ?? (throw StateError("metadata unavailable")),
      branchName: generatedBranchName,
    );
  }
}

class FakePullRequestRepository() implements PullRequestRepository {
  final Map<String, List<PullRequestDto>> _prsBySessionId = <String, List<PullRequestDto>>{};
  final Map<String, PullRequestDto> _prsByPrimaryKey = <String, PullRequestDto>{};

  void setPr({required String sessionId, required PullRequestDto pullRequest}) {
    _prsBySessionId.putIfAbsent(sessionId, () => <PullRequestDto>[]).add(pullRequest);
    _prsByPrimaryKey[_key(
          projectId: pullRequest.projectId,
          githubRepositoryIdentity: pullRequest.githubRepositoryIdentity,
          prNumber: pullRequest.prNumber,
        )] =
        pullRequest;
  }

  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({
    required List<String> sessionIds,
    required VerifiedGithubLogin verifiedGithubLogin,
  }) async {
    return <String, List<PullRequestDto>>{
      for (final sessionId in sessionIds)
        if (_prsBySessionId[sessionId]?.where((pr) => pr.githubLogin == verifiedGithubLogin.login).toList()
            case final matching? when matching.isNotEmpty)
          sessionId: matching,
    };
  }

  @override
  Future<PullRequestReplacementOutcome> replaceScopedPullRequests({
    required String projectId,
    required VerifiedGithubLogin verifiedGithubLogin,
    required Map<String, String> capturedRootDirectoriesBySessionId,
    required List<PullRequestTargetSelection> targetSelections,
    required int lastCheckedAt,
  }) async {
    _prsByPrimaryKey.removeWhere((_, pullRequest) => pullRequest.projectId == projectId);
    for (final selection in targetSelections) {
      if (selection is! PullRequestTargetSelected) continue;
      final pullRequest = selection;
      final record = PullRequestDto(
        projectId: projectId,
        githubRepositoryIdentity: pullRequest.target.githubRepositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        prNumber: pullRequest.pullRequest.number,
        branchName: pullRequest.target.branchName,
        url: pullRequest.pullRequest.url,
        title: pullRequest.pullRequest.title,
        state: pullRequest.pullRequest.state,
        mergeableStatus: pullRequest.pullRequest.mergeable,
        reviewDecision: pullRequest.pullRequest.reviewDecision,
        checkStatus: pullRequest.pullRequest.statusCheckRollup,
        lastCheckedAt: lastCheckedAt,
        createdAt: pullRequest.pullRequest.createdAt.millisecondsSinceEpoch,
      );
      _prsByPrimaryKey[_key(
            projectId: record.projectId,
            githubRepositoryIdentity: record.githubRepositoryIdentity,
            prNumber: record.prNumber,
          )] =
          record;
    }
    return const PullRequestReplacementApplied(changed: true);
  }

  String _key({
    required String projectId,
    required String githubRepositoryIdentity,
    required int prNumber,
  }) => "$projectId::$githubRepositoryIdentity::$prNumber";

  @override
  Future<Set<String>> prepareScopedRefresh({
    required Set<String> projectIds,
    required VerifiedGithubLogin verifiedGithubLogin,
  }) async => const <String>{};

  @override
  Future<Set<String>> applyResolvedTargets({
    required Map<String, List<StoredSession>> sessionsByProject,
    required Map<String, PullRequestDirectoryTarget> targetsByDirectory,
  }) async => const <String>{};
}
