import "dart:async";

import "package:meta/meta.dart";

import "bridge_sse_event.dart";
import "log.dart";
import "models/plugin_pending_permission.dart";
import "models/plugin_pending_question.dart";
import "plugin_permission_reply.dart";

enum PendingCancellationReason() { sessionCancelled, disposed }

enum PendingQuestionReplyOutcome() { replied, rejected }

typedef PendingPermissionResolver<TPayload extends Object> = void Function({
  required TPayload payload,
  required PluginPermissionReply reply,
});
typedef PendingQuestionResolver<TPayload extends Object> = PendingQuestionReplyOutcome Function({
  required TPayload payload,
  required List<List<String>> answers,
});
typedef PendingQuestionRejecter<TPayload extends Object> = void Function({required TPayload payload});
typedef PendingInputCanceller<TPayload extends Object> = void Function({
  required TPayload payload,
  required PendingCancellationReason reason,
});

/// Shared pending-input state and lifecycle for bridge plugin implementations.
///
/// Backend request parsing and response payloads belong in subclasses. This
/// registry stores their opaque payloads alongside the exact contract snapshots
/// surfaced to clients.
abstract class PendingPermissionRegistry<TRequest, TPayload extends Object>({
  required void Function(BridgeSseEvent event) emit,
  required String logContext,
  required PendingPermissionResolver<TPayload> resolvePermission,
  required PendingQuestionResolver<TPayload> resolveQuestion,
  required PendingQuestionRejecter<TPayload> rejectQuestion,
  required PendingInputCanceller<TPayload> cancelPending,
  String Function()? idGenerator,
}) {
  final void Function(BridgeSseEvent event) _emit = emit;
  final String _logContext = logContext;
  final String Function()? _injectedIdGenerator = idGenerator;
  final PendingPermissionResolver<TPayload> _resolvePermission = resolvePermission;
  final PendingQuestionResolver<TPayload> _resolveQuestion = resolveQuestion;
  final PendingQuestionRejecter<TPayload> _rejectQuestion = rejectQuestion;
  final PendingInputCanceller<TPayload> _cancelPending = cancelPending;

  StreamSubscription<TRequest>? _subscription;
  final Map<String, _PendingEntry<TPayload>> _pending = {};
  int _sequence = 0;

  @protected
  void handleRequest(TRequest request);

  @protected
  String registerPendingPermission({
    required TPayload payload,
    required String sessionId,
    required String? displaySessionId,
    required String tool,
    required String description,
    required bool allowAlways,
  }) {
    final id = _generateId();
    final snapshot = PluginPendingPermission(
      id: id,
      sessionID: sessionId,
      displaySessionId: displaySessionId,
      tool: tool,
      description: description,
      allowAlways: allowAlways,
    );
    _pending[id] = _PendingPermissionEntry(payload: payload, snapshot: snapshot);
    _emit(
      BridgeSsePermissionAsked(
        requestID: id,
        sessionID: sessionId,
        displaySessionId: displaySessionId,
        tool: tool,
        description: description,
        allowAlways: allowAlways,
      ),
    );
    return id;
  }

  @protected
  String registerPendingQuestion({
    required TPayload payload,
    required String sessionId,
    required String? displaySessionId,
    required List<PluginQuestionInfo> questions,
  }) {
    final id = _generateId();
    final snapshot = PluginPendingQuestion(
      id: id,
      sessionID: sessionId,
      displaySessionId: displaySessionId,
      questions: questions,
    );
    _pending[id] = _PendingQuestionEntry(payload: payload, snapshot: snapshot);
    _emit(
      BridgeSseQuestionAsked(
        id: id,
        sessionID: sessionId,
        displaySessionId: displaySessionId,
        questions: questions,
      ),
    );
    return id;
  }

  StreamSubscription<TRequest> attach({required Stream<TRequest> stream}) {
    final subscription = stream.listen(handleRequest);
    _subscription = subscription;
    return subscription;
  }

  Future<void> dispose() async {
    try {
      await _subscription?.cancel();
    } on Object catch (error, stack) {
      Log.w("$_logContext failed to cancel pending-input subscription", error, stack);
    }
    _subscription = null;
    final remaining = List<_PendingEntry<TPayload>>.from(_pending.values);
    _pending.clear();
    for (final entry in remaining) {
      _settleCancelled(entry: entry, reason: PendingCancellationReason.disposed);
    }
  }

  List<PluginPendingQuestion> pendingForSession({required String sessionId}) => [
    for (final entry in _pending.values)
      if (entry case _PendingQuestionEntry<TPayload>(:final snapshot) when snapshot.sessionID == sessionId) snapshot,
  ];

  List<PluginPendingPermission> pendingPermissionsForSession({required String sessionId}) => [
    for (final entry in _pending.values)
      if (entry case _PendingPermissionEntry<TPayload>(:final snapshot) when snapshot.sessionID == sessionId) snapshot,
  ];

  List<PluginPendingQuestion> pendingForProject({required Iterable<String> sessionIds}) {
    final sessionIdSet = Set<String>.from(sessionIds);
    return [
      for (final entry in _pending.values)
        if (entry case _PendingQuestionEntry<TPayload>(:final snapshot) when sessionIdSet.contains(snapshot.sessionID))
          snapshot,
    ];
  }

  bool hasPendingInput({required String sessionId}) => _pending.values.any((entry) => entry.sessionId == sessionId);

  bool get hasAnyPendingInput => _pending.isNotEmpty;

  Set<String> get pendingSessionIds => Set<String>.unmodifiable(_pending.values.map((entry) => entry.sessionId));

  void cancelForSession({required String sessionId}) {
    final entries = _pending.values.where((entry) => entry.sessionId == sessionId).toList(growable: false);
    for (final entry in entries) {
      _pending.remove(entry.id);
      _settleCancelled(entry: entry, reason: PendingCancellationReason.sessionCancelled);
    }
  }

  bool replyPermission({required String requestId, required PluginPermissionReply reply}) {
    // Peek before removing: a question id routed here must stay pending so the
    // agent still gets an answer instead of blocking on a destroyed entry.
    final entry = _pending[requestId];
    if (entry is! _PendingPermissionEntry<TPayload>) return false;
    _pending.remove(requestId);
    _resolvePermission(payload: entry.payload, reply: reply);
    final snapshot = entry.snapshot;
    _emit(
      BridgeSsePermissionReplied(
        requestID: requestId,
        sessionID: snapshot.sessionID,
        displaySessionId: snapshot.displaySessionId,
        reply: reply.name,
      ),
    );
    return true;
  }

  bool replyQuestion({required String requestId, required List<List<String>> answers}) {
    final entry = _pending[requestId];
    if (entry is! _PendingQuestionEntry<TPayload>) return false;
    _pending.remove(requestId);
    final outcome = _resolveQuestion(payload: entry.payload, answers: answers);
    final snapshot = entry.snapshot;
    _emit(
      switch (outcome) {
        PendingQuestionReplyOutcome.replied => BridgeSseQuestionReplied(
          requestID: requestId,
          sessionID: snapshot.sessionID,
          displaySessionId: snapshot.displaySessionId,
        ),
        PendingQuestionReplyOutcome.rejected => BridgeSseQuestionRejected(
          requestID: requestId,
          sessionID: snapshot.sessionID,
          displaySessionId: snapshot.displaySessionId,
        ),
      },
    );
    return true;
  }

  bool rejectQuestion({required String requestId}) {
    final entry = _pending[requestId];
    if (entry is! _PendingQuestionEntry<TPayload>) return false;
    _pending.remove(requestId);
    _rejectQuestion(payload: entry.payload);
    final snapshot = entry.snapshot;
    _emit(
      BridgeSseQuestionRejected(
        requestID: requestId,
        sessionID: snapshot.sessionID,
        displaySessionId: snapshot.displaySessionId,
      ),
    );
    return true;
  }

  String _generateId() {
    final injected = _injectedIdGenerator;
    if (injected != null) return injected();
    _sequence++;
    return "br-$_sequence";
  }

  void _settleCancelled({
    required _PendingEntry<TPayload> entry,
    required PendingCancellationReason reason,
  }) {
    try {
      _cancelPending(payload: entry.payload, reason: reason);
    } on Object catch (error, stack) {
      Log.w("$_logContext failed to resolve cancelled pending input", error, stack);
    }
    try {
      _emit(entry.cancellationEvent);
    } on Object catch (error, stack) {
      Log.w("$_logContext failed to emit cancelled pending-input event", error, stack);
    }
  }
}

sealed class const _PendingEntry<TPayload extends Object>() {
  TPayload get payload;
  String get id;
  String get sessionId;
  BridgeSseEvent get cancellationEvent;
}

class const _PendingPermissionEntry<TPayload extends Object>({
  @override required final TPayload payload,
  required final PluginPendingPermission snapshot,
}) extends _PendingEntry<TPayload> {
  @override
  String get id => snapshot.id;

  @override
  String get sessionId => snapshot.sessionID;

  @override
  BridgeSseEvent get cancellationEvent => BridgeSsePermissionReplied(
    requestID: snapshot.id,
    sessionID: snapshot.sessionID,
    displaySessionId: snapshot.displaySessionId,
    reply: PluginPermissionReply.reject.name,
  );
}

class const _PendingQuestionEntry<TPayload extends Object>({
  @override required final TPayload payload,
  required final PluginPendingQuestion snapshot,
}) extends _PendingEntry<TPayload> {
  @override
  String get id => snapshot.id;

  @override
  String get sessionId => snapshot.sessionID;

  @override
  BridgeSseEvent get cancellationEvent => BridgeSseQuestionRejected(
    requestID: snapshot.id,
    sessionID: snapshot.sessionID,
    displaySessionId: snapshot.displaySessionId,
  );
}
