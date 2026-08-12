import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/pull_request_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/database.dart";
import "../../api/database/tables/pull_requests_table.dart";
import "../../api/database/tables/session_table.dart" show SessionDto;
import "../../repositories/models/pull_request_selection.dart";
import "../../repositories/models/pull_request_target.dart";
import "models/stored_session.dart";
import "models/verified_github_login.dart";

class PullRequestRepository({
  required final AppDatabase _database,
  required final PullRequestDao _pullRequestDao,
  required final ProjectsDao _projectsDao,
  required final SessionDao _sessionDao,
}) {
  Future<Set<String>> applyResolvedTargets({
    required Map<String, List<StoredSession>> sessionsByProject,
    required Map<String, PullRequestDirectoryTarget> targetsByDirectory,
  }) {
    return _database.transaction(() async {
      final changedProjectIds = <String>{};
      final sortedProjectIds = sessionsByProject.keys.toList(growable: false)..sort();
      for (final projectId in sortedProjectIds) {
        final capturedSessions = sessionsByProject[projectId] ?? const <StoredSession>[];
        final sessionIds = capturedSessions.map((session) => session.id).toList(growable: false);
        final currentById = await _sessionDao.getSessionsByIds(sessionIds: sessionIds);
        final before = await _pullRequestDao.getPrsByPersistedScopeSessionIds(sessionIds: sessionIds);
        final updates = <SessionPullRequestScopeUpdate>[];
        var renderedBranchChanged = false;

        for (final captured in capturedSessions) {
          final current = currentById[captured.id];
          if (current == null ||
              current.projectId != captured.projectId ||
              current.parentSessionId != captured.parentSessionId) {
            continue;
          }
          if (current.directory != captured.directory) {
            if (current.currentBranchName != null) {
              renderedBranchChanged = true;
            }
            if (current.currentBranchName != null || current.currentGithubRepositoryIdentity != null) {
              updates.add((
                sessionId: captured.id,
                currentBranchName: null,
                currentGithubRepositoryIdentity: null,
              ));
            }
            continue;
          }

          final ({String? branchName, String? repositoryIdentity}) desiredScope;
          if (captured.parentSessionId != null) {
            desiredScope = (branchName: null, repositoryIdentity: null);
          } else {
            final resolution = targetsByDirectory[captured.directory];
            desiredScope = switch (resolution) {
              PullRequestGithubDirectoryTarget(:final target) => (
                branchName: target.branchName,
                repositoryIdentity: target.githubRepositoryIdentity,
              ),
              PullRequestLocalBranchDirectoryTarget(:final branchName) => (
                branchName: branchName,
                repositoryIdentity: null,
              ),
              PullRequestNoBranchDirectoryTarget() => (branchName: null, repositoryIdentity: null),
              PullRequestRepositoryResolutionFailed(:final branchName) => (
                branchName: branchName,
                repositoryIdentity: null,
              ),
              PullRequestBranchResolutionFailed() || PullRequestBranchChangedDuringResolution() || null => (
                branchName: current.currentBranchName,
                repositoryIdentity: current.currentGithubRepositoryIdentity,
              ),
            };
          }

          if (current.currentBranchName != desiredScope.branchName) {
            renderedBranchChanged = true;
          }
          if (current.currentBranchName != desiredScope.branchName ||
              current.currentGithubRepositoryIdentity != desiredScope.repositoryIdentity) {
            updates.add((
              sessionId: captured.id,
              currentBranchName: desiredScope.branchName,
              currentGithubRepositoryIdentity: desiredScope.repositoryIdentity,
            ));
          }
        }

        await _sessionDao.updatePullRequestScopes(updates: updates);
        final currentSessions = await _sessionDao.getSessionsByProject(projectId: projectId);
        final currentTargets = _currentSelectionTargets(sessions: currentSessions);
        await _pullRequestDao.deletePrsOutsideTargets(
          projectId: projectId,
          targets: currentTargets,
        );
        if (currentTargets.isEmpty) {
          await _projectsDao.setPrCacheGithubLogin(projectId: projectId, githubLogin: null);
        }
        final after = await _pullRequestDao.getPrsByPersistedScopeSessionIds(sessionIds: sessionIds);
        if (renderedBranchChanged || !_sameVisiblePullRequests(before: before, after: after)) {
          changedProjectIds.add(projectId);
        }
      }
      return changedProjectIds;
    });
  }

  Future<Set<String>> prepareScopedRefresh({
    required Set<String> projectIds,
    required VerifiedGithubLogin verifiedGithubLogin,
  }) {
    return _database.transaction(() async {
      final changedProjectIds = <String>{};
      final sortedProjectIds = projectIds.toList(growable: false)..sort();
      for (final projectId in sortedProjectIds) {
        if (await _projectsDao.getProject(projectId: projectId) == null) continue;
        final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
        final sessionIds = sessions.map((session) => session.sessionId).toList(growable: false);
        final before = await _pullRequestDao.getPrsByPersistedScopeSessionIds(sessionIds: sessionIds);
        await _projectsDao.setPrCacheGithubLogin(
          projectId: projectId,
          githubLogin: verifiedGithubLogin.login,
        );
        await _pullRequestDao.deletePrsOutsideTargets(
          projectId: projectId,
          targets: _currentSelectionTargets(sessions: sessions),
        );
        await _pullRequestDao.deletePrsForOtherGithubLogins(
          projectId: projectId,
          githubLogin: verifiedGithubLogin.login,
        );
        final after = await _pullRequestDao.getPrsByPersistedScopeSessionIds(sessionIds: sessionIds);
        if (!_sameVisiblePullRequests(before: before, after: after)) {
          changedProjectIds.add(projectId);
        }
      }
      return changedProjectIds;
    });
  }

  Future<PullRequestReplacementOutcome> replaceScopedPullRequests({
    required String projectId,
    required VerifiedGithubLogin verifiedGithubLogin,
    required Map<String, String> capturedRootDirectoriesBySessionId,
    required List<PullRequestTargetSelection> targetSelections,
    required int lastCheckedAt,
  }) async {
    final targets = targetSelections.map((selection) => selection.target).toSet();
    if (targets.length != targetSelections.length) {
      throw ArgumentError.value(
        targetSelections,
        "targetSelections",
        "Expected exactly one result per pull request target",
      );
    }
    final replacements = [
      for (final selection in targetSelections)
        if (selection case final PullRequestTargetSelected pullRequest)
          PullRequestDto(
            projectId: projectId,
            githubRepositoryIdentity: pullRequest.target.githubRepositoryIdentity,
            githubLogin: verifiedGithubLogin.login,
            branchName: pullRequest.target.branchName,
            prNumber: pullRequest.number,
            url: pullRequest.url,
            title: pullRequest.title,
            state: pullRequest.state,
            mergeableStatus: pullRequest.mergeableStatus,
            reviewDecision: pullRequest.reviewDecision,
            checkStatus: pullRequest.checkStatus,
            lastCheckedAt: lastCheckedAt,
            createdAt: pullRequest.createdAt.millisecondsSinceEpoch,
          ),
    ];
    return await _database.transaction<PullRequestReplacementOutcome>(() async {
      final project = await _projectsDao.getProject(projectId: projectId);
      final currentSessions = await _sessionDao.getSessionsByProject(projectId: projectId);
      if (project?.prCacheGithubLogin != verifiedGithubLogin.login ||
          !_sameRootDirectories(
            first: _rootDirectoriesBySessionId(sessions: currentSessions),
            second: capturedRootDirectoriesBySessionId,
          ) ||
          !_sameTargets(
            first: _currentSelectionTargets(sessions: currentSessions),
            second: targets,
          )) {
        return const PullRequestReplacementScopeChanged();
      }
      final previous = await _pullRequestDao.getPrsByProjectId(projectId: projectId);
      final changed = !_sameSelectedPullRequests(previous: previous, replacements: replacements);
      await _pullRequestDao.deletePrsByProjectId(projectId: projectId);
      for (final replacement in replacements) {
        await _pullRequestDao.upsertPr(pullRequest: replacement);
      }
      return PullRequestReplacementApplied(changed: changed);
    });
  }

  bool _sameVisiblePullRequests({
    required Map<String, List<PullRequestDto>> before,
    required Map<String, List<PullRequestDto>> after,
  }) {
    final beforeKeys = _visiblePullRequestKeys(before);
    final afterKeys = _visiblePullRequestKeys(after);
    return beforeKeys.length == afterKeys.length && beforeKeys.containsAll(afterKeys);
  }

  bool _sameSelectedPullRequests({
    required List<PullRequestDto> previous,
    required List<PullRequestDto> replacements,
  }) {
    if (previous.length != replacements.length) return false;
    final previousByKey = {
      for (final pullRequest in previous) (pullRequest.githubRepositoryIdentity, pullRequest.prNumber): pullRequest,
    };
    for (final replacement in replacements) {
      final existing = previousByKey[(replacement.githubRepositoryIdentity, replacement.prNumber)];
      if (existing == null ||
          existing.githubLogin != replacement.githubLogin ||
          existing.branchName != replacement.branchName ||
          existing.url != replacement.url ||
          existing.title != replacement.title ||
          existing.state != replacement.state ||
          existing.mergeableStatus != replacement.mergeableStatus ||
          existing.reviewDecision != replacement.reviewDecision ||
          existing.checkStatus != replacement.checkStatus ||
          existing.createdAt != replacement.createdAt) {
        return false;
      }
    }
    return true;
  }

  Set<({String sessionId, String repository, String login, int number})> _visiblePullRequestKeys(
    Map<String, List<PullRequestDto>> pullRequestsBySession,
  ) {
    return {
      for (final entry in pullRequestsBySession.entries)
        for (final pullRequest in entry.value)
          (
            sessionId: entry.key,
            repository: pullRequest.githubRepositoryIdentity,
            login: pullRequest.githubLogin,
            number: pullRequest.prNumber,
          ),
    };
  }

  Set<PullRequestSelectionTarget> _currentSelectionTargets({
    required Iterable<SessionDto> sessions,
  }) {
    return {
      for (final session in sessions)
        if (session.parentSessionId == null)
          if ((session.currentGithubRepositoryIdentity, session.currentBranchName)
              case (
                final repositoryIdentity?,
                final branchName?,
              )
              when repositoryIdentity.isNotEmpty && branchName.isNotEmpty)
            (
              githubRepositoryIdentity: repositoryIdentity,
              branchName: branchName,
            ),
    };
  }

  bool _sameTargets({
    required Set<PullRequestSelectionTarget> first,
    required Set<PullRequestSelectionTarget> second,
  }) {
    return first.length == second.length && first.containsAll(second);
  }

  Map<String, String> _rootDirectoriesBySessionId({required Iterable<SessionDto> sessions}) {
    return {
      for (final session in sessions)
        if (session.parentSessionId == null) session.sessionId: session.directory,
    };
  }

  bool _sameRootDirectories({
    required Map<String, String> first,
    required Map<String, String> second,
  }) {
    if (first.length != second.length) return false;
    return first.entries.every((entry) => second[entry.key] == entry.value);
  }
}
