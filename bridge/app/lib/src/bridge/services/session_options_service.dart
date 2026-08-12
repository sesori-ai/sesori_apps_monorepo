import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_options_cache_key.dart";
import "../repositories/session_options_repository.dart";

sealed class SessionOptionsOutcome {
  const SessionOptionsOutcome();
}

final class SessionOptionsAvailable extends SessionOptionsOutcome {
  const SessionOptionsAvailable({required this.response});

  final SessionOptionsResponse response;
}

final class SessionOptionsCacheUnavailable extends SessionOptionsOutcome {
  const SessionOptionsCacheUnavailable();
}

final class SessionOptionsProjectNotFound extends SessionOptionsOutcome {
  const SessionOptionsProjectNotFound();
}

sealed class SessionOptionsRefreshFailure {
  const SessionOptionsRefreshFailure();
}

final class SessionOptionsKnownRefreshFailure extends SessionOptionsRefreshFailure {
  const SessionOptionsKnownRefreshFailure();
}

final class SessionOptionsCaughtRefreshFailure extends SessionOptionsRefreshFailure {
  const SessionOptionsCaughtRefreshFailure({
    required this.cause,
    required this.causeStackTrace,
  });

  final Object cause;
  final StackTrace causeStackTrace;

  @override
  String toString() => "SessionOptionsCaughtRefreshFailure";
}

final class SessionOptionsRefreshFailedRetained extends SessionOptionsOutcome {
  const SessionOptionsRefreshFailedRetained({required this.failure});

  final SessionOptionsRefreshFailure failure;
}

final class SessionOptionsRefreshFailedUnavailable extends SessionOptionsOutcome {
  const SessionOptionsRefreshFailedUnavailable({required this.failure});

  final SessionOptionsRefreshFailure failure;
}

final class SessionOptionsAutomaticNoOp extends SessionOptionsOutcome {
  const SessionOptionsAutomaticNoOp();
}

class SessionOptionsService {
  SessionOptionsService({
    required SessionOptionsRepository repository,
    required Map<String, PluginSessionOptionsScope> pluginScopes,
    required ServerClock clock,
    required Duration retention,
  }) : _repository = repository,
       _pluginScopes = Map<String, PluginSessionOptionsScope>.unmodifiable(pluginScopes),
       _clock = clock,
       _retention = retention {
    if (retention.isNegative) {
      throw ArgumentError.value(retention, "retention", "must not be negative");
    }
  }

  final SessionOptionsRepository _repository;
  final Map<String, PluginSessionOptionsScope> _pluginScopes;
  final ServerClock _clock;
  final Duration _retention;
  final Map<SessionOptionsCacheKey, _RefreshCoordinator> _refreshes = {};

  Future<SessionOptionsOutcome> loadDynamic({
    required String pluginId,
    required String projectId,
  }) async {
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    final cached = await _readValid(key: resolved.key);
    if (cached != null && await _isCurrentResolution(resolved: resolved)) {
      return SessionOptionsAvailable(response: cached.response);
    }

    final outcome = await _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.reuse,
      generation: null,
      operation: () async {
        final newlyCached = await _readValid(key: resolved.key);
        final isCurrentResolution = await _isCurrentResolution(resolved: resolved);
        if (newlyCached != null && isCurrentResolution) {
          return SessionOptionsAvailable(response: newlyCached.response);
        }
        if (!isCurrentResolution) {
          return _movedProjectOutcome(automatic: false);
        }
        return _refresh(
          resolved: resolved,
          activation: SessionOptionsCaptureActivation.mayActivate,
          discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
          expectedGeneration: null,
          automatic: false,
        );
      },
    );
    if (outcome case SessionOptionsRefreshFailedRetained(:final failure)) {
      final concurrentlyAvailable = await _readValid(key: resolved.key);
      if (concurrentlyAvailable != null && await _isCurrentResolution(resolved: resolved)) {
        return SessionOptionsAvailable(response: concurrentlyAvailable.response);
      }
      return SessionOptionsRefreshFailedUnavailable(failure: failure);
    }
    return outcome;
  }

  Future<SessionOptionsOutcome> loadCacheOnly({
    required String pluginId,
    required String projectId,
  }) async {
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    final cached = await _readValid(key: resolved.key);
    if (cached == null) return const SessionOptionsCacheUnavailable();
    if (resolved.key is ProjectSessionOptionsCacheKey && !await _isCurrentResolution(resolved: resolved)) {
      return const SessionOptionsCacheUnavailable();
    }
    return SessionOptionsAvailable(response: cached.response);
  }

  Future<SessionOptionsOutcome> refreshExplicit({
    required String pluginId,
    required String projectId,
  }) async {
    final resolved = await _resolve(pluginId: pluginId, projectId: projectId);
    if (resolved == null) return const SessionOptionsProjectNotFound();
    return _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.forced,
      generation: null,
      operation: () => _refresh(
        resolved: resolved,
        activation: SessionOptionsCaptureActivation.mayActivate,
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        expectedGeneration: null,
        automatic: false,
      ),
    );
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
    return _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.reuse,
      generation: generation,
      operation: () => _refresh(
        resolved: resolved,
        activation: SessionOptionsCaptureActivation.activeOnly,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        expectedGeneration: generation,
        automatic: true,
      ),
    );
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
    return _coalesce(
      key: resolved.key,
      intent: _RefreshIntent.reuse,
      generation: generation,
      operation: () => _refresh(
        resolved: resolved,
        activation: SessionOptionsCaptureActivation.activeOnly,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        expectedGeneration: generation,
        automatic: true,
      ),
    );
  }

  Future<SessionOptionsOutcome> _refresh({
    required _ResolvedSessionOptions resolved,
    required SessionOptionsCaptureActivation activation,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
    required int? expectedGeneration,
    required bool automatic,
  }) async {
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
      return _captureFailure(
        resolved: resolved,
        automatic: automatic,
        message: "Session options capture failed for plugin ${resolved.key.pluginId}",
        error: error,
        stackTrace: stackTrace,
      );
    }

    switch (capture) {
      case SessionOptionsCaptureInactive():
        return const SessionOptionsAutomaticNoOp();
      case SessionOptionsCaptureFailed():
        return _captureFailure(
          resolved: resolved,
          automatic: automatic,
          message: "Session options discovery failed for plugin ${resolved.key.pluginId}",
          error: null,
          stackTrace: null,
        );
      case SessionOptionsCaptureObserved():
        break;
    }

    if (!await _isCurrentResolution(resolved: resolved)) {
      return _movedProjectOutcome(automatic: automatic);
    }

    final retained = await _readValid(key: resolved.key);
    if (!_canReplace(observation: capture, retained: retained)) {
      return SessionOptionsAvailable(response: retained!.response);
    }

    return _commitObservation(
      resolved: resolved,
      observation: capture,
      capturedAt: _clock.now().toUtc(),
      retained: retained,
      automatic: automatic,
      expectedGeneration: expectedGeneration,
    );
  }

  Future<SessionOptionsOutcome> _commitObservation({
    required _ResolvedSessionOptions resolved,
    required SessionOptionsCaptureObserved observation,
    required DateTime capturedAt,
    required SessionOptionsCacheEntry? retained,
    required bool automatic,
    required int? expectedGeneration,
  }) async {
    final firstCommit = await _tryCommit(
      resolved: resolved,
      observation: observation,
      capturedAt: capturedAt,
      retained: retained,
      automatic: automatic,
      expectedGeneration: expectedGeneration,
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
    );
    switch (secondCommit) {
      case _CommitFailed(:final outcome):
        return outcome;
      case _CommitSucceeded():
        return SessionOptionsAvailable(response: observation.response);
      case _CommitConflict():
        final latest = await _readValid(key: resolved.key);
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
  }) async {
    final key = resolved.key;
    if (!await _isCurrentResolution(resolved: resolved)) {
      return _CommitFailed(outcome: _movedProjectOutcome(automatic: automatic));
    }
    final expectedRevision = retained?.revision;
    final candidate = SessionOptionsCacheEntry(
      key: key,
      revision: expectedRevision == null ? 1 : expectedRevision + 1,
      capturedAt: capturedAt,
      completeness: observation.completeness,
      response: observation.response,
    );
    try {
      final committed = await _repository.commit(
        candidate: candidate,
        expectedRevision: expectedRevision,
        generation: observation.generation,
      );
      return committed ? const _CommitSucceeded() : const _CommitConflict();
    } on Object catch (error, stackTrace) {
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
  }) async {
    if (!await _isCurrentResolution(resolved: resolved)) {
      return _movedProjectOutcome(automatic: automatic);
    }
    final retained = await _readValid(key: resolved.key);
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
      final revision = error.revision;
      if (revision == null) {
        if (retryAfterDeleteConflict) {
          return _readValidAttempt(key: key, retryAfterDeleteConflict: false);
        }
        Log.w("Unable to recover undecodable session options cache for plugin ${key.pluginId}");
        return null;
      }
      Log.w("Recovering from undecodable session options cache for plugin ${key.pluginId}");
      if (!await _isCurrentCacheKey(key: key)) return null;
      final deleted = await _repository.deleteIfRevision(
        key: key,
        expectedRevision: revision,
      );
      if (!deleted && retryAfterDeleteConflict) {
        return _readValidAttempt(key: key, retryAfterDeleteConflict: false);
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
        return _readValidAttempt(key: key, retryAfterDeleteConflict: false);
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
    required Future<SessionOptionsOutcome> Function() operation,
  }) {
    final existing = _refreshes[key];
    if (existing != null) {
      final forcedTail = existing.forcedTail;
      if (forcedTail != null) return forcedTail;
      if (existing.intent == _RefreshIntent.forced) {
        return existing.running;
      }

      if (intent == _RefreshIntent.reuse) {
        if (existing.generation == generation) return existing.running;
        if (existing.reuseTail != null && existing.reuseTailGeneration == generation) {
          return existing.reuseTail!;
        }

        final predecessor = existing.reuseTail ?? existing.running;
        late final Future<SessionOptionsOutcome> tail;
        Future<SessionOptionsOutcome> startReuse() {
          existing
            ..intent = _RefreshIntent.reuse
            ..generation = generation
            ..running = tail;
          return Future<SessionOptionsOutcome>.sync(operation);
        }

        tail = predecessor.then(
          (_) => startReuse(),
          onError: (Object _, StackTrace _) => startReuse(),
        );
        existing
          ..reuseTail = tail
          ..reuseTailGeneration = generation;
        _removeAfterCompletion(key: key, coordinator: existing, future: tail);
        return tail;
      }

      final predecessor = existing.reuseTail ?? existing.running;
      late final Future<SessionOptionsOutcome> tail;
      Future<SessionOptionsOutcome> startForced() {
        existing
          ..intent = _RefreshIntent.forced
          ..generation = null
          ..running = tail;
        return Future<SessionOptionsOutcome>.sync(operation);
      }

      tail = predecessor.then(
        (_) => startForced(),
        onError: (Object _, StackTrace _) => startForced(),
      );
      existing.forcedTail = tail;
      _removeAfterCompletion(key: key, coordinator: existing, future: tail);
      return tail;
    }

    final running = Future<SessionOptionsOutcome>.sync(operation);
    final coordinator = _RefreshCoordinator(
      intent: intent,
      generation: generation,
      running: running,
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
      final terminal = coordinator.forcedTail ?? coordinator.reuseTail ?? coordinator.running;
      if (identical(terminal, future) && identical(_refreshes[key], coordinator)) {
        _refreshes.remove(key);
      }
    }

    unawaited(future.then<void>((_) => remove(), onError: (Object _, StackTrace _) => remove()));
  }
}

final class _ResolvedSessionOptions {
  const _ResolvedSessionOptions({
    required this.key,
    required this.projectId,
    required this.projectPath,
  });

  final SessionOptionsCacheKey key;
  final String projectId;
  final String projectPath;
}

enum _RefreshIntent { reuse, forced }

final class _RefreshCoordinator {
  _RefreshCoordinator({
    required this.intent,
    required this.generation,
    required this.running,
  });

  _RefreshIntent intent;
  int? generation;
  Future<SessionOptionsOutcome> running;
  Future<SessionOptionsOutcome>? reuseTail;
  int? reuseTailGeneration;
  Future<SessionOptionsOutcome>? forcedTail;
}

sealed class _CommitAttempt {
  const _CommitAttempt();
}

final class _CommitSucceeded extends _CommitAttempt {
  const _CommitSucceeded();
}

final class _CommitConflict extends _CommitAttempt {
  const _CommitConflict();
}

final class _CommitFailed extends _CommitAttempt {
  const _CommitFailed({required this.outcome});

  final SessionOptionsOutcome outcome;
}
