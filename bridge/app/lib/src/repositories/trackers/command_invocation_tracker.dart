import "dart:collection";

import "package:sesori_shared/sesori_shared.dart";

/// The commands this bridge sent, by prompt id, so the user message that
/// fulfils one can be named when its echo arrives.
///
/// Plugin queues live in this process, so nothing here needs to survive a
/// restart: the history store keeps an invocation once its echo was stamped.
/// The oldest entry is evicted past [capacity]; an echo arrives within one
/// turn of its send, long before that many newer commands.
class CommandInvocationTracker() {
  static const capacity = 256;

  final LinkedHashMap<({String sessionId, String promptId}), CommandInvocation> _invocations = LinkedHashMap();

  /// Records [invocation] as the command [promptId] sent to [sessionId].
  void record({
    required String sessionId,
    required String promptId,
    required CommandInvocation invocation,
  }) {
    final key = (sessionId: sessionId, promptId: promptId);
    _invocations.remove(key);
    _invocations[key] = invocation;
    while (_invocations.length > capacity) {
      _invocations.remove(_invocations.keys.first);
    }
  }

  /// Forgets the command [promptId] sent to [sessionId].
  void remove({required String sessionId, required String promptId}) =>
      _invocations.remove((sessionId: sessionId, promptId: promptId));

  /// The command [promptId] sent to [sessionId], when this bridge sent one.
  CommandInvocation? invocationFor({required String sessionId, required String promptId}) =>
      _invocations[(sessionId: sessionId, promptId: promptId)];
}
