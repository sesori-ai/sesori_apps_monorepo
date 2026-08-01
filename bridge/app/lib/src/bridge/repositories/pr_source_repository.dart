import "../../api/gh_pull_request_batch.dart";
import "../../repositories/models/pull_request_selection.dart";
import "../api/gh_cli_api.dart";
import "../api/gh_pull_request.dart";
import "../api/git_cli_api.dart";
import "mappers/git_remote_identity_parser.dart";
import "models/verified_github_login.dart";

class PrSourceRepository {
  static const GitRemoteIdentityParser _remoteIdentityParser = GitRemoteIdentityParser();

  final GhCliApi _ghCli;
  final GitCliApi _gitCli;

  PrSourceRepository({required GhCliApi ghCli, required GitCliApi gitCli}) : _ghCli = ghCli, _gitCli = gitCli;

  Future<bool> isGithubCliAvailable() => _ghCli.isAvailable();

  Future<bool> isGithubCliAuthenticated() => _ghCli.isAuthenticated();

  Future<VerifiedGithubLogin?> getAuthenticatedIdentity() async {
    final identity = await _ghCli.getAuthenticatedIdentity();
    return VerifiedGithubLogin.tryParse(rawLogin: identity.rawLogin);
  }

  Future<String?> getGithubRepositoryIdentity({required String projectPath}) async {
    final remoteUrl = await _gitCli.getRemoteUrl(projectPath: projectPath);
    if (remoteUrl == null) {
      return null;
    }
    final identity = _remoteIdentityParser.parse(remoteUrl: remoteUrl);
    if (identity == null || identity.host != "github.com") {
      return null;
    }
    final segments = identity.slug.split("/");
    if (segments.length != 2 || segments.any((segment) => segment.isEmpty)) {
      return null;
    }
    return identity.slug.toLowerCase();
  }

  Future<PullRequestSelectionOutcome> selectPullRequests({
    required List<PullRequestSelectionTarget> targets,
    required VerifiedGithubLogin expectedGithubLogin,
  }) async {
    final uniqueTargets = targets.toSet().toList(growable: false)
      ..sort((a, b) {
        final repositoryComparison = a.githubRepositoryIdentity.compareTo(b.githubRepositoryIdentity);
        return repositoryComparison != 0 ? repositoryComparison : a.branchName.compareTo(b.branchName);
      });
    final selections = <PullRequestTargetSelection>[];

    for (final targetChunk in _chunks(
      values: uniqueTargets,
      size: GhCliApi.maxPullRequestTargetsPerQuery,
    )) {
      final apiTargets = [for (final target in targetChunk) _toApiTarget(target: target)];
      final initialResponse = await _ghCli.queryInitialPullRequestPages(targets: apiTargets);
      if (!_viewerMatches(response: initialResponse, expectedGithubLogin: expectedGithubLogin)) {
        return const PullRequestSelectionIdentityChanged();
      }

      final states = <_PullRequestTargetSelection>[];
      for (var index = 0; index < targetChunk.length; index++) {
        final state = _PullRequestTargetSelection(target: targetChunk[index]);
        state.consumeInitial(
          openPage: _requirePage(
            response: initialResponse,
            requestIndex: index,
            stateGroup: GhPullRequestStateGroup.open,
          ),
          terminalPage: _requirePage(
            response: initialResponse,
            requestIndex: index,
            stateGroup: GhPullRequestStateGroup.terminal,
          ),
        );
        states.add(state);
      }

      while (states.any((state) => !state.isComplete)) {
        final pending = states
            .map((state) => state.pendingRequest)
            .whereType<_PendingPullRequestCursor>()
            .toList(growable: false);
        if (pending.isEmpty) {
          throw const FormatException("GitHub pull request pagination did not complete");
        }

        for (final pendingChunk in _chunks(
          values: pending,
          size: GhCliApi.maxPullRequestTargetsPerQuery,
        )) {
          final response = await _ghCli.queryPullRequestCursorPages(
            requests: [for (final request in pendingChunk) request.apiRequest],
          );
          if (!_viewerMatches(response: response, expectedGithubLogin: expectedGithubLogin)) {
            return const PullRequestSelectionIdentityChanged();
          }
          for (var index = 0; index < pendingChunk.length; index++) {
            final request = pendingChunk[index];
            request.state.consumeCursor(
              page: _requirePage(
                response: response,
                requestIndex: index,
                stateGroup: request.stateGroup,
              ),
            );
          }
        }
      }

      for (final state in states) {
        selections.add(state.targetSelection);
      }
    }

    final finalGithubLogin = await getAuthenticatedIdentity();
    if (finalGithubLogin?.login != expectedGithubLogin.login) {
      return const PullRequestSelectionIdentityChanged();
    }
    return PullRequestSelectionCompleted(selections: selections);
  }

  GhPullRequestTarget _toApiTarget({required PullRequestSelectionTarget target}) {
    final segments = target.githubRepositoryIdentity.split("/");
    if (segments.length != 2 || segments.any((segment) => segment.isEmpty)) {
      throw const FormatException("Expected canonical GitHub repository identity");
    }
    return GhPullRequestTarget(
      repositoryOwner: segments[0],
      repositoryName: segments[1],
      branchName: target.branchName,
    );
  }

  GhPullRequestCandidatePage _requirePage({
    required GhPullRequestBatchResponse response,
    required int requestIndex,
    required GhPullRequestStateGroup stateGroup,
  }) {
    final matches = response.pages.where(
      (page) => page.requestIndex == requestIndex && page.stateGroup == stateGroup,
    );
    if (matches.length != 1) {
      throw const FormatException("GitHub pull request query returned an invalid page set");
    }
    return matches.single;
  }

  bool _viewerMatches({
    required GhPullRequestBatchResponse response,
    required VerifiedGithubLogin expectedGithubLogin,
  }) {
    return VerifiedGithubLogin.tryParse(rawLogin: response.viewerLogin)?.login == expectedGithubLogin.login;
  }

  List<List<T>> _chunks<T>({required List<T> values, required int size}) {
    return [
      for (var start = 0; start < values.length; start += size)
        values.sublist(start, start + size < values.length ? start + size : values.length),
    ];
  }
}

final class _PullRequestTargetSelection {
  final PullRequestSelectionTarget target;
  GhPullRequestCandidatePage? _terminalInitialPage;
  final List<GhPullRequest> _eligibleCandidates = <GhPullRequest>[];
  final Map<GhPullRequestStateGroup, Set<String>> _seenCursorsByState = <GhPullRequestStateGroup, Set<String>>{};
  GhPullRequestStateGroup _stateGroup = GhPullRequestStateGroup.open;
  String? _pendingCursor;

  bool isComplete = false;
  GhPullRequest? _selection;

  _PullRequestTargetSelection({required this.target});

  PullRequestTargetSelection get targetSelection {
    final pullRequest = _selection;
    if (pullRequest == null) {
      return PullRequestTargetUnmatched(target: target);
    }
    return PullRequestTargetSelected(
      target: target,
      number: pullRequest.number,
      url: pullRequest.url,
      title: pullRequest.title,
      createdAt: pullRequest.createdAt,
      state: pullRequest.state,
      mergeableStatus: pullRequest.mergeable,
      reviewDecision: pullRequest.reviewDecision,
      checkStatus: pullRequest.statusCheckRollup,
    );
  }

  _PendingPullRequestCursor? get pendingRequest {
    final cursor = _pendingCursor;
    if (isComplete || cursor == null) return null;
    return _PendingPullRequestCursor(
      state: this,
      stateGroup: _stateGroup,
      cursor: cursor,
    );
  }

  void consumeInitial({
    required GhPullRequestCandidatePage openPage,
    required GhPullRequestCandidatePage terminalPage,
  }) {
    _terminalInitialPage = terminalPage;
    _consume(page: openPage);
  }

  void consumeCursor({required GhPullRequestCandidatePage page}) {
    if (isComplete || page.stateGroup != _stateGroup) {
      throw const FormatException("GitHub pull request query returned an unexpected cursor page");
    }
    _consume(page: page);
  }

  void _consume({required GhPullRequestCandidatePage page}) {
    if (page.repositoryIdentity.toLowerCase() != target.githubRepositoryIdentity) {
      throw const FormatException("GitHub pull request query returned a different repository");
    }

    _eligibleCandidates.addAll(
      page.connection.nodes.where(
        (pullRequest) => !pullRequest.isCrossRepository && pullRequest.headRefName == target.branchName,
      ),
    );
    if (_mustContinue(page: page)) {
      final cursor = page.connection.pageInfo.endCursor;
      if (cursor == null || cursor.isEmpty) {
        throw const FormatException("GitHub pull request query omitted a required cursor");
      }
      final seenCursors = _seenCursorsByState.putIfAbsent(_stateGroup, () => <String>{});
      if (!seenCursors.add(cursor)) {
        throw const FormatException("GitHub pull request query returned a repeated cursor");
      }
      _pendingCursor = cursor;
      return;
    }

    _pendingCursor = null;
    if (_eligibleCandidates.isNotEmpty) {
      _selection = _newestCandidate();
      isComplete = true;
      return;
    }

    if (_stateGroup == GhPullRequestStateGroup.open) {
      _stateGroup = GhPullRequestStateGroup.terminal;
      final terminalPage = _terminalInitialPage;
      _terminalInitialPage = null;
      if (terminalPage == null) {
        throw const FormatException("GitHub pull request query omitted terminal candidates");
      }
      _consume(page: terminalPage);
      return;
    }

    isComplete = true;
  }

  bool _mustContinue({required GhPullRequestCandidatePage page}) {
    if (!page.connection.pageInfo.hasNextPage) return false;
    if (_eligibleCandidates.isEmpty || page.connection.nodes.isEmpty) return true;

    final newestEligibleCreatedAt = _newestCandidate().createdAt;
    final oldestPageCreatedAt = page.connection.nodes.last.createdAt;
    return !oldestPageCreatedAt.isBefore(newestEligibleCreatedAt);
  }

  GhPullRequest _newestCandidate() {
    return _eligibleCandidates.reduce((current, candidate) {
      final createdAtComparison = candidate.createdAt.compareTo(current.createdAt);
      if (createdAtComparison != 0) {
        return createdAtComparison > 0 ? candidate : current;
      }
      return candidate.number > current.number ? candidate : current;
    });
  }
}

final class _PendingPullRequestCursor {
  final _PullRequestTargetSelection state;
  final GhPullRequestStateGroup stateGroup;
  final String cursor;

  const _PendingPullRequestCursor({
    required this.state,
    required this.stateGroup,
    required this.cursor,
  });

  GhPullRequestCursorRequest get apiRequest => GhPullRequestCursorRequest(
    target: GhPullRequestTarget(
      repositoryOwner: state.target.githubRepositoryIdentity.split("/")[0],
      repositoryName: state.target.githubRepositoryIdentity.split("/")[1],
      branchName: state.target.branchName,
    ),
    stateGroup: stateGroup,
    cursor: cursor,
  );
}
