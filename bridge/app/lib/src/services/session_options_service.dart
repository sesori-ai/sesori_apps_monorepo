import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show KeyedParallelLock;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_options_cache_key.dart";
import "../repositories/new_session_defaults_repository.dart";
import "../repositories/session_options_repository.dart";

/// How long a cached snapshot stays fresh. Past it the bridge still serves the
/// cache immediately and reports it stale, so a client can refresh in the
/// background instead of making the user wait on discovery. The entry itself
/// lives until retention expires it.
const Duration _staleAfter = Duration(days: 1);

sealed class const SessionOptionsOutcome();

final class const SessionOptionsAvailable({required final SessionOptionsResponse response})
    extends SessionOptionsOutcome;

final class const SessionOptionsCacheUnavailable() extends SessionOptionsOutcome;

final class const SessionOptionsProjectNotFound() extends SessionOptionsOutcome;

sealed class const SessionOptionsRefreshFailure();

final class const SessionOptionsKnownRefreshFailure() extends SessionOptionsRefreshFailure;

final class const SessionOptionsCaughtRefreshFailure({
  required final Object cause,
  required final StackTrace causeStackTrace,
}) extends SessionOptionsRefreshFailure {
  @override
  String toString() => "SessionOptionsCaughtRefreshFailure";
}

final class const SessionOptionsRefreshFailedRetained({required final SessionOptionsRefreshFailure failure})
    extends SessionOptionsOutcome;

final class const SessionOptionsRefreshFailedUnavailable({required final SessionOptionsRefreshFailure failure})
    extends SessionOptionsOutcome;

final class const SessionOptionsAutomaticNoOp() extends SessionOptionsOutcome;

/// A committed snapshot, announced so screens already showing these options can
/// re-read the cache instead of continuing to render what it replaced.
/// [projectId] is null for a plugin-scoped catalog, which every project shares.
final class const SessionOptionsCacheUpdate({
  required final String pluginId,
  required final String? projectId,
});

class SessionOptionsService({
  required final SessionOptionsRepository _repository,
  required final NewSessionDefaultsRepository _newSessionDefaultsRepository,
  required Map<String, PluginSessionOptionsScope> pluginScopes,
  required final ServerClock _clock,
  required final Duration _retention,
}) {
  this {
    if (_retention.isNegative) {
      throw ArgumentError.value(_retention, "retention", "must not be negative");
    }
  }

  final Map<String, PluginSessionOptionsScope> _pluginScopes = Map<String, PluginSessionOptionsScope>.unmodifiable(
    pluginScopes,
  );
  final StreamController<SessionOptionsCacheUpdate> _cacheUpdatesController =
      StreamController<SessionOptionsCacheUpdate>.broadcast(sync: true);
  final Map<SessionOptionsCacheKey, _RefreshCoordinator> _refreshes = {};
  final KeyedParallelLock<SessionOptionsCacheKey> _invalidationLock = KeyedParallelLock<SessionOptionsCacheKey>();
  final Map<SessionOptionsCacheKey, int> _invalidationEpochs = {};

  /// Committed snapshots, in commit order. A refresh that changed nothing the
  /// cache did not already hold still announces: the commit is what proves the
  /// snapshot current, and a consumer re-reading an unchanged cache is cheap.
  Stream<SessionOptionsCacheUpdate> get cacheUpdates => _cacheUpdatesController.stream;

  Future<void> dispose() => _cacheUpdatesController.close();

  Future<SessionOptionsOutcome> loadDynamic({
    required String pluginId,
    required String projectId,
  }) {
    return _withLastUsedPromptDefaults(
      pluginId: pluginId,
      outcome: _loadDynamic(pluginId: pluginId, projectId: projectId),
    );
  }

  Future<SessionOptionsOutcome> _loadDynamic({
    required String pluginId,
    required String projectId,
  }) async {
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    final cacheEpoch = _invalidationEpoch(key: resolved.key);
    final cached = await _readValid(key: resolved.key);
    if (cached != null &&
        await _isCurrentResolution(resolved: resolved) &&
        await _isCurrentInvalidationEpoch(key: resolved.key, expected: cacheEpoch)) {
      return _servedFromCache(entry: cached);
    }

    final outcome = await _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.reuse,
      generation: null,
      operation: (invalidationEpoch) async {
        if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
          return _invalidatedRefreshOutcome(automatic: false);
        }
        final newlyCached = await _readValid(key: resolved.key);
        final isCurrentResolution = await _isCurrentResolution(resolved: resolved);
        if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
          return _invalidatedRefreshOutcome(automatic: false);
        }
        if (newlyCached != null && isCurrentResolution) {
          return _servedFromCache(entry: newlyCached);
        }
        if (!isCurrentResolution) {
          return _movedProjectOutcome(automatic: false);
        }
        return await _refresh(
          resolved: resolved,
          activation: SessionOptionsCaptureActivation.mayActivate,
          discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
          expectedGeneration: null,
          automatic: false,
          invalidationEpoch: invalidationEpoch,
        );
      },
    );
    if (outcome case SessionOptionsRefreshFailedRetained(:final failure)) {
      final recoveryEpoch = _invalidationEpoch(key: resolved.key);
      final concurrentlyAvailable = await _readValid(key: resolved.key);
      if (concurrentlyAvailable != null &&
          await _isCurrentResolution(resolved: resolved) &&
          await _isCurrentInvalidationEpoch(key: resolved.key, expected: recoveryEpoch)) {
        return SessionOptionsAvailable(response: concurrentlyAvailable.response);
      }
      return SessionOptionsRefreshFailedUnavailable(failure: failure);
    }
    return outcome;
  }

  /// A valid cache [loadDynamic] served instead of discovering, told whether
  /// the snapshot has aged past [_staleAfter] so the client can refresh it in
  /// the background. The failure fallback below deliberately does not: the
  /// bridge just failed to refresh this very cache, so asking again at once
  /// would only repeat the failure.
  SessionOptionsAvailable _servedFromCache({required SessionOptionsCacheEntry entry}) {
    final age = _clock.now().toUtc().difference(entry.capturedAt.toUtc());
    return SessionOptionsAvailable(response: entry.response.copyWith(stale: age > _staleAfter));
  }

  Future<SessionOptionsOutcome> loadCacheOnly({
    required String pluginId,
    required String projectId,
  }) {
    return _withLastUsedPromptDefaults(
      pluginId: pluginId,
      outcome: _loadCacheOnly(pluginId: pluginId, projectId: projectId),
    );
  }

  Future<SessionOptionsOutcome> _loadCacheOnly({
    required String pluginId,
    required String projectId,
  }) async {
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    final cacheEpoch = _invalidationEpoch(key: resolved.key);
    final cached = await _readValid(key: resolved.key);
    if (cached == null) return const SessionOptionsCacheUnavailable();
    if (resolved.key is ProjectSessionOptionsCacheKey && !await _isCurrentResolution(resolved: resolved)) {
      return const SessionOptionsCacheUnavailable();
    }
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: cacheEpoch)) {
      return const SessionOptionsCacheUnavailable();
    }
    return SessionOptionsAvailable(response: cached.response);
  }

  Future<SessionOptionsOutcome> refreshExplicit({
    required String pluginId,
    required String projectId,
  }) {
    return _withLastUsedPromptDefaults(
      pluginId: pluginId,
      outcome: _refreshExplicit(pluginId: pluginId, projectId: projectId),
    );
  }

  Future<SessionOptionsOutcome> _refreshExplicit({
    required String pluginId,
    required String projectId,
  }) async {
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    return await _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.forced,
      generation: null,
      operation: (invalidationEpoch) => _refresh(
        resolved: resolved,
        activation: SessionOptionsCaptureActivation.mayActivate,
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        expectedGeneration: null,
        automatic: false,
        invalidationEpoch: invalidationEpoch,
      ),
    );
  }

  Future<SessionOptionsOutcome> _withLastUsedPromptDefaults({
    required String pluginId,
    required Future<SessionOptionsOutcome> outcome,
  }) async {
    final resolved = await outcome;
    if (resolved case SessionOptionsAvailable(:final response)) {
      try {
        final defaults = await _newSessionDefaultsRepository.read(pluginId: pluginId);
        return SessionOptionsAvailable(response: response.copyWith(lastUsedPromptDefaults: defaults));
      } on Object catch (error, stackTrace) {
        Log.w("Failed to read new-session defaults for plugin $pluginId", error, stackTrace);
        return SessionOptionsAvailable(response: response.copyWith(lastUsedPromptDefaults: null));
      }
    }
    return resolved;
  }

  /// Discards an options snapshot proven stale by a rejected send. The client
  /// that receives the typed rejection then requests forced discovery; the
  /// rejected snapshot cannot be retained if that discovery fails.
  ///
  /// The delete runs immediately, alongside any discovery already in flight,
  /// so it never waits behind a plugin catalog probe. The epoch prevents work
  /// requested before the rejection from republishing the rejected snapshot.
  Future<void> invalidateRejectedSelection({
    required String pluginId,
    required String projectId,
  }) async {
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return;
    final key = resolved.key;
    _invalidationEpochs[key] = _invalidationEpoch(key: key) + 1;
    await _invalidationLock.use(
      key: key,
      operation: () => _repository.delete(key: key),
    );
  }

  /// Holds a commit until every delete already issued for [key] has settled,
  /// so a snapshot captured after a rejection survives the delete that raced it.
  Future<void> _awaitInvalidation({required SessionOptionsCacheKey key}) => _invalidationLock.idleFor(key: key);

  int _invalidationEpoch({required SessionOptionsCacheKey key}) => _invalidationEpochs[key] ?? 0;

  Future<bool> _isCurrentInvalidationEpoch({
    required SessionOptionsCacheKey key,
    required int expected,
  }) async {
    await _awaitInvalidation(key: key);
    return _invalidationEpoch(key: key) == expected;
  }

  Future<SessionOptionsOutcome> refreshActiveOnly({
    required String pluginId,
    required String projectId,
    required int generation,
  }) async {
    if (!_repository.isCurrentGeneration(pluginId: pluginId, generation: generation)) {
      return const SessionOptionsAutomaticNoOp();
    }
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    return await _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.reuse,
      generation: generation,
      operation: (invalidationEpoch) => _refresh(
        resolved: resolved,
        activation: SessionOptionsCaptureActivation.activeOnly,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        expectedGeneration: generation,
        automatic: true,
        invalidationEpoch: invalidationEpoch,
      ),
    );
  }

  /// Brings every project-scoped snapshot this plugin holds up to date, for a
  /// backend change that named no session — Codex reporting changed skills, for
  /// one. Only cached, unexpired projects are refreshed: a project the user has
  /// never opened options for has nothing to correct, and a snapshot already
  /// past retention should expire rather than be renewed here, which also keeps
  /// this bounded on an installation with a long project history.
  Future<void> refreshActiveOnlyForCachedProjects({
    required String pluginId,
    required int generation,
  }) async {
    if (!_repository.isCurrentGeneration(pluginId: pluginId, generation: generation)) return;
    final projectIds = await _repository.listCachedProjectIds(
      pluginId: pluginId,
      notBefore: _clock.now().toUtc().subtract(_retention),
    );
    for (final projectId in projectIds) {
      await refreshActiveOnly(pluginId: pluginId, projectId: projectId, generation: generation);
    }
  }

  Future<SessionOptionsOutcome> refreshActiveOnlyForBackendSession({
    required String pluginId,
    required String backendSessionId,
    required int generation,
  }) async {
    if (!_repository.isCurrentGeneration(pluginId: pluginId, generation: generation)) {
      return const SessionOptionsAutomaticNoOp();
    }
    final projectId = await _repository.resolveProjectIdForBackendSession(
      pluginId: pluginId,
      backendSessionId: backendSessionId,
    );
    if (projectId == null) return const SessionOptionsAutomaticNoOp();
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    return await _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.reuse,
      generation: generation,
      operation: (invalidationEpoch) => _refresh(
        resolved: resolved,
        activation: SessionOptionsCaptureActivation.activeOnly,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        expectedGeneration: generation,
        automatic: true,
        invalidationEpoch: invalidationEpoch,
      ),
    );
  }

  Future<SessionOptionsOutcome> _refresh({
    required _ResolvedSessionOptions resolved,
    required SessionOptionsCaptureActivation activation,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
    required int? expectedGeneration,
    required bool automatic,
    required int invalidationEpoch,
  }) async {
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }
    if (activation == SessionOptionsCaptureActivation.activeOnly) {
      if (expectedGeneration != null &&
          !_repository.isCurrentGeneration(
            pluginId: resolved.key.pluginId,
            generation: expectedGeneration,
          )) {
        return const SessionOptionsAutomaticNoOp();
      }
      if (!_repository.isPluginActive(pluginId: resolved.key.pluginId)) {
        return const SessionOptionsAutomaticNoOp();
      }
    }

    final SessionOptionsCaptureResult capture;
    try {
      capture = await _repository.capture(
        key: resolved.key,
        projectPath: resolved.projectPath,
        activation: activation,
        discoveryMode: discoveryMode,
        expectedGeneration: expectedGeneration,
      );
    } on Object catch (error, stackTrace) {
      if (_becameStale(pluginId: resolved.key.pluginId, expectedGeneration: expectedGeneration)) {
        return const SessionOptionsAutomaticNoOp();
      }
      return await _captureFailure(
        resolved: resolved,
        automatic: automatic,
        message: "Session options capture failed for plugin ${resolved.key.pluginId}",
        error: error,
        stackTrace: stackTrace,
        invalidationEpoch: invalidationEpoch,
      );
    }

    switch (capture) {
      case SessionOptionsCaptureInactive():
        return const SessionOptionsAutomaticNoOp();
      case SessionOptionsCaptureFailed():
        return await _captureFailure(
          resolved: resolved,
          automatic: automatic,
          message: "Session options discovery failed for plugin ${resolved.key.pluginId}",
          error: null,
          stackTrace: null,
          invalidationEpoch: invalidationEpoch,
        );
      case SessionOptionsCaptureObserved():
        break;
    }

    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }

    if (!await _isCurrentResolution(resolved: resolved)) {
      return _movedProjectOutcome(automatic: automatic);
    }
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }

    final retained = await _readValid(key: resolved.key);
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }
    if (!_canReplace(observation: capture, retained: retained)) {
      return SessionOptionsAvailable(response: retained!.response);
    }

    return await _commitObservation(
      resolved: resolved,
      observation: capture,
      capturedAt: _clock.now().toUtc(),
      retained: retained,
      automatic: automatic,
      expectedGeneration: expectedGeneration,
      invalidationEpoch: invalidationEpoch,
    );
  }

  Future<SessionOptionsOutcome> _commitObservation({
    required _ResolvedSessionOptions resolved,
    required SessionOptionsCaptureObserved observation,
    required DateTime capturedAt,
    required SessionOptionsCacheEntry? retained,
    required bool automatic,
    required int? expectedGeneration,
    required int invalidationEpoch,
  }) async {
    final firstCommit = await _tryCommit(
      resolved: resolved,
      observation: observation,
      capturedAt: capturedAt,
      retained: retained,
      automatic: automatic,
      expectedGeneration: expectedGeneration,
      invalidationEpoch: invalidationEpoch,
    );
    switch (firstCommit) {
      case _CommitFailed(:final outcome):
        return outcome;
      case _CommitSucceeded():
        return SessionOptionsAvailable(response: observation.response);
      case _CommitConflict():
        break;
    }

    final newest = await _readValid(key: resolved.key);
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }
    if (!_canReplace(observation: observation, retained: newest)) {
      return SessionOptionsAvailable(response: newest!.response);
    }

    final secondCommit = await _tryCommit(
      resolved: resolved,
      observation: observation,
      capturedAt: capturedAt,
      retained: newest,
      automatic: automatic,
      expectedGeneration: expectedGeneration,
      invalidationEpoch: invalidationEpoch,
    );
    switch (secondCommit) {
      case _CommitFailed(:final outcome):
        return outcome;
      case _CommitSucceeded():
        return SessionOptionsAvailable(response: observation.response);
      case _CommitConflict():
        final latest = await _readValid(key: resolved.key);
        if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
          return _invalidatedRefreshOutcome(automatic: automatic);
        }
        Log.w(
          "Session options cache commit conflicted twice for plugin ${resolved.key.pluginId}; retaining newest cache",
        );
        return latest == null
            ? const SessionOptionsRefreshFailedUnavailable(
                failure: SessionOptionsKnownRefreshFailure(),
              )
            : SessionOptionsAvailable(response: latest.response);
    }
  }

  Future<_CommitAttempt> _tryCommit({
    required _ResolvedSessionOptions resolved,
    required SessionOptionsCaptureObserved observation,
    required DateTime capturedAt,
    required SessionOptionsCacheEntry? retained,
    required bool automatic,
    required int? expectedGeneration,
    required int invalidationEpoch,
  }) async {
    final key = resolved.key;
    if (!await _isCurrentResolution(resolved: resolved)) {
      return _CommitFailed(outcome: _movedProjectOutcome(automatic: automatic));
    }
    if (!await _isCurrentInvalidationEpoch(key: key, expected: invalidationEpoch)) {
      return _CommitFailed(outcome: _invalidatedRefreshOutcome(automatic: automatic));
    }
    final expectedRevision = retained?.revision;
    final candidate = SessionOptionsCacheEntry(
      key: key,
      revision: expectedRevision == null ? 1 : expectedRevision + 1,
      capturedAt: capturedAt,
      response: observation.response,
    );
    try {
      final committed = await _repository.commit(
        candidate: candidate,
        expectedRevision: expectedRevision,
        generation: observation.generation,
      );
      if (!await _isCurrentInvalidationEpoch(key: key, expected: invalidationEpoch)) {
        if (committed) {
          try {
            await _repository.deleteIfRevision(key: key, expectedRevision: candidate.revision);
          } on Object catch (error, stackTrace) {
            Log.w("Failed to discard invalidated session options for plugin ${key.pluginId}", error, stackTrace);
          }
        }
        return _CommitFailed(outcome: _invalidatedRefreshOutcome(automatic: automatic));
      }
      if (committed) _announceCommit(key: key);
      return committed ? const _CommitSucceeded() : const _CommitConflict();
    } on Object catch (error, stackTrace) {
      if (!await _isCurrentInvalidationEpoch(key: key, expected: invalidationEpoch)) {
        return _CommitFailed(outcome: _invalidatedRefreshOutcome(automatic: automatic));
      }
      if (_becameStale(pluginId: key.pluginId, expectedGeneration: expectedGeneration)) {
        return const _CommitFailed(outcome: SessionOptionsAutomaticNoOp());
      }
      final newest = await _readValid(key: key);
      return _CommitFailed(
        outcome: _refreshFailure(
          retained: newest,
          message: "Session options cache commit failed for plugin ${key.pluginId}",
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _announceCommit({required SessionOptionsCacheKey key}) {
    if (_cacheUpdatesController.isClosed) return;
    _cacheUpdatesController.add(
      SessionOptionsCacheUpdate(
        pluginId: key.pluginId,
        projectId: switch (key) {
          PluginSessionOptionsCacheKey() => null,
          ProjectSessionOptionsCacheKey(:final projectId) => projectId,
        },
      ),
    );
  }

  bool _canReplace({
    required SessionOptionsCaptureObserved observation,
    required SessionOptionsCacheEntry? retained,
  }) {
    return observation.completeness == PluginSessionOptionsCompleteness.complete || retained == null;
  }

  SessionOptionsOutcome _refreshFailure({
    required SessionOptionsCacheEntry? retained,
    required String message,
    required Object? error,
    required StackTrace? stackTrace,
  }) {
    final SessionOptionsRefreshFailure failure;
    if (error == null) {
      failure = const SessionOptionsKnownRefreshFailure();
    } else {
      final caughtStackTrace = stackTrace;
      if (caughtStackTrace == null) {
        throw StateError("caught refresh failure requires a stack trace");
      }
      failure = SessionOptionsCaughtRefreshFailure(
        cause: error,
        causeStackTrace: caughtStackTrace,
      );
    }
    // Explicit requests are logged too: the client only ever sees an opaque
    // `refreshFailedUnavailable` code, so this log is the sole place that
    // retains the original error, stack trace, and operation context.
    if (error == null) {
      Log.w(message);
    } else {
      Log.w(message, error, stackTrace);
    }
    return retained == null
        ? SessionOptionsRefreshFailedUnavailable(failure: failure)
        : SessionOptionsRefreshFailedRetained(failure: failure);
  }

  Future<SessionOptionsOutcome> _captureFailure({
    required _ResolvedSessionOptions resolved,
    required bool automatic,
    required String message,
    required Object? error,
    required StackTrace? stackTrace,
    required int invalidationEpoch,
  }) async {
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }
    if (!await _isCurrentResolution(resolved: resolved)) {
      return _movedProjectOutcome(automatic: automatic);
    }
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }
    final retained = await _readValid(key: resolved.key);
    if (!await _isCurrentInvalidationEpoch(key: resolved.key, expected: invalidationEpoch)) {
      return _invalidatedRefreshOutcome(automatic: automatic);
    }
    return _refreshFailure(
      retained: retained,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  bool _becameStale({required String pluginId, required int? expectedGeneration}) {
    return expectedGeneration != null &&
        !_repository.isCurrentGeneration(pluginId: pluginId, generation: expectedGeneration);
  }

  Future<bool> _isCurrentResolution({required _ResolvedSessionOptions resolved}) async {
    if (resolved.key is PluginSessionOptionsCacheKey) return true;
    final currentPath = await _repository.resolveProjectPath(projectId: resolved.projectId);
    return currentPath == resolved.projectPath;
  }

  SessionOptionsOutcome _movedProjectOutcome({required bool automatic}) {
    return automatic
        ? const SessionOptionsAutomaticNoOp()
        : const SessionOptionsRefreshFailedUnavailable(
            failure: SessionOptionsKnownRefreshFailure(),
          );
  }

  SessionOptionsOutcome _invalidatedRefreshOutcome({required bool automatic}) {
    return automatic
        ? const SessionOptionsAutomaticNoOp()
        : const SessionOptionsRefreshFailedUnavailable(
            failure: SessionOptionsKnownRefreshFailure(),
          );
  }

  Future<SessionOptionsCacheEntry?> _readValid({required SessionOptionsCacheKey key}) {
    return _readValidAttempt(key: key, retryAfterDeleteConflict: true);
  }

  Future<SessionOptionsCacheEntry?> _readValidAttempt({
    required SessionOptionsCacheKey key,
    required bool retryAfterDeleteConflict,
  }) async {
    final SessionOptionsCacheEntry? entry;
    try {
      entry = await _repository.read(key: key);
    } on SessionOptionsCacheDecodingException catch (error) {
      Log.w(
        "Recovering from undecodable session options cache for plugin ${key.pluginId} "
        "(discarding revision ${error.revision})",
      );
      if (!await _isCurrentCacheKey(key: key)) return null;
      final deleted = await _repository.deleteIfRevision(
        key: key,
        expectedRevision: error.revision,
      );
      if (!deleted && retryAfterDeleteConflict) {
        return await _readValidAttempt(key: key, retryAfterDeleteConflict: false);
      }
      return null;
    }
    if (entry == null) return null;

    final now = _clock.now().toUtc();
    final capturedAt = entry.capturedAt.toUtc();
    if (entry.key != key || capturedAt.isAfter(now) || now.difference(capturedAt) > _retention) {
      if (!await _isCurrentCacheKey(key: key)) return null;
      final deleted = await _repository.deleteIfRevision(
        key: key,
        expectedRevision: entry.revision,
      );
      if (!deleted && retryAfterDeleteConflict) {
        return await _readValidAttempt(key: key, retryAfterDeleteConflict: false);
      }
      return null;
    }
    return entry;
  }

  Future<bool> _isCurrentCacheKey({required SessionOptionsCacheKey key}) async {
    return switch (key) {
      PluginSessionOptionsCacheKey() => true,
      ProjectSessionOptionsCacheKey(:final projectId, :final projectPath) =>
        await _repository.resolveProjectPath(projectId: projectId) == projectPath,
    };
  }

  Future<_ResolvedSessionOptions?> _resolve({
    required String pluginId,
    required String projectId,
  }) async {
    final scope = _pluginScopes[pluginId];
    if (scope == null) {
      throw StateError("Session options scope is not registered for plugin $pluginId");
    }
    final projectPath = await _repository.resolveProjectPath(projectId: projectId);
    if (projectPath == null) return null;
    final key = switch (scope) {
      PluginSessionOptionsScope.plugin => SessionOptionsCacheKey.plugin(pluginId: pluginId),
      PluginSessionOptionsScope.project => SessionOptionsCacheKey.project(
        pluginId: pluginId,
        projectId: projectId,
        projectPath: projectPath,
      ),
    };
    return _ResolvedSessionOptions(
      key: key,
      projectId: projectId,
      projectPath: projectPath,
    );
  }

  Future<SessionOptionsOutcome> _coalesce({
    required SessionOptionsCacheKey key,
    required _RefreshIntent intent,
    required int? generation,
    required Future<SessionOptionsOutcome> Function(int invalidationEpoch) operation,
  }) {
    final invalidationEpoch = _invalidationEpoch(key: key);
    final existing = _refreshes[key];
    if (existing != null) {
      final sameEpoch = existing.invalidationEpoch == invalidationEpoch;
      if (sameEpoch &&
          (existing.intent == _RefreshIntent.forced ||
              (intent == _RefreshIntent.reuse && existing.generation == generation))) {
        return existing.terminal;
      }

      final predecessor = existing.terminal;
      Future<SessionOptionsOutcome> start() {
        return Future<SessionOptionsOutcome>.sync(() => operation(invalidationEpoch));
      }

      final tail = predecessor.then(
        (_) => start(),
        onError: (Object _, StackTrace _) => start(),
      );
      existing
        ..intent = intent
        ..generation = generation
        ..invalidationEpoch = invalidationEpoch
        ..terminal = tail;
      _removeAfterCompletion(key: key, coordinator: existing, future: tail);
      return tail;
    }

    final running = Future<SessionOptionsOutcome>.sync(() => operation(invalidationEpoch));
    final coordinator = _RefreshCoordinator(
      intent: intent,
      generation: generation,
      invalidationEpoch: invalidationEpoch,
      terminal: running,
    );
    _refreshes[key] = coordinator;
    _removeAfterCompletion(key: key, coordinator: coordinator, future: running);
    return running;
  }

  void _removeAfterCompletion({
    required SessionOptionsCacheKey key,
    required _RefreshCoordinator coordinator,
    required Future<SessionOptionsOutcome> future,
  }) {
    void remove() {
      if (identical(coordinator.terminal, future) && identical(_refreshes[key], coordinator)) {
        _refreshes.remove(key);
      }
    }

    unawaited(future.then<void>((_) => remove(), onError: (Object _, StackTrace _) => remove()));
  }
}

final class const _ResolvedSessionOptions({
  required final SessionOptionsCacheKey key,
  required final String projectId,
  required final String projectPath,
});

enum _RefreshIntent() {
  reuse,
  forced,
}

final class _RefreshCoordinator({
  required var _RefreshIntent intent,
  required var int? generation,
  required var int invalidationEpoch,
  required var Future<SessionOptionsOutcome> terminal,
});

sealed class const _CommitAttempt();

final class const _CommitSucceeded() extends _CommitAttempt;

final class const _CommitConflict() extends _CommitAttempt;

final class const _CommitFailed({required final SessionOptionsOutcome outcome}) extends _CommitAttempt;
