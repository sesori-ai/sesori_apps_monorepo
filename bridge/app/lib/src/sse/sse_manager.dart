import "dart:async";
import "dart:collection";
import "dart:convert";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/relay_client.dart";
import "sse_event_delivery.dart";

/// One connection's queue plus the attachment shape it subscribed with.
typedef _SubscriberQueue = ({
  EventQueue<SesoriSseEvent> queue,
  MessageAttachmentDelivery attachmentDelivery,
});

typedef _OrphanQueue = ({
  EventQueue<SesoriSseEvent> queue,
  MessageAttachmentDelivery attachmentDelivery,
  DateTime expiry,
});

class SSEManager({
  /// How long a disconnected subscriber's orphan queue stays valid.
  required final Duration replayWindow,
  required final void Function(int bytes) _onBytesSent,
  required final FailureReporter _failureReporter,
  required final SessionEncryptor _encryptor,
}) {
  /// Default duration for which orphan queues remain valid after a phone
  /// disconnects. Referenced by the CLI entry point and tests.
  static const Duration defaultReplayWindow = sseReplayWindow;

  /// Maximum number of events retained per subscriber queue.
  static const int maxQueueSize = 50000;

  final Map<int, _SubscriberQueue> _subscribers = {};
  final Map<int, EventQueueSubscription<SesoriSseEvent>> _subscriptions = {};
  final Map<int, Object> _subscriptionOwners = {};
  final Queue<_OrphanQueue> _orphanQueues = Queue<_OrphanQueue>();

  /// Registers [connID] as an SSE subscriber.
  ///
  /// [path] is accepted for API compatibility with call sites but is not used
  /// by this manager.
  ///
  /// [attachmentDelivery] selects which attachment shape this connection
  /// receives and stays with its queue: only an orphan queued for the same
  /// mode is adopted, so a replayed event can never hand a stored reference to
  /// a subscriber that asked for inline data.
  void subscribePath({
    required int connID,
    required String path,
    required RelayClient client,
    required RelayConnection connection,
    required MessageAttachmentDelivery attachmentDelivery,
  }) {
    final orphan = _popValidOrphan(attachmentDelivery: attachmentDelivery);
    final subscriptionOwner = Object();
    _subscriptionOwners[connID] = subscriptionOwner;

    try {
      final subscriber =
          orphan ??
          (
            queue: EventQueue<SesoriSseEvent>(maxSize: maxQueueSize),
            attachmentDelivery: attachmentDelivery,
          );
      _subscriptions[connID] = subscriber.queue.listen(
        _createSendFunction(
          connID: connID,
          client: client,
          connection: connection,
          subscriptionOwner: subscriptionOwner,
        ),
        onError: _createErrorHandler(connID),
      );
      _subscribers[connID] = subscriber;
    } on Object {
      if (identical(_subscriptionOwners[connID], subscriptionOwner)) {
        _subscriptionOwners.remove(connID);
      }
      rethrow;
    }
  }

  /// Removes [connID] from active subscribers.
  ///
  /// The queue is paused and retained as an orphan queue for replay during
  /// [replayWindow]. If the phone reconnects within that window, the orphan
  /// is resumed via [subscribePath] and all buffered events are delivered.
  void unsubscribe(int connID) {
    _subscriptionOwners.remove(connID);
    final subscriber = _subscribers.remove(connID);
    _subscriptions.remove(connID)?.cancel();
    if (subscriber == null) return;

    _orphanQueues.addLast((
      queue: subscriber.queue,
      attachmentDelivery: subscriber.attachmentDelivery,
      expiry: clock.now().add(replayWindow),
    ));
  }

  /// Alias for [unsubscribe].

  /// Pauses all active subscriber queues and moves them to orphan state.
  ///
  /// Use this when the relay connection drops but may recover. Orphan queues
  /// continue to buffer incoming events and will be replayed when phones
  /// reconnect within [replayWindow].
  void orphanAll() {
    for (final entry in _subscribers.entries) {
      _subscriptions.remove(entry.key)?.cancel();
      _orphanQueues.addLast((
        queue: entry.value.queue,
        attachmentDelivery: entry.value.attachmentDelivery,
        expiry: clock.now().add(replayWindow),
      ));
    }
    _subscribers.clear();
    _subscriptionOwners.clear();
  }

  /// Clears all subscribers and orphan state.
  void stop() {
    _subscriptions.clear();
    for (final sub in _subscribers.values) {
      sub.queue.dispose();
    }
    _subscribers.clear();
    _subscriptionOwners.clear();
    _disposeOrphans();
  }

  /// Current number of active subscribers.
  int get subscriberCount => _subscribers.length;

  /// Number of orphan queues from disconnected subscribers.
  int get pendingReplayCount => _orphanQueues.length;

  /// Enqueues [delivery] into all active and non-expired orphan queues, giving
  /// each queue the shape its own subscription asked for.
  void enqueueEvent(SseEventDelivery delivery) {
    for (final subscriber in _subscribers.values) {
      subscriber.queue.enqueue(delivery.eventFor(delivery: subscriber.attachmentDelivery));
    }

    _purgeExpiredOrphans();
    for (final orphan in _orphanQueues) {
      orphan.queue.enqueue(delivery.eventFor(delivery: orphan.attachmentDelivery));
    }
  }

  void _disposeOrphans() {
    for (final orphan in _orphanQueues) {
      orphan.queue.dispose();
    }
    _orphanQueues.clear();
  }

  /// The oldest live orphan queued for [attachmentDelivery], if any.
  ///
  /// Expired queues are dropped on the way; live queues for another delivery
  /// mode are kept for the reconnect they belong to.
  _SubscriberQueue? _popValidOrphan({required MessageAttachmentDelivery attachmentDelivery}) {
    final now = clock.now();
    _OrphanQueue? adopted;
    final retained = Queue<_OrphanQueue>();
    while (_orphanQueues.isNotEmpty) {
      final oldest = _orphanQueues.removeFirst();
      if (!oldest.expiry.isAfter(now)) {
        oldest.queue.dispose();
        continue;
      }
      if (adopted == null && oldest.attachmentDelivery == attachmentDelivery) {
        adopted = oldest;
        continue;
      }
      retained.addLast(oldest);
    }
    _orphanQueues.addAll(retained);
    return adopted == null ? null : (queue: adopted.queue, attachmentDelivery: adopted.attachmentDelivery);
  }

  void Function(SesoriSseEvent, Object) _createErrorHandler(int connID) {
    return (event, error) {
      if (error is _StaleRelayConnectionException) {
        Log.v("[sse] retaining event ${event.runtimeType} for connID=$connID after relay turnover");
        return;
      }
      Log.w("[sse] failed to send event ${event.runtimeType} to connID=$connID: $error");
      unawaited(
        _failureReporter
            .recordFailure(
              error: error,
              stackTrace: StackTrace.current,
              uniqueIdentifier: "sse_send_failure:$connID",
              fatal: false,
              reason: "Failed to send SSE event to phone",
              information: [event.runtimeType.toString(), "connID=$connID"],
            )
            .catchError((_) {}),
      );
    };
  }

  Future<void> Function(SesoriSseEvent) _createSendFunction({
    required int connID,
    required RelayClient client,
    required RelayConnection connection,
    required Object subscriptionOwner,
  }) {
    return (SesoriSseEvent event) async {
      Log.v("[sse] dequeuing event for connID=$connID: ${event.runtimeType}");
      final eventData = jsonEncode(_toOpenCodeFormat(event));
      final relayMessage = RelayMessage.sseEvent(data: eventData);
      final payloadBytes = utf8.encode(jsonEncode(relayMessage.toJson()));
      Log.v("[sse] sending ${payloadBytes.length} bytes to connID=$connID");
      final framed = await frame(payloadBytes, encryptor: _encryptor);
      final outcome = client.sendIfCurrent(
        connection: connection,
        connID: connID,
        payload: framed,
      );
      if (outcome == RelaySendOutcome.stale) {
        _unsubscribeIfOwned(connID: connID, subscriptionOwner: subscriptionOwner);
        throw const _StaleRelayConnectionException();
      }
      _onBytesSent(payloadBytes.length);
    };
  }

  void _unsubscribeIfOwned({required int connID, required Object subscriptionOwner}) {
    if (!identical(_subscriptionOwners[connID], subscriptionOwner)) return;
    unsubscribe(connID);
  }

  /// Converts a [SesoriSseEvent] to the OpenCode wire format expected by the
  /// mobile client: {"payload": {"type": "...", "properties": {...rest...}}}
  ///
  /// The mobile's _onSseData extracts `payload.properties`, merges it with
  /// `type`, then calls SseEventData.fromJson(merged). Sending the flat Sesori
  /// format (no `properties` key) causes all required fields to be missing.
  Map<String, dynamic> _toOpenCodeFormat(SesoriSseEvent event) {
    final json = event.toJson();
    final type = json['type'] as String;
    final properties = Map<String, dynamic>.from(json)..remove('type');
    return {
      'payload': {'type': type, 'properties': properties},
    };
  }

  void _purgeExpiredOrphans() {
    final now = clock.now();
    final expired = _orphanQueues.where((o) => !o.expiry.isAfter(now)).toList();
    for (final orphan in expired) {
      orphan.queue.dispose();
      _orphanQueues.remove(orphan);
    }
  }
}

final class const _StaleRelayConnectionException() implements Exception;
