import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../persistence/dao_interfaces.dart";
import "../persistence/daos/pull_request_dao.dart";
import "../persistence/tables/pull_requests_table.dart";
import "../persistence/tables/session_table.dart";
import "../worktree_service.dart";
import "gh_cli_service.dart";
import "gh_pull_request.dart";
import "remote_detection.dart";

class PrSyncService {
  final GhCliService _ghCli;
  final PullRequestDao _prDao;
  final SessionDaoLike _sessionDao;
  final ProcessRunner _processRunner;
  final Duration _debounceWindow;
  final StreamController<String> _prChangesController = StreamController<String>.broadcast();

  bool? _ghAvailable;
  bool? _ghAuthenticated;
  final Map<String, bool> _hasGitHubRemoteCache = <String, bool>{};
  final Map<String, DateTime> _lastRefreshTimes = <String, DateTime>{};
  final Set<String> _activeRefreshes = <String>{};

  PrSyncService({
    required GhCliService ghCli,
    required PullRequestDao prDao,
    required SessionDaoLike sessionDao,
    required ProcessRunner processRunner,
    Duration debounceWindow = const Duration(seconds: 30),
  }) : _ghCli = ghCli,
       _prDao = prDao,
       _sessionDao = sessionDao,
       _processRunner = processRunner,
       _debounceWindow = debounceWindow;

  Stream<String> get prChanges => _prChangesController.stream;

  Future<void> triggerRefresh({required String projectId, required String projectPath}) async {
    _ghAvailable ??= await _ghCli.isAvailable();
    if (!_ghAvailable!) {
      return;
    }

    _ghAuthenticated ??= await _ghCli.isAuthenticated();
    if (!_ghAuthenticated!) {
      return;
    }

    if (!_hasGitHubRemoteCache.containsKey(projectPath)) {
      _hasGitHubRemoteCache[projectPath] = await hasGitHubRemote(
        processRunner: _processRunner,
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
      final (openPrs, sessions, activePrs) = await (
        _ghCli.listOpenPrs(workingDirectory: projectPath),
        _sessionDao.getSessionsByProject(projectId: projectId),
        _prDao.getActivePrsByProjectId(projectId: projectId),
      ).wait;

      final sessionsByBranch = _indexSessionsByBranch(sessions: sessions);
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

        await _prDao.upsertPr(
          projectId: projectId,
          branchName: pr.headRefName,
          prNumber: pr.number,
          url: pr.url,
          title: pr.title,
          state: pr.state,
          mergeableStatus: pr.mergeable ?? "",
          reviewDecision: pr.reviewDecision ?? "",
          checkStatus: pr.statusCheckRollup ?? "",
          lastCheckedAt: nowEpochMs,
          createdAt: createdAt,
        );
      }

      final openPrNumbers = openPrs.map((GhPullRequest pr) => pr.number).toSet();
      final disappearedActivePrs = activePrs
          .where((PullRequestDto activePr) => !openPrNumbers.contains(activePr.prNumber))
          .toList(growable: false);

      for (final disappeared in disappearedActivePrs) {
        try {
          final finalPr = await _ghCli.getPrByNumber(
            number: disappeared.prNumber,
            workingDirectory: projectPath,
          );

          if (_isMeaningfullyDifferent(existing: disappeared, pr: finalPr)) {
            hasChanges = true;
          }

          await _prDao.upsertPr(
            projectId: projectId,
            branchName: finalPr.headRefName,
            prNumber: finalPr.number,
            url: finalPr.url,
            title: finalPr.title,
            state: finalPr.state,
            mergeableStatus: finalPr.mergeable ?? "",
            reviewDecision: finalPr.reviewDecision ?? "",
            checkStatus: finalPr.statusCheckRollup ?? "",
            lastCheckedAt: nowEpochMs,
            createdAt: disappeared.createdAt,
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

  Map<String, SessionDto> _indexSessionsByBranch({required List<SessionDto> sessions}) {
    final result = <String, SessionDto>{};
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
        existing.state != pr.state ||
        existing.mergeableStatus != (pr.mergeable ?? "") ||
        existing.reviewDecision != (pr.reviewDecision ?? "") ||
        existing.checkStatus != (pr.statusCheckRollup ?? "");
  }
}
