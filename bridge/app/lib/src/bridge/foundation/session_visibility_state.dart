import "dart:async";

typedef SessionVisibilitySnapshot = ({int version, List<String> unpublishedSessionIds});

final class SessionCreationReservation {
  SessionCreationReservation._({
    required _PluginVisibilityState pluginState,
    required Future<void> catalogWritesFinished,
  }) : _pluginState = pluginState,
       _catalogWritesFinished = catalogWritesFinished;
  final _PluginVisibilityState _pluginState;
  final Future<void> _catalogWritesFinished;
}

final class UnpublishedSessionReservation {
  UnpublishedSessionReservation._({required this.sessionId});
  final String sessionId;
  bool _active = true;
  bool get isActive => _active;
}

/// Orders catalog writes against process-local unpublished bindings, which are visible after restart.
class SessionVisibilityState {
  final Set<String> _unpublishedSessionIds = <String>{};
  final Map<String, _PluginVisibilityState> _pluginStates = <String, _PluginVisibilityState>{};
  int _version = 0;
  SessionVisibilitySnapshot get snapshot => (
    version: _version,
    unpublishedSessionIds: List<String>.unmodifiable(_unpublishedSessionIds),
  );
  bool isSnapshotCurrent({required SessionVisibilitySnapshot snapshot}) => snapshot.version == _version;
  bool isPublished({required String sessionId}) => !_unpublishedSessionIds.contains(sessionId);
  SessionCreationReservation reserveSessionCreation({required String pluginId}) {
    final pluginState = _pluginStates.putIfAbsent(pluginId, _PluginVisibilityState.new);
    final catalogWritesFinished = pluginState.activeCatalogWrites == 0
        ? Future<void>.value()
        : pluginState.catalogWritesFinished!.future;
    pluginState.creationReservations++;
    pluginState.creationReservationsFinished ??= Completer<void>();
    return SessionCreationReservation._(pluginState: pluginState, catalogWritesFinished: catalogWritesFinished);
  }
  void releaseSessionCreation({required SessionCreationReservation reservation}) {
    final pluginState = reservation._pluginState;
    pluginState.creationReservations--;
    if (pluginState.creationReservations != 0) return;
    pluginState.creationReservationsFinished!.complete();
    pluginState.creationReservationsFinished = null;
  }

  Future<T> withSessionCreationCommit<T>({
    required SessionCreationReservation reservation,
    required Future<T> Function() body,
  }) async {
    await reservation._catalogWritesFinished;
    final pluginState = reservation._pluginState;
    final predecessor = pluginState.creationCommitTail;
    final released = Completer<void>();
    pluginState.creationCommitTail = released.future;
    await predecessor;
    try {
      return await body();
    } finally {
      released.complete();
    }
  }

  Future<T> withCatalogWrite<T>({required String pluginId, required Future<T> Function() body}) async {
    final pluginState = _pluginStates.putIfAbsent(pluginId, _PluginVisibilityState.new);
    while (pluginState.creationReservations > 0) {
      await pluginState.creationReservationsFinished!.future;
    }
    pluginState.activeCatalogWrites++;
    pluginState.catalogWritesFinished ??= Completer<void>();
    try {
      return await body();
    } finally {
      pluginState.activeCatalogWrites--;
      if (pluginState.activeCatalogWrites == 0) {
        pluginState.catalogWritesFinished!.complete();
        pluginState.catalogWritesFinished = null;
      }
    }
  }

  UnpublishedSessionReservation? beginUnpublishedSession({required String sessionId}) {
    if (!_unpublishedSessionIds.add(sessionId)) return null;
    _version++;
    return UnpublishedSessionReservation._(sessionId: sessionId);
  }

  bool completeUnpublishedSession({required UnpublishedSessionReservation reservation}) {
    if (!reservation._active) return false;
    reservation._active = false;
    if (!_unpublishedSessionIds.remove(reservation.sessionId)) {
      throw StateError("Unpublished session reservation lost its visibility marker");
    }
    _version++;
    return true;
  }
}

class _PluginVisibilityState {
  int creationReservations = 0;
  Completer<void>? creationReservationsFinished;
  int activeCatalogWrites = 0;
  Completer<void>? catalogWritesFinished;
  Future<void> creationCommitTail = Future<void>.value();
}
