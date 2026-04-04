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

  final Map<String, ({bool value, DateTime cachedAt})> _hasGitHubRemoteCache =
      <String, ({bool value, DateTime cachedAt})>{};
  final Map<String, DateTime> _lastRefreshTimes = <String, DateTime>{};
  final Set<String> _activeRefreshes = <String>{};

  static const _remoteCacheTtl = Duration(minutes: 10);

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

    final cached = _hasGitHubRemoteCache[projectPath];
    final cacheCheckTime = DateTime.now();
    if (cached == null || cacheCheckTime.difference(cached.cachedAt) > _remoteCacheTtl) {
      final hasRemote = await _prSource.hasGitHubRemote(projectPath: projectPath);
      _hasGitHubRemoteCache[projectPath] = (value: hasRemote, cachedAt: cacheCheckTime);
    }
    if (_hasGitHubRemoteCache[projectPath] case final cachedRemote?) {
      if (!cachedRemote.value) {
        return;
      }
    }

    if (_activeRefreshes.contains(projectId)) {
      return;
    }

    final now = DateTime.now();
    final lastRefreshAt = _lastRefreshTimes[projectId];
    if (lastRefreshAt != null && now.difference(lastRefreshAt) < _debounceWindow) {
      return;
    }

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
          .where((pr) => !pr.isCrossRepository && sessionsByBranch.containsKey(pr.headRefName))
          .toList(growable: false);

      final activeByBranch = {
        for (final activePr in activePrs) activePr.branchName: activePr,
      };

      for (final pr in matchedOpenPrs) {
        final existing = activeByBranch[pr.headRefName];
        final createdAt = existing?.createdAt ?? nowEpochMs;

        if (_pullRequestRepository.hasChangedFromExisting(existing: existing, pr: pr)) {
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

          if (_pullRequestRepository.hasChangedFromExisting(existing: disappeared, pr: finalPr)) {
            hasChanges = true;
          }

          await _pullRequestRepository.upsertFromGhPr(
            projectId: projectId,
            pr: finalPr,
            createdAt: disappeared.createdAt,
            lastCheckedAt: nowEpochMs,
          );
        } catch (e) {
          Log.w("[PrSync] failed to fetch PR #${disappeared.prNumber}: $e — removing stale record");
          await _pullRequestRepository.deletePr(
            projectId: projectId,
            prNumber: disappeared.prNumber,
          );
          hasChanges = true;
        }
      }

      if (hasChanges) {
        _prChangesController.add(projectId);
      }

      _lastRefreshTimes[projectId] = DateTime.now();
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
