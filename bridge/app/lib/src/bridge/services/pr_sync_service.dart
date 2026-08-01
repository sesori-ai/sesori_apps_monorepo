import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console, Log;

import "../repositories/models/stored_session.dart";
import "../repositories/models/verified_github_login.dart";
import "../repositories/pr_source_repository.dart";
import "../repositories/pull_request_repository.dart";
import "../repositories/session_repository.dart";

class PrSyncService {
  final PrSourceRepository _prSource;
  final PullRequestRepository _pullRequestRepository;
  final SessionRepository _sessionRepository;
  final Clock _clock;
  final Duration _debounceWindow;
  final StreamController<String> _prChangesController = StreamController<String>.broadcast();

  final Map<String, DateTime> _lastRefreshTimes = <String, DateTime>{};
  final Set<String> _activeRefreshes = <String>{};
  ({bool capable, DateTime checkedAt})? _githubCliCapabilityCache;
  Future<bool>? _githubCliCapabilityCheck;
  bool _identityVerificationFailureReported = false;

  static const _githubCliCapabilityCacheTtl = Duration(seconds: 30);

  PrSyncService({
    required PrSourceRepository prSource,
    required PullRequestRepository pullRequestRepository,
    required SessionRepository sessionRepository,
    required Clock clock,
    Duration debounceWindow = const Duration(seconds: 30),
  }) : _prSource = prSource,
       _pullRequestRepository = pullRequestRepository,
       _sessionRepository = sessionRepository,
       _clock = clock,
       _debounceWindow = debounceWindow;

  Stream<String> get prChanges => _prChangesController.stream;

  Future<VerifiedGithubLogin?> _verifyGithubIdentity() async {
    try {
      final identity = await _prSource.getAuthenticatedIdentity();
      if (identity == null) {
        _reportIdentityVerificationFailure();
        return null;
      }
      _identityVerificationFailureReported = false;
      return identity;
    } on Object catch (error, stackTrace) {
      _reportIdentityVerificationFailure();
      Log.w(
        "[PrSyncService] Failed to verify the active GitHub identity; PR refresh is skipped",
        error,
        stackTrace,
      );
      return null;
    }
  }

  void _reportIdentityVerificationFailure() {
    if (_identityVerificationFailureReported) return;
    _identityVerificationFailureReported = true;
    Console.warning(
      "GitHub CLI (gh) could not verify the active github.com account. "
      "GitHub pull request and CI status metadata cannot be refreshed until verification succeeds. "
      "Run 'gh auth status --hostname github.com' to check authentication and connectivity.",
    );
  }

  Future<void> triggerRefresh({required String projectId, required String projectPath}) async {
    if (_activeRefreshes.contains(projectId)) {
      return;
    }

    final lastRefreshAt = _lastRefreshTimes[projectId];
    if (lastRefreshAt != null && _clock.now().difference(lastRefreshAt) < _debounceWindow) {
      return;
    }

    // Claim the project before the first async gap so concurrent requests for
    // one project cannot start duplicate preflight or refresh work.
    _activeRefreshes.add(projectId);
    try {
      if (!await _hasGithubCliCapability()) {
        return;
      }

      final githubRepositoryIdentity = await _prSource.getGithubRepositoryIdentity(
        projectPath: projectPath,
      );
      if (githubRepositoryIdentity == null) {
        final scopeChanged = await _pullRequestRepository.clearScopedRefresh(
          projectId: projectId,
          sessions: await _sessionRepository.getStoredSessionsByProjectId(
            projectId: projectId,
          ),
        );
        if (scopeChanged) {
          _prChangesController.add(projectId);
        }
        _lastRefreshTimes[projectId] = _clock.now();
        return;
      }

      final verifiedGithubLogin = await _verifyGithubIdentity();
      if (verifiedGithubLogin == null) {
        return;
      }

      final storedSessions = await _sessionRepository.getStoredSessionsByProjectId(
        projectId: projectId,
      );
      final scopeChanged = await _pullRequestRepository.prepareScopedRefresh(
        projectId: projectId,
        githubRepositoryIdentity: githubRepositoryIdentity,
        verifiedGithubLogin: verifiedGithubLogin,
        sessions: storedSessions,
      );
      if (scopeChanged) {
        _prChangesController.add(projectId);
      }

      await _refresh(
        projectId: projectId,
        projectPath: projectPath,
        githubRepositoryIdentity: githubRepositoryIdentity,
        verifiedGithubLogin: verifiedGithubLogin,
        storedSessions: storedSessions,
      );
    } finally {
      _activeRefreshes.remove(projectId);
    }
  }

  Future<bool> _hasGithubCliCapability() async {
    final inFlight = _githubCliCapabilityCheck;
    if (inFlight != null) return inFlight;

    final cached = _githubCliCapabilityCache;
    if (cached != null && _clock.now().difference(cached.checkedAt) < _githubCliCapabilityCacheTtl) {
      return cached.capable;
    }

    final check = _checkGithubCliCapability();
    _githubCliCapabilityCheck = check;
    try {
      return await check;
    } finally {
      if (identical(_githubCliCapabilityCheck, check)) {
        _githubCliCapabilityCheck = null;
      }
    }
  }

  Future<bool> _checkGithubCliCapability() async {
    final available = await _prSource.isGithubCliAvailable();
    final capable = available && await _prSource.isGithubCliAuthenticated();
    _githubCliCapabilityCache = (capable: capable, checkedAt: _clock.now());
    return capable;
  }

  Future<void> _refresh({
    required String projectId,
    required String projectPath,
    required String githubRepositoryIdentity,
    required VerifiedGithubLogin verifiedGithubLogin,
    required List<StoredSession> storedSessions,
  }) async {
    var hasChanges = false;
    var completed = false;
    try {
      final (openPrs, activePrs) = await (
        _prSource.listOpenPrs(
          workingDirectory: projectPath,
          githubRepositoryIdentity: githubRepositoryIdentity,
        ),
        _pullRequestRepository.getActivePullRequestsByProjectId(
          projectId: projectId,
          githubRepositoryIdentity: githubRepositoryIdentity,
          verifiedGithubLogin: verifiedGithubLogin,
        ),
      ).wait;

      final sessionsByBranch = _indexSessionsByBranch(sessions: storedSessions);

      final nowEpochMs = _clock.now().millisecondsSinceEpoch;

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
          githubRepositoryIdentity: githubRepositoryIdentity,
          verifiedGithubLogin: verifiedGithubLogin,
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
            githubRepositoryIdentity: githubRepositoryIdentity,
          );

          if (_pullRequestRepository.hasChangedFromExisting(existing: disappeared, pr: finalPr)) {
            hasChanges = true;
          }

          await _pullRequestRepository.upsertFromGhPr(
            projectId: projectId,
            githubRepositoryIdentity: githubRepositoryIdentity,
            verifiedGithubLogin: verifiedGithubLogin,
            pr: finalPr,
            createdAt: disappeared.createdAt,
            lastCheckedAt: nowEpochMs,
          );
        } catch (e) {
          Log.w("[PrSync] failed to fetch PR #${disappeared.prNumber}: $e — removing stale record");
          await _pullRequestRepository.deletePr(
            projectId: projectId,
            githubRepositoryIdentity: githubRepositoryIdentity,
            prNumber: disappeared.prNumber,
          );
          hasChanges = true;
        }
      }

      completed = true;
    } catch (e, st) {
      Log.e("[PrSync] refresh failed for $projectId: $e\n$st");
    } finally {
      if (hasChanges) {
        _prChangesController.add(projectId);
      }
      if (completed) {
        _lastRefreshTimes[projectId] = _clock.now();
      }
    }
  }

  void dispose() {
    _prChangesController.close();
  }

  Map<String, StoredSession> _indexSessionsByBranch({required List<StoredSession> sessions}) {
    final result = <String, StoredSession>{};
    for (final session in sessions) {
      if (session.parentSessionId != null) {
        continue;
      }
      final branchName = session.branchName;
      if (branchName == null || branchName.isEmpty) {
        continue;
      }
      result[branchName] = session;
    }
    return result;
  }
}
