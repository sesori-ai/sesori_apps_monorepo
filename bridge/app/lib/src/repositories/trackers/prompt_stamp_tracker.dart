import "dart:collection";

import "package:sesori_shared/sesori_shared.dart";

import "prompt_stamp.dart";

/// The stamps of prompts this bridge sent, by prompt id, so the user message
/// that fulfils one can be stamped when its echo arrives, and of the summary
/// requests a send marked as not sent, by message id, for updates that name
/// no prompt.
///
/// Plugin queues live in this process, so nothing here needs to survive a
/// restart: the history store keeps a stamp once its echo was stamped. The
/// oldest entry is evicted past [capacity]; an echo arrives within one turn of
/// its send, long before that many newer stamped prompts.
class PromptStampTracker() {
  static const capacity = 256;

  final LinkedHashMap<({String sessionId, String promptId}), PromptStamp> _stamps = LinkedHashMap();
  final LinkedHashMap<({String sessionId, String messageId}), MessageHandoffNotSent> _notSentRequests = LinkedHashMap();

  /// Records [stamp] for the prompt [promptId] sent to [sessionId].
  void record({
    required String sessionId,
    required String promptId,
    required PromptStamp stamp,
  }) {
    _put(map: _stamps, key: (sessionId: sessionId, promptId: promptId), value: stamp);
  }

  /// Records that the summary request [messageId] of [sessionId] was not sent.
  void recordNotSentRequest({
    required String sessionId,
    required String messageId,
    required MessageHandoffNotSent notSent,
  }) => _put(map: _notSentRequests, key: (sessionId: sessionId, messageId: messageId), value: notSent);

  /// The not-sent stamp recorded for the summary request [messageId] of
  /// [sessionId], if any.
  MessageHandoffNotSent? notSentRequestFor({required String sessionId, required String messageId}) =>
      _notSentRequests[(sessionId: sessionId, messageId: messageId)];

  static void _put<K, V>({required LinkedHashMap<K, V> map, required K key, required V value}) {
    map.remove(key);
    map[key] = value;
    while (map.length > capacity) {
      map.remove(map.keys.first);
    }
  }

  /// Forgets the stamp of the prompt [promptId] sent to [sessionId].
  void remove({required String sessionId, required String promptId}) =>
      _stamps.remove((sessionId: sessionId, promptId: promptId));

  /// The stamp of the prompt [promptId] sent to [sessionId], when this bridge
  /// recorded one.
  PromptStamp? stampFor({required String sessionId, required String promptId}) =>
      _stamps[(sessionId: sessionId, promptId: promptId)];
}
