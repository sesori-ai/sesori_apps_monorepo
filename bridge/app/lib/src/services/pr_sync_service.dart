import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console, Log;

import "../repositories/models/pull_request_selection.dart";
import "../repositories/models/pull_request_target.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/models/verified_github_login.dart";
import "../repositories/pr_source_repository.dart";
import "../repositories/pull_request_repository.dart";
import "../repositories/session_repository.dart";

enum PrRefreshOutcome() { completed, failed }

enum PrRefreshPolicy() { background, explicit, viewedProject }

typedef PullRequestRenderedChange = ({String projectId});

class PrSyncService({
    required final PrSourceRepository _prSource,
    required final PullRequestRepository _pullRequestRepository,
    required final SessionRepository _sessionRepository,
    required final Clock _clock,
    final Duration _debounceWindow = const Duration(seconds: 30),
  }) {
  final StreamController<PullRequestRenderedChange> _renderedChangesController =
      StreamController<PullRequestRenderedChange>.broadcast();

  final Map<String, DateTime> _lastRefreshTimes = <String, DateTime>{};
  final Map<String, int> _nextRequestGenerations = <String, int>{};
  final Map<String, int> _pendingProjectGenerations = <String, int>{};
  Map<String, int> _activeProjectGenerations = const <String, int>{};
  final List<_PrRefreshWaiter> _refreshWaiters = <_PrRefreshWaiter>[];
  ({bool capable, DateTime checkedAt})? _githubCliCapabilityCache;
  Future<bool>? _githubCliCapabilityCheck;
  bool _identityVerificationFailureReported = false;
  Future<void>? _activeDrain;
  Future<void>? _disposeFuture;
  bool _isDraining = false;
  bool _disposed = false;

  static const _githubCliCacheTtl = Duration(seconds: 30);
  ({VerifiedGithubLogin login, DateTime checkedAt})? _verifiedIdentityCache;
  Future<VerifiedGithubLogin?>? _identityVerification;

  Stream<PullRequestRenderedChange> get renderedChanges => _renderedChangesController.stream;

  /// Verifies the active gh login, sharing one in-flight `gh api user` call and
  /// reusing a successful result for [_githubCliCacheTtl]. Each call is a
  /// network round trip, and an explicit refresh otherwise pays for several in
  /// series. Failures are never cached so a fixed login is picked up at once.
  Future<VerifiedGithubLogin?> verifyGithubIdentity() async {
    final inFlight = _identityVerification;
    if (inFlight != null) return await inFlight;

    final cached = _verifiedIdentityCache;
    if (cached != null && _clock.now().difference(cached.checkedAt) < _githubCliCacheTtl) {
      return cached.login;
    }

    final verification = _verifyGithubIdentity();
    _identityVerification = verification;
    try {
      return await verification;
    } finally {
      if (identical(_identityVerification, verification)) {
        _identityVerification = null;
      }
    }
  }

  Future<VerifiedGithubLogin?> _verifyGithubIdentity() async {
    try {
      final identity = await _prSource.getAuthenticatedIdentity();
      if (identity == null) {
        _reportIdentityVerificationFailure();
        return null;
      }
      _identityVerificationFailureReported = false;
      _verifiedIdentityCache = (login: identity, checkedAt: _clock.now());
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

  Future<PrRefreshOutcome> triggerRefresh({
    required Set<String> projectIds,
    required PrRefreshPolicy refreshPolicy,
  }) {
    if (_disposed) return Future.value(PrRefreshOutcome.failed);

    final requiredGenerations = <String, int>{};
    final sortedProjectIds = projectIds.where((projectId) => projectId.isNotEmpty).toList(growable: false)..sort();
    for (final projectId in sortedProjectIds) {
      final hasOutstandingRequest =
          _activeProjectGenerations.containsKey(projectId) || _pendingProjectGenerations.containsKey(projectId);
      final lastRefreshAt = _lastRefreshTimes[projectId];
      if (refreshPolicy == PrRefreshPolicy.background &&
          (hasOutstandingRequest ||
              lastRefreshAt != null && _clock.now().difference(lastRefreshAt) < _debounceWindow)) {
        continue;
      }
      final generation = (_nextRequestGenerations[projectId] ?? 0) + 1;
      _nextRequestGenerations[projectId] = generation;
      _pendingProjectGenerations[projectId] = generation;
      requiredGenerations[projectId] = generation;
    }
    if (requiredGenerations.isEmpty) {
      return Future.value(PrRefreshOutcome.completed);
    }

    final waiter = _PrRefreshWaiter(requiredGenerations: requiredGenerations);
    _refreshWaiters.add(waiter);
    _ensureDrainStarted();
    return waiter.future;
  }

  void _ensureDrainStarted() {
    if (_isDraining || _disposed) return;
    _isDraining = true;
    final drain = _drainRefreshCycles();
    _activeDrain = drain;
    unawaited(drain);
  }

  Future<void> _drainRefreshCycles() async {
    try {
      while (_pendingProjectGenerations.isNotEmpty && !_disposed) {
        final sealedGenerations = Map<String, int>.from(_pendingProjectGenerations);
        _pendingProjectGenerations.clear();
        _activeProjectGenerations = sealedGenerations;

        Map<String, PrRefreshOutcome> outcomes;
        try {
          outcomes = await _runRefreshCycle(projectIds: sealedGenerations.keys.toSet());
        } on Object catch (error, stackTrace) {
          Log.e("[PrSync] refresh cycle failed", error, stackTrace);
          outcomes = {
            for (final projectId in sealedGenerations.keys) projectId: PrRefreshOutcome.failed,
          };
        } finally {
          _activeProjectGenerations = const <String, int>{};
        }
        _settleWaiters(
          sealedGenerations: sealedGenerations,
          outcomes: outcomes,
        );
      }
    } finally {
      _isDraining = false;
      if (_pendingProjectGenerations.isNotEmpty && !_disposed) {
        _ensureDrainStarted();
      }
    }
  }

  void _settleWaiters({
    required Map<String, int> sealedGenerations,
    required Map<String, PrRefreshOutcome> outcomes,
  }) {
    for (final waiter in List<_PrRefreshWaiter>.from(_refreshWaiters)) {
      waiter.settle(
        sealedGenerations: sealedGenerations,
        outcomes: outcomes,
      );
      if (waiter.isSettled) {
        _refreshWaiters.remove(waiter);
      }
    }
  }

  Future<bool> _hasGithubCliCapability() async {
    final inFlight = _githubCliCapabilityCheck;
    if (inFlight != null) return await inFlight;

    final cached = _githubCliCapabilityCache;
    if (cached != null && _clock.now().difference(cached.checkedAt) < _githubCliCacheTtl) {
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

  Future<Map<String, PrRefreshOutcome>> _runRefreshCycle({
    required Set<String> projectIds,
  }) async {
    final outcomes = {
      for (final projectId in projectIds) projectId: PrRefreshOutcome.failed,
    };
    final sessionsByProject = <String, List<StoredSession>>{};
    final sortedProjectIds = projectIds.toList(growable: false)..sort();
    for (final projectId in sortedProjectIds) {
      sessionsByProject[projectId] = await _sessionRepository.getStoredSessionsByProjectId(
        projectId: projectId,
      );
    }
    final rootSessions = [
      for (final sessions in sessionsByProject.values)
        for (final session in sessions)
          if (session.parentSessionId == null) session,
    ];
    if (_disposed) return outcomes;
    final targetsByDirectory = await _prSource.resolvePullRequestTargets(
      directories: rootSessions.map((session) => session.directory),
    );
    if (_disposed) return outcomes;
    final failedProjectIds = <String>{};
    for (final entry in targetsByDirectory.entries) {
      switch (entry.value) {
        case PullRequestBranchResolutionFailed(:final error) || PullRequestRepositoryResolutionFailed(:final error):
          failedProjectIds.addAll(
            rootSessions.where((session) => session.directory == entry.key).map((session) => session.projectId),
          );
          Log.w("[PrSync] local pull request target resolution failed", error, error.innerStackTrace);
        case PullRequestBranchChangedDuringResolution():
          failedProjectIds.addAll(
            rootSessions.where((session) => session.directory == entry.key).map((session) => session.projectId),
          );
        default:
          break;
      }
    }

    final localChanges = await _pullRequestRepository.applyResolvedTargets(
      sessionsByProject: sessionsByProject,
      targetsByDirectory: targetsByDirectory,
    );
    _emitRenderedChanges(projectIds: localChanges);

    final githubTargetsByProject = <String, Set<PullRequestSelectionTarget>>{};
    for (final projectId in sortedProjectIds) {
      final targets = <PullRequestSelectionTarget>{
        for (final session in sessionsByProject[projectId] ?? const <StoredSession>[])
          if (session.parentSessionId == null)
            if (targetsByDirectory[session.directory] case PullRequestGithubDirectoryTarget(:final target)) target,
      };
      githubTargetsByProject[projectId] = targets;
      if (!failedProjectIds.contains(projectId) && targets.isEmpty) {
        outcomes[projectId] = PrRefreshOutcome.completed;
      }
    }
    final networkProjectIds = {
      for (final projectId in sortedProjectIds)
        if (!failedProjectIds.contains(projectId) && githubTargetsByProject[projectId]!.isNotEmpty) projectId,
    };
    if (networkProjectIds.isEmpty) {
      return _finishCycle(outcomes: outcomes);
    }

    try {
      if (!await _hasGithubCliCapability()) {
        return _finishCycle(outcomes: outcomes);
      }
      final verifiedGithubLogin = await verifyGithubIdentity();
      if (verifiedGithubLogin == null) {
        return _finishCycle(outcomes: outcomes);
      }
      final preparedChanges = await _pullRequestRepository.prepareScopedRefresh(
        projectIds: networkProjectIds,
        verifiedGithubLogin: verifiedGithubLogin,
      );
      _emitRenderedChanges(projectIds: preparedChanges);

      final uniqueTargets = {
        for (final projectId in networkProjectIds) ...githubTargetsByProject[projectId]!,
      }.toList(growable: false)..sort((first, second) => _compareTargets(first: first, second: second));
      final selectionOutcome = await _prSource.selectPullRequests(
        targets: uniqueTargets,
        expectedGithubLogin: verifiedGithubLogin,
      );
      final PullRequestSelectionCompleted completedSelection;
      switch (selectionOutcome) {
        case PullRequestSelectionCompleted():
          completedSelection = selectionOutcome;
        case PullRequestSelectionIdentityChanged():
          return _finishCycle(outcomes: outcomes);
      }

      final selectionsByTarget = {
        for (final selection in completedSelection.selections) selection.target: selection,
      };
      for (final projectId in networkProjectIds) {
        final targets = githubTargetsByProject[projectId]!.toList(growable: false)
          ..sort((first, second) => _compareTargets(first: first, second: second));
        final targetSelections = <PullRequestTargetSelection>[];
        for (final target in targets) {
          final selection = selectionsByTarget[target];
          if (selection == null) {
            throw const FormatException("GitHub pull request selection omitted a requested target");
          }
          targetSelections.add(selection);
        }
        try {
          final replacement = await _pullRequestRepository.replaceScopedPullRequests(
            projectId: projectId,
            verifiedGithubLogin: verifiedGithubLogin,
            capturedRootDirectoriesBySessionId: {
              for (final session in sessionsByProject[projectId] ?? const <StoredSession>[])
                if (session.parentSessionId == null) session.id: session.directory,
            },
            targetSelections: targetSelections,
            lastCheckedAt: _clock.now().millisecondsSinceEpoch,
          );
          switch (replacement) {
            case PullRequestReplacementApplied(:final changed):
              if (changed) _emitRenderedChanges(projectIds: {projectId});
              outcomes[projectId] = PrRefreshOutcome.completed;
            case PullRequestReplacementScopeChanged():
              outcomes[projectId] = PrRefreshOutcome.failed;
          }
        } on Object catch (error, stackTrace) {
          Log.e(
            "[PrSync] scoped pull request replacement failed; continuing remaining projects",
            error,
            stackTrace,
          );
        }
      }
    } on Object catch (error, stackTrace) {
      Log.e("[PrSync] GitHub pull request refresh failed", error, stackTrace);
    }
    return _finishCycle(outcomes: outcomes);
  }

  Map<String, PrRefreshOutcome> _finishCycle({
    required Map<String, PrRefreshOutcome> outcomes,
  }) {
    final completedAt = _clock.now();
    for (final entry in outcomes.entries) {
      if (entry.value == PrRefreshOutcome.completed) {
        _lastRefreshTimes[entry.key] = completedAt;
      }
    }
    return outcomes;
  }

  int _compareTargets({
    required PullRequestSelectionTarget first,
    required PullRequestSelectionTarget second,
  }) {
    final repositoryComparison = first.githubRepositoryIdentity.compareTo(second.githubRepositoryIdentity);
    return repositoryComparison != 0 ? repositoryComparison : first.branchName.compareTo(second.branchName);
  }

  void _emitRenderedChanges({required Iterable<String> projectIds}) {
    if (_disposed) return;
    final sortedProjectIds = projectIds.toSet().toList(growable: false)..sort();
    for (final projectId in sortedProjectIds) {
      _renderedChangesController.add((projectId: projectId));
    }
  }

  void beginShutdown() {
    if (_disposed) return;
    _disposed = true;
    _pendingProjectGenerations.clear();
    for (final waiter in _refreshWaiters) {
      waiter.fail();
    }
    _refreshWaiters.clear();
  }

  Future<void> drain() => _disposeFuture ??= _drain();

  Future<void> dispose() {
    beginShutdown();
    return drain();
  }

  Future<void> _drain() async {
    final activeDrain = _activeDrain;
    if (activeDrain != null) await activeDrain;
    await _renderedChangesController.close();
  }
}

final class _PrRefreshWaiter({required Map<String, int> requiredGenerations}) {
  final Map<String, int> _remainingGenerations = Map<String, int>.from(requiredGenerations);
  final Completer<PrRefreshOutcome> _completer = Completer<PrRefreshOutcome>();
  bool _failed = false;


  Future<PrRefreshOutcome> get future => _completer.future;
  bool get isSettled => _completer.isCompleted;

  void settle({
    required Map<String, int> sealedGenerations,
    required Map<String, PrRefreshOutcome> outcomes,
  }) {
    for (final entry in Map<String, int>.from(_remainingGenerations).entries) {
      final sealedGeneration = sealedGenerations[entry.key];
      if (sealedGeneration == null || sealedGeneration < entry.value) continue;
      if (outcomes[entry.key] != PrRefreshOutcome.completed) {
        _failed = true;
      }
      _remainingGenerations.remove(entry.key);
    }
    if (_remainingGenerations.isEmpty && !_completer.isCompleted) {
      _completer.complete(_failed ? PrRefreshOutcome.failed : PrRefreshOutcome.completed);
    }
  }

  void fail() {
    if (!_completer.isCompleted) {
      _completer.complete(PrRefreshOutcome.failed);
    }
  }
}
