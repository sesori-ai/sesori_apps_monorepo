import "dart:async";

import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";

sealed class PendingInteractionRequest {
  final String requestId;

  const PendingInteractionRequest({required this.requestId});
}

final class PendingPermissionInteraction extends PendingInteractionRequest {
  const PendingPermissionInteraction({required super.requestId});
}

final class PendingQuestionInteraction extends PendingInteractionRequest {
  const PendingQuestionInteraction({required super.requestId});
}

enum _PendingInteractionKind { permission, question }

typedef _FamilyKey = ({String pluginId, String rootSessionId});
typedef _InteractionKey = ({
  String pluginId,
  String ownerSessionId,
  _PendingInteractionKind kind,
  String requestId,
});

/// Admits session work in arrival order, then serializes only shared domains.
class SessionOperationDispatcher {
  final SessionRepository _sessionRepository;
  final Map<_FamilyKey, _LaneToken> _familyLanes = {};
  final Map<_InteractionKey, _LaneToken> _interactionLanes = {};
  final Map<String, _LaneToken> _pluginAdmissionLanes = {};
  final Map<String, Set<Future<void>>> _pluginSettlements = {};
  final Set<Future<void>> _inFlightSettlements = {};

  Future<void> _resolutionTail = Future<void>.value();
  Future<void>? _drainFuture;
  var _nextTicket = 0;
  var _accepting = true;
  var _disposed = false;

  SessionOperationDispatcher({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Future<T> dispatch<T>({
    required String sessionId,
    required SessionOperation operation,
    required PendingInteractionRequest? interaction,
    required Future<T> Function() body,
  }) {
    if (!_accepting) throw _closedError();

    final ticket = _nextTicket++;
    final result = Completer<T>();
    _track(result: result);
    _enqueueResolution(
      ticket: ticket,
      action: () async {
        final family = await _sessionRepository.resolveSessionFamily(
          sessionId: sessionId,
          operation: operation,
        );
        _enqueuePluginAdmission(
          pluginId: family.pluginId,
          ticket: ticket,
          action: () {
            _registerOperation(
              ticket: ticket,
              family: family,
              ownerSessionId: sessionId,
              interaction: interaction,
              body: body,
              result: result,
            );
          },
          onError: result.completeError,
        );
      },
      onError: result.completeError,
    );
    return result.future;
  }

  /// Queues a sessionless question ticket synchronously. Its plugin admission
  /// waits for prior plugin work, then blocks later admissions while resolving.
  Future<T> dispatchLegacyQuestion<T>({
    required String pluginId,
    required String questionId,
    required SessionOperation operation,
    required Future<String> Function() resolveOwnerSessionId,
    required Future<T> Function({required String ownerSessionId}) body,
  }) {
    if (!_accepting) throw _closedError();

    final ticket = _nextTicket++;
    final result = Completer<T>();
    _track(result: result);
    _enqueueResolution(
      ticket: ticket,
      action: () {
        _enqueuePluginAdmission(
          pluginId: pluginId,
          ticket: ticket,
          action: () async {
            await Future.wait(_pluginSettlements[pluginId]?.toList(growable: false) ?? const []);
            final ownerSessionId = await resolveOwnerSessionId();
            final family = await _sessionRepository.resolveSessionFamily(
              sessionId: ownerSessionId,
              operation: operation,
            );
            if (family.pluginId != pluginId) {
              throw PluginOperationException(
                operation.name,
                statusCode: 409,
                message: "question $questionId resolved to plugin ${family.pluginId}, expected $pluginId",
              );
            }
            _registerOperation(
              ticket: ticket,
              family: family,
              ownerSessionId: ownerSessionId,
              interaction: PendingQuestionInteraction(requestId: questionId),
              body: () => body(ownerSessionId: ownerSessionId),
              result: result,
            );
          },
          onError: result.completeError,
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
  int get activeLaneCount => _familyLanes.length + _interactionLanes.length + _pluginAdmissionLanes.length;

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
    required int ticket,
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

  void _enqueuePluginAdmission({
    required String pluginId,
    required int ticket,
    required FutureOr<void> Function() action,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    final previous = _pluginAdmissionLanes[pluginId]?.completion.future ?? Future<void>.value();
    final token = _LaneToken(ticket: ticket);
    _pluginAdmissionLanes[pluginId] = token;
    unawaited(() async {
      await previous;
      try {
        await action();
      } on Object catch (error, stackTrace) {
        onError(error, stackTrace);
      } finally {
        token.completion.complete();
        if (identical(_pluginAdmissionLanes[pluginId], token)) {
          _pluginAdmissionLanes.remove(pluginId);
        }
      }
    }());
  }

  void _registerOperation<T>({
    required int ticket,
    required SessionFamilyScope family,
    required String ownerSessionId,
    required PendingInteractionRequest? interaction,
    required Future<T> Function() body,
    required Completer<T> result,
  }) {
    final familyKey = (pluginId: family.pluginId, rootSessionId: family.rootSessionId);
    final predecessors = <Future<void>>[
      _familyLanes[familyKey]?.completion.future ?? Future<void>.value(),
    ];
    final token = _LaneToken(ticket: ticket);
    _familyLanes[familyKey] = token;

    final interactionKey = interaction == null
        ? null
        : (
            pluginId: family.pluginId,
            ownerSessionId: ownerSessionId,
            kind: switch (interaction) {
              PendingPermissionInteraction() => _PendingInteractionKind.permission,
              PendingQuestionInteraction() => _PendingInteractionKind.question,
            },
            requestId: interaction.requestId,
          );
    if (interactionKey != null) {
      predecessors.add(
        _interactionLanes[interactionKey]?.completion.future ?? Future<void>.value(),
      );
      _interactionLanes[interactionKey] = token;
    }
    _trackPlugin(result: result, pluginId: family.pluginId);

    unawaited(() async {
      await Future.wait(predecessors);
      try {
        result.complete(await body());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        token.completion.complete();
        if (identical(_familyLanes[familyKey], token)) _familyLanes.remove(familyKey);
        if (interactionKey != null && identical(_interactionLanes[interactionKey], token)) {
          _interactionLanes.remove(interactionKey);
        }
      }
    }());
  }

  void _track<T>({required Completer<T> result}) {
    late final Future<void> settlement;
    settlement = result.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}).whenComplete(() {
      _inFlightSettlements.remove(settlement);
    });
    _inFlightSettlements.add(settlement);
  }

  void _trackPlugin<T>({required Completer<T> result, required String pluginId}) {
    late final Future<void> settlement;
    settlement = result.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}).whenComplete(() {
      final settlements = _pluginSettlements[pluginId];
      settlements?.remove(settlement);
      if (settlements?.isEmpty ?? false) _pluginSettlements.remove(pluginId);
    });
    (_pluginSettlements[pluginId] ??= {}).add(settlement);
  }
}

class _LaneToken {
  final int ticket;
  final Completer<void> completion = Completer<void>();

  _LaneToken({required this.ticket});
}
