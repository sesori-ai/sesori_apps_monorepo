import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mappers/session_event_mapper.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";
import "../repositories/trackers/session_event_tracker.dart";
import "session_mutation_dispatcher.dart";

typedef SourcedBridgeEvent = ({String pluginId, int projectionUpdatedAt, BridgeSseEvent event});
typedef _ProjectedSession = ({StoredSession binding, bool inserted});

class SessionEventService {
  final SessionRepository _sessionRepository;
  final SessionMutationDispatcher _sessionMutationDispatcher;
  final SessionEventMapper _eventMapper;
  final SessionEventTracker _eventTracker;
  final FailureReporter _failureReporter;

  SessionEventService({
    required SessionRepository sessionRepository,
    required SessionMutationDispatcher sessionMutationDispatcher,
    required SessionEventMapper eventMapper,
    required SessionEventTracker eventTracker,
    required FailureReporter failureReporter,
  }) : _sessionRepository = sessionRepository,
       _sessionMutationDispatcher = sessionMutationDispatcher,
       _eventMapper = eventMapper,
       _eventTracker = eventTracker,
       _failureReporter = failureReporter;

  SourcedBridgeEvent captureSource({required String pluginId, required BridgeSseEvent event}) {
    return (
      pluginId: pluginId,
      projectionUpdatedAt: _sessionRepository.captureProjectionTimestamp(),
      event: event,
    );
  }

  Future<List<BridgeSseEvent>> normalize({required SourcedBridgeEvent source}) async {
    return _normalizeGuarded(source: source, drainPending: true);
  }

  Future<List<BridgeSseEvent>> _normalizeGuarded({
    required SourcedBridgeEvent source,
    required bool drainPending,
  }) async {
    try {
      return await _normalize(source: source, drainPending: drainPending);
    } on Object catch (error, stackTrace) {
      Log.w("[sse] failed to normalize ${source.event.runtimeType}", error, stackTrace);
      try {
        await _failureReporter.recordFailure(
          error: error,
          stackTrace: stackTrace,
          uniqueIdentifier: "bridge.sse.session_event",
          fatal: false,
          reason: "failed to normalize plugin SSE event",
          information: [source.pluginId, source.event.runtimeType],
        );
      } on Object catch (reportError, reportStackTrace) {
        Log.w("[sse] failed to report normalization failure", reportError, reportStackTrace);
      }
      return const [];
    }
  }

  Future<List<BridgeSseEvent>> _normalize({
    required SourcedBridgeEvent source,
    required bool drainPending,
  }) async {
    if (source.event is BridgeSseSessionDeleted) return const [];

    final observed = _eventMapper.sessionInfo(event: source.event);
    if (observed == null) {
      return [
        ?await _translate(source: source),
      ];
    }

    final projection = await _projectSession(source: source, observed: observed);
    if (projection == null) return const [];
    final normalized = await _translate(source: source);
    final output = <BridgeSseEvent>[
      if (projection.inserted && source.event is! BridgeSseSessionCreated)
        ?await _createdEvent(sessionId: projection.binding.id),
      ?normalized,
    ];
    if (drainPending) {
      output.addAll(
        await _drainPendingForBinding(
          pluginId: source.pluginId,
          backendSessionId: observed.id,
        ),
      );
    }
    return output;
  }

  Future<List<BridgeSseEvent>> handleBindingsCommitted({required SessionBindingsCommitted commit}) async {
    final output = <BridgeSseEvent>[];
    for (final backendSessionId in commit.backendSessionIds) {
      final pendingRoot = _eventTracker.takeRoot(
        pluginId: commit.pluginId,
        backendSessionId: backendSessionId,
      );
      if (pendingRoot != null) {
        final binding = await _sessionRepository.getStoredSessionByBackendId(
          pluginId: commit.pluginId,
          backendSessionId: backendSessionId,
        );
        final catalog = binding == null ? null : await _sessionRepository.getCatalogSession(sessionId: binding.id);
        if (catalog != null) output.add(BridgeSseSessionCreated(info: catalog.toJson()));
      }
      output.addAll(
        await _drainPendingForBinding(
          pluginId: commit.pluginId,
          backendSessionId: backendSessionId,
        ),
      );
    }
    return output;
  }

  Future<bool> canPublish({required BridgeSseEvent event}) async {
    if (event is! BridgeSseSessionCreated && event is! BridgeSseSessionUpdated) return true;
    final session = _eventMapper.sessionInfo(event: event);
    if (session == null || await _sessionRepository.getStoredSession(sessionId: session.id) == null) return false;
    return !await _sessionRepository.isSessionTombstoned(sessionId: session.id);
  }

  Future<_ProjectedSession?> _projectSession({
    required SourcedBridgeEvent source,
    required Session observed,
  }) async {
    final existing = await _sessionRepository.getStoredSessionByBackendId(
      pluginId: source.pluginId,
      backendSessionId: observed.id,
    );
    final backendParentId = observed.parentID;
    if (existing != null) {
      if (backendParentId != null) {
        final parent = await _sessionRepository.getStoredSessionByBackendId(
          pluginId: source.pluginId,
          backendSessionId: backendParentId,
        );
        if (parent == null || existing.parentSessionId != parent.id) return null;
      } else if (existing.parentSessionId != null) {
        return null;
      }
      final binding = await _sessionRepository.updateObservedSessionProjection(
        pluginId: source.pluginId,
        observed: observed,
        updateCatalogTitle: switch (source.event) {
          BridgeSseSessionCreated() => true,
          BridgeSseSessionUpdated(:final titleChanged) => titleChanged || observed.title != null,
          _ => observed.title != null,
        },
        projectionUpdatedAt: source.projectionUpdatedAt,
      );
      return binding == null ? null : (binding: binding, inserted: false);
    }
    if (backendParentId == null) {
      if (source.event is BridgeSseSessionCreated) {
        _warnIfEvicted(
          evicted: _eventTracker.addRoot(
            event: PendingSessionEvent(
              pluginId: source.pluginId,
              event: source.event,
              session: observed,
              projectionUpdatedAt: source.projectionUpdatedAt,
            ),
          ),
        );
      }
      return null;
    }

    final parent = await _sessionRepository.getStoredSessionByBackendId(
      pluginId: source.pluginId,
      backendSessionId: backendParentId,
    );
    if (parent == null) {
      _warnIfEvicted(
        evicted: _eventTracker.addChild(
          event: PendingSessionEvent(
            pluginId: source.pluginId,
            event: source.event,
            session: observed,
            projectionUpdatedAt: source.projectionUpdatedAt,
          ),
        ),
      );
      return null;
    }
    final binding = await _sessionRepository.insertObservedChild(
      pluginId: source.pluginId,
      observed: observed,
      parent: parent,
      projectionUpdatedAt: source.projectionUpdatedAt,
    );
    return binding == null ? null : (binding: binding, inserted: true);
  }

  Future<List<BridgeSseEvent>> _drainPendingForBinding({
    required String pluginId,
    required String backendSessionId,
  }) async {
    final output = <BridgeSseEvent>[];
    final readyBindings = {
      (pluginId: pluginId, backendSessionId: backendSessionId),
    };
    while (true) {
      final pending = _eventTracker.takeNextReady(readyBindings: readyBindings);
      if (pending == null) break;
      output.addAll(
        await _normalizeGuarded(
          source: (
            pluginId: pending.pluginId,
            projectionUpdatedAt: pending.projectionUpdatedAt,
            event: pending.event,
          ),
          drainPending: false,
        ),
      );
      if (pending is PendingSessionEvent) {
        final binding = await _sessionRepository.getStoredSessionByBackendId(
          pluginId: pending.pluginId,
          backendSessionId: pending.session.id,
        );
        if (binding != null) {
          readyBindings.add((
            pluginId: pending.pluginId,
            backendSessionId: pending.session.id,
          ));
        }
      }
    }
    return output;
  }

  void _warnIfEvicted({required PendingTrackedEvent? evicted}) {
    if (evicted == null) return;
    Log.w(
      "Dropping pending session event ${evicted.pluginId}/${evicted.backendSessionId}: "
      "the ${_eventTracker.maxPendingEntries}-event ancestry buffer is full",
    );
  }

  Future<BridgeSseEvent?> _translate({required SourcedBridgeEvent source}) async {
    final backendSessionIds = _eventMapper.backendSessionIds(event: source.event);
    final bindings = await _sessionRepository.getStoredSessionsByBackendIds(
      pluginId: source.pluginId,
      backendSessionIds: backendSessionIds.toList(growable: false),
    );
    if (bindings.length != backendSessionIds.length) {
      final missingBackendSessionIds = backendSessionIds.where((id) => !bindings.containsKey(id)).toList();
      if (missingBackendSessionIds.isNotEmpty &&
          missingBackendSessionIds.every(
            (id) => _eventTracker.isBindingPending(
              pluginId: source.pluginId,
              backendSessionId: id,
            ),
          )) {
        _warnIfEvicted(
          evicted: _eventTracker.addTranslation(
            event: PendingTranslationEvent(
              pluginId: source.pluginId,
              event: source.event,
              backendSessionId: missingBackendSessionIds.first,
              projectionUpdatedAt: source.projectionUpdatedAt,
            ),
          ),
        );
      }
      return null;
    }
    final translated = _eventMapper.map(
      event: source.event,
      sessionIdsByBackendId: {
        for (final entry in bindings.entries) entry.key: entry.value.id,
      },
    );
    if (translated == null) return null;

    final translatedSession = _eventMapper.sessionInfo(event: translated);
    return switch (translated) {
      BridgeSseSessionCreated() => switch (translatedSession) {
        final session? => switch (await _catalogSession(session: session)) {
          final catalogSession? => BridgeSseSessionCreated(info: catalogSession.toJson()),
          null => null,
        },
        null => null,
      },
      BridgeSseSessionUpdated(:final titleChanged) => switch (translatedSession) {
        final session? => await _enrichUpdatedSession(session: session, titleChanged: titleChanged),
        null => null,
      },
      BridgeSseSessionsUpdated(:final sessionID) => switch (await _sessionRepository.findProjectIdForSession(
        sessionId: sessionID,
      )) {
        final projectId? => BridgeSseSessionsUpdated(sessionID: sessionID, projectID: projectId),
        null => null,
      },
      _ => translated,
    };
  }

  Future<BridgeSseEvent?> _enrichUpdatedSession({
    required Session session,
    required bool titleChanged,
  }) async {
    if (titleChanged) {
      await _sessionMutationDispatcher.captureTitle(
        sessionId: session.id,
        title: session.title,
      );
    }
    final catalogSession = await _sessionRepository.getCatalogSession(sessionId: session.id);
    if (catalogSession == null) return null;
    return BridgeSseSessionUpdated(info: catalogSession.toJson(), titleChanged: titleChanged);
  }

  Future<Session?> _catalogSession({required Session session}) {
    return _sessionRepository.getCatalogSession(
      sessionId: session.id,
    );
  }

  Future<BridgeSseEvent?> _createdEvent({required String sessionId}) async {
    final session = await _sessionRepository.getCatalogSession(sessionId: sessionId);
    return session == null ? null : BridgeSseSessionCreated(info: session.toJson());
  }
}
