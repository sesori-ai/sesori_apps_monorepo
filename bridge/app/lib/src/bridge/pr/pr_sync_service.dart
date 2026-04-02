import "dart:async";

import "../persistence/database.dart";
import "../persistence/tables/session_table.dart";
import "../routing/get_sessions_handler.dart";
import "gh_cli_service.dart";
import "gh_pull_request.dart";

class PrSyncService {
  final GhCliService _ghCli;
  final PullRequestDaoLike _prDao;
  final SessionDaoLike _sessionDao;
  final void Function(String projectId) _onPrDataChanged;
  final Duration _debounceWindow;

  final Map<String, DateTime> _lastRefreshTimes = <String, DateTime>{};
  final Set<String> _activeRefreshes = <String>{};

  PrSyncService({
    required GhCliService ghCli,
    required PullRequestDaoLike prDao,
    required SessionDaoLike sessionDao,
    required void Function(String projectId) onPrDataChanged,
    Duration debounceWindow = const Duration(seconds: 30),
  }) : _ghCli = ghCli,
       _prDao = prDao,
       _sessionDao = sessionDao,
       _onPrDataChanged = onPrDataChanged,
       _debounceWindow = debounceWindow;

  void triggerRefreshForProject({required String projectId, required String projectPath}) {
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
      final openPrs = await _ghCli.listOpenPrs(workingDirectory: projectPath);
      final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
      final activePrs = await _prDao.getActivePrsByProjectId(projectId: projectId);

      final sessionsByBranch = _indexSessionsByBranch(sessions: sessions);
      final activeByBranch = <String, PullRequestsTableData>{
        for (final activePr in activePrs) activePr.branchName: activePr,
      };

      var hasChanges = false;
      final nowEpochMs = DateTime.now().millisecondsSinceEpoch;

      final matchedOpenPrs = openPrs
          .where((GhPullRequest pr) => sessionsByBranch.containsKey(pr.headRefName))
          .toList(growable: false);

      for (final pr in matchedOpenPrs) {
        final session = sessionsByBranch[pr.headRefName];
        final existing = activeByBranch[pr.headRefName];
        final createdAt = existing?.createdAt ?? nowEpochMs;

        if (_isMeaningfullyDifferent(existing: existing, pr: pr, sessionId: session?.sessionId)) {
          hasChanges = true;
        }

        await _prDao.upsertPr(
          projectId: projectId,
          branchName: pr.headRefName,
          prNumber: pr.number,
          url: pr.url,
          title: pr.title,
          state: pr.state,
          mergeableStatus: pr.mergeable,
          reviewDecision: pr.reviewDecision,
          checkStatus: pr.statusCheckRollup,
          sessionId: session?.sessionId,
          lastCheckedAt: nowEpochMs,
          createdAt: createdAt,
        );
      }

      final openPrNumbers = openPrs.map((GhPullRequest pr) => pr.number).toSet();
      final disappearedActivePrs = activePrs
          .where((PullRequestsTableData activePr) => !openPrNumbers.contains(activePr.prNumber))
          .toList(growable: false);

      for (final disappeared in disappearedActivePrs) {
        final finalPr = await _ghCli.getPrByNumber(
          number: disappeared.prNumber,
          workingDirectory: projectPath,
        );
        if (finalPr == null) {
          continue;
        }

        final session = sessionsByBranch[finalPr.headRefName];
        if (_isMeaningfullyDifferent(existing: disappeared, pr: finalPr, sessionId: session?.sessionId)) {
          hasChanges = true;
        }

        await _prDao.upsertPr(
          projectId: projectId,
          branchName: finalPr.headRefName,
          prNumber: finalPr.number,
          url: finalPr.url,
          title: finalPr.title,
          state: finalPr.state,
          mergeableStatus: finalPr.mergeable,
          reviewDecision: finalPr.reviewDecision,
          checkStatus: finalPr.statusCheckRollup,
          sessionId: session?.sessionId,
          lastCheckedAt: nowEpochMs,
          createdAt: disappeared.createdAt,
        );
      }

      if (hasChanges) {
        _onPrDataChanged(projectId);
      }
    } catch (_) {
      // Ignore errors; next trigger attempts refresh again.
    } finally {
      _activeRefreshes.remove(projectId);
    }
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
    required PullRequestsTableData? existing,
    required GhPullRequest pr,
    required String? sessionId,
  }) {
    if (existing == null) {
      return true;
    }

    return existing.prNumber != pr.number ||
        existing.url != pr.url ||
        existing.title != pr.title ||
        existing.state != pr.state ||
        existing.mergeableStatus != pr.mergeable ||
        existing.reviewDecision != pr.reviewDecision ||
        existing.checkStatus != pr.statusCheckRollup ||
        existing.sessionId != sessionId;
  }
}
