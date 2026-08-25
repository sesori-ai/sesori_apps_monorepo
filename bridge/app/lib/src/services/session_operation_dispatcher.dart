import "dart:async";

import "package:meta/meta.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";

typedef _FamilyKey = ({String pluginId, String rootSessionId});

/// Admits session work in arrival order, then serializes only shared domains.
class SessionOperationDispatcher({required final SessionRepository _sessionRepository}) {
  final Map<_FamilyKey, _LaneToken> _familyLanes = {};
  final Set<Future<void>> _inFlightSettlements = {};

  Future<void> _resolutionTail = Future<void>.value();
  Future<void>? _drainFuture;
  var _accepting = true;
  var _disposed = false;

  Future<T> dispatch<T>({
    required String sessionId,
    required SessionOperation operation,
    required Future<T> Function() body,
  }) {
    if (!_accepting) throw _closedError();

    final result = Completer<T>();
    _track(result: result);
    _enqueueResolution(
      action: () async {
        final family = await _sessionRepository.resolveSessionFamily(
          sessionId: sessionId,
          operation: operation,
        );
        _registerOperation(
          family: family,
          body: body,
          result: result,
        );
      },
      onError: result.completeError,
    );
    return result.future;
  }

  void beginShutdown() {
    _accepting = false;
  }

  Future<void> drain() => _drainFuture ??= _drain();

  Future<void> dispose() {
    _disposed = true;
    return drain();
  }

  @visibleForTesting
  int get activeLaneCount => _familyLanes.length;

  Future<void> _drain() async {
    beginShutdown();
    await _resolutionTail;
    await Future.wait(_inFlightSettlements.toList(growable: false));
  }

  StateError _closedError() {
    final state = _disposed ? "disposed" : "closed";
    return StateError("SessionOperationDispatcher is $state");
  }

  void _enqueueResolution({
    required FutureOr<void> Function() action,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    final previous = _resolutionTail;
    final release = Completer<void>();
    _resolutionTail = release.future;
    unawaited(() async {
      await previous;
      try {
        await action();
      } on Object catch (error, stackTrace) {
        onError(error, stackTrace);
      } finally {
        release.complete();
      }
    }());
  }

  void _registerOperation<T>({
    required SessionFamilyScope family,
    required Future<T> Function() body,
    required Completer<T> result,
  }) {
    final familyKey = (pluginId: family.pluginId, rootSessionId: family.rootSessionId);
    final predecessor = _familyLanes[familyKey]?.completion.future ?? Future<void>.value();
    final token = _LaneToken();
    _familyLanes[familyKey] = token;

    unawaited(() async {
      await predecessor;
      try {
        result.complete(await body());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        token.completion.complete();
        if (identical(_familyLanes[familyKey], token)) _familyLanes.remove(familyKey);
      }
    }());
  }

  void _track<T>({required Completer<T> result}) {
    late final Future<void> settlement;
    settlement = result.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}).whenComplete(() {
      _inFlightSettlements.remove(settlement);
    });
    _inFlightSettlements.add(settlement);
  }
}

class _LaneToken() {
  final Completer<void> completion = Completer<void>();
}
