import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

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

  Stream<String> get prChanges => _prChangesController.stream;

  Future<void> triggerRefresh({required String projectId, required String projectPath}) async {
    final ghAvailable = await _prSource.isGithubCliAvailable();
    if (!ghAvailable) {
      return;
    }

    final ghAuthenticated = await _prSource.isGithubCliAuthenticated();
    if (!ghAuthenticated) {
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

      var hasChanges = false;
      final nowEpochMs = DateTime.now().millisecondsSinceEpoch;

      final matchedOpenPrs = openPrs
          .where((pr) => sessionsByBranch.containsKey(pr.headRefName))
          .toList(growable: false);

      for (final pr in matchedOpenPrs) {
        final existing = activePrs.where((activePr) => activePr.branchName == pr.headRefName).firstOrNull;
        final createdAt = existing?.createdAt ?? nowEpochMs;

        if (await _pullRequestRepository.hasChanged(projectId: projectId, prNumber: pr.number, pr: pr)) {
          hasChanges = true;
        }

        await _pullRequestRepository.upsertFromGhPr(
          projectId: projectId,
          pr: pr,
          createdAt: createdAt,
          lastCheckedAt: nowEpochMs,
        );
      }

      final openPrNumbers = openPrs.map((pr) => pr.number).toSet();
      final disappearedActivePrs = activePrs
          .where((activePr) => !openPrNumbers.contains(activePr.prNumber))
          .toList(growable: false);

      for (final disappeared in disappearedActivePrs) {
        try {
          final finalPr = await _prSource.getPrByNumber(
            number: disappeared.prNumber,
            workingDirectory: projectPath,
          );

          if (await _pullRequestRepository.hasChanged(projectId: projectId, prNumber: finalPr.number, pr: finalPr)) {
            hasChanges = true;
          }

          await _pullRequestRepository.upsertFromGhPr(
            projectId: projectId,
            pr: finalPr,
            createdAt: disappeared.createdAt,
            lastCheckedAt: nowEpochMs,
          );
        } catch (e) {
          Log.w("[PrSync] failed to fetch PR #${disappeared.prNumber}: $e");
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
}
