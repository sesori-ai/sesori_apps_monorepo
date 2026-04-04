import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/database/tables/pull_requests_table.dart";
import "../api/gh_pull_request.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/pr_source_repository.dart";
import "../repositories/pull_request_repository.dart";
import "../repositories/session_repository.dart";

class PrSyncService {
  final PrSourceRepository _prSource;
  final PullRequestRepository _pullRequestRepository;
  final SessionRepository _sessionRepository;
  final Duration _debounceWindow;
  final StreamController<String> _prChangesController = StreamController<String>.broadcast();

  bool? _ghAvailable;
  bool? _ghAuthenticated;
  final Map<String, bool> _hasGitHubRemoteCache = <String, bool>{};
  final Map<String, DateTime> _lastRefreshTimes = <String, DateTime>{};
  final Set<String> _activeRefreshes = <String>{};

  PrSyncService({
    required PrSourceRepository prSource,
    required PullRequestRepository pullRequestRepository,
    required SessionRepository sessionRepository,
    Duration debounceWindow = const Duration(seconds: 30),
  }) : _prSource = prSource,
       _pullRequestRepository = pullRequestRepository,
       _sessionRepository = sessionRepository,
       _debounceWindow = debounceWindow;

  /// Resets cached auth state so that a later `gh auth login` is picked up.
  void resetAuthCache() {
    _ghAvailable = null;
    _ghAuthenticated = null;
  }

  Stream<String> get prChanges => _prChangesController.stream;

  Future<void> triggerRefresh({required String projectId, required String projectPath}) async {
    _ghAvailable ??= await _prSource.isGithubCliAvailable();
    if (!_ghAvailable!) {
      return;
    }

    _ghAuthenticated ??= await _prSource.isGithubCliAuthenticated();
    if (!_ghAuthenticated!) {
      return;
    }

    if (!_hasGitHubRemoteCache.containsKey(projectPath)) {
      _hasGitHubRemoteCache[projectPath] = await _prSource.hasGitHubRemote(
        projectPath: projectPath,
      );
    }
    if (!_hasGitHubRemoteCache[projectPath]!) {
      return;
    }

    if (_activeRefreshes.contains(projectId)) {
      return;
    }

    final now = DateTime.now();
    final lastRefreshAt = _lastRefreshTimes[projectId];
    if (lastRefreshAt != null && now.difference(lastRefreshAt) < _debounceWindow) {
      return;
    }

    _lastRefreshTimes[projectId] = now;
    _activeRefreshes.add(projectId);
    unawaited(_refresh(projectId: projectId, projectPath: projectPath));
  }

  Future<void> _refresh({required String projectId, required String projectPath}) async {
    try {
      final (openPrs, storedSessions, activePrs) = await (
        _prSource.listOpenPrs(workingDirectory: projectPath),
        _sessionRepository.getStoredSessionsByProjectId(projectId: projectId),
        _pullRequestRepository.getActivePullRequestsByProjectId(projectId: projectId),
      ).wait;

      final sessionsByBranch = _indexSessionsByBranch(sessions: storedSessions);
      final activeByBranch = <String, PullRequestDto>{
        for (final activePr in activePrs) activePr.branchName: activePr,
      };

      var hasChanges = false;
      final nowEpochMs = DateTime.now().millisecondsSinceEpoch;

      final matchedOpenPrs = openPrs
          .where((GhPullRequest pr) => sessionsByBranch.containsKey(pr.headRefName))
          .toList(growable: false);

      for (final pr in matchedOpenPrs) {
        final existing = activeByBranch[pr.headRefName];
        final createdAt = existing?.createdAt ?? nowEpochMs;

        if (_isMeaningfullyDifferent(existing: existing, pr: pr)) {
          hasChanges = true;
        }

        await _pullRequestRepository.upsertPullRequest(
          record: PullRequestDto(
            projectId: projectId,
            branchName: pr.headRefName,
            prNumber: pr.number,
            url: pr.url,
            title: pr.title,
            state: pr.state.name.toUpperCase(),
            mergeableStatus: pr.mergeable.name.toUpperCase(),
            reviewDecision: pr.reviewDecision.name.toUpperCase(),
            checkStatus: pr.statusCheckRollup.name.toUpperCase(),
            lastCheckedAt: nowEpochMs,
            createdAt: createdAt,
          ),
        );
      }

      final openPrNumbers = openPrs.map((GhPullRequest pr) => pr.number).toSet();
      final disappearedActivePrs = activePrs
          .where((PullRequestDto activePr) => !openPrNumbers.contains(activePr.prNumber))
          .toList(growable: false);

      for (final disappeared in disappearedActivePrs) {
        try {
          final finalPr = await _prSource.getPrByNumber(
            number: disappeared.prNumber,
            workingDirectory: projectPath,
          );

          if (_isMeaningfullyDifferent(existing: disappeared, pr: finalPr)) {
            hasChanges = true;
          }

          await _pullRequestRepository.upsertPullRequest(
            record: PullRequestDto(
              projectId: projectId,
              branchName: finalPr.headRefName,
              prNumber: finalPr.number,
              url: finalPr.url,
              title: finalPr.title,
              state: finalPr.state.name.toUpperCase(),
              mergeableStatus: finalPr.mergeable.name.toUpperCase(),
              reviewDecision: finalPr.reviewDecision.name.toUpperCase(),
              checkStatus: finalPr.statusCheckRollup.name.toUpperCase(),
              lastCheckedAt: nowEpochMs,
              createdAt: disappeared.createdAt,
            ),
          );
        } catch (e) {
          Log.w("[PrSync] failed to fetch PR #${disappeared.prNumber}: $e");
          continue;
        }
      }

      if (hasChanges) {
        _prChangesController.add(projectId);
      }
    } catch (e, st) {
      Log.e("[PrSync] refresh failed for $projectId: $e\n$st");
    } finally {
      _activeRefreshes.remove(projectId);
    }
  }

  void dispose() {
    _prChangesController.close();
  }

  Map<String, StoredSession> _indexSessionsByBranch({required List<StoredSession> sessions}) {
    final result = <String, StoredSession>{};
    for (final session in sessions) {
      final branchName = session.branchName;
      if (branchName == null || branchName.isEmpty) {
        continue;
      }
      result[branchName] = session;
    }
    return result;
  }

  bool _isMeaningfullyDifferent({
    required PullRequestDto? existing,
    required GhPullRequest pr,
  }) {
    if (existing == null) {
      return true;
    }

    return existing.prNumber != pr.number ||
        existing.url != pr.url ||
        existing.title != pr.title ||
        existing.state != pr.state.name.toUpperCase() ||
        existing.mergeableStatus != pr.mergeable.name.toUpperCase() ||
        existing.reviewDecision != pr.reviewDecision.name.toUpperCase() ||
        existing.checkStatus != pr.statusCheckRollup.name.toUpperCase();
  }
}
