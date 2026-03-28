import "dart:async";
import "dart:collection";
import "dart:convert";

import "package:clock/clock.dart";
import "package:cryptography/cryptography.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../relay_client.dart";

class SSEManager {
  /// Default duration for which orphan queues remain valid after a phone
  /// disconnects. Referenced by the CLI entry point and tests.
  static const Duration defaultReplayWindow = Duration(minutes: 5);

  /// How long a disconnected subscriber's orphan queue stays valid.
  final Duration replayWindow;

  final void Function(int bytes) _onBytesSent;
  final FailureReporter _failureReporter;

  /// Maximum number of events retained per subscriber queue.
  static const int maxQueueSize = 50000;

  final Map<int, EventQueue<SesoriSseEvent>> _subscribers = {};
  final Queue<({EventQueue<SesoriSseEvent> queue, DateTime expiry})> _orphanQueues =
      Queue<({EventQueue<SesoriSseEvent> queue, DateTime expiry})>();

  List<int>? _roomKey;

  SSEManager({
    required this.replayWindow,
    required void Function(int bytes) onBytesSent,
    required FailureReporter failureReporter,
  }) : _onBytesSent = onBytesSent,
       _failureReporter = failureReporter;

  /// Stores a copy of the room key used to encrypt outgoing SSE events.
  void setRoomKey(List<int> roomKey) {
    _roomKey = List<int>.from(roomKey);
  }

  /// Registers [connID] as an SSE subscriber.
  ///
  /// [path] is accepted for API compatibility with call sites but is not used
  /// by this manager.
  void subscribePath(int connID, String path, RelayClient client) {
    final orphan = _popValidOrphan();

    if (orphan != null) {
      orphan.onDequeue = _createSendFunction(connID, client);
      orphan.onError = (event, error) {
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
      orphan.resume();
      _subscribers[connID] = orphan;
      return;
    }

    _subscribers[connID] = EventQueue<SesoriSseEvent>(
      onDequeue: _createSendFunction(connID, client),
      maxSize: maxQueueSize,
      onError: (event, error) {
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
      },
    );
  }

  /// Removes [connID] from active subscribers.
  ///
  /// The queue is paused and retained as an orphan queue for replay during
  /// [replayWindow]. If the phone reconnects within that window, the orphan
  /// is resumed via [subscribePath] and all buffered events are delivered.
  void unsubscribe(int connID) {
    final queue = _subscribers.remove(connID);
    if (queue == null) return;

    queue.pause();
    _orphanQueues.addLast((
      queue: queue,
      expiry: clock.now().add(replayWindow),
    ));
  }

  /// Alias for [unsubscribe].
  void removeSubscriber(int connID) => unsubscribe(connID);

  /// Pauses all active subscriber queues and moves them to orphan state.
  ///
  /// Use this when the relay connection drops but may recover. Orphan queues
  /// continue to buffer incoming events and will be replayed when phones
  /// reconnect within [replayWindow].
  void orphanAll() {
    for (final queue in _subscribers.values) {
      queue.pause();
      _orphanQueues.addLast((
        queue: queue,
        expiry: clock.now().add(replayWindow),
      ));
    }
    _subscribers.clear();
  }

  /// Clears all subscribers and orphan state.
  void stop() {
    for (final sub in _subscribers.values) {
      sub.dispose();
    }
    _subscribers.clear();
    _disposeOrphans();
  }

  /// Current number of active subscribers.
  int get subscriberCount => _subscribers.length;

  /// Number of orphan queues from disconnected subscribers.
  int get pendingReplayCount => _orphanQueues.length;

  /// Enqueues [event] into all active and non-expired orphan queues.
  void enqueueEvent(SesoriSseEvent event) {
    for (final queue in _subscribers.values) {
      queue.enqueue(event);
    }

    _purgeExpiredOrphans();
    for (final orphan in _orphanQueues) {
      orphan.queue.enqueue(event);
    }
  }

  void _disposeOrphans() {
    for (final orphan in _orphanQueues) {
      orphan.queue.dispose();
    }
    _orphanQueues.clear();
  }

  EventQueue<SesoriSseEvent>? _popValidOrphan() {
    final now = clock.now();
    while (_orphanQueues.isNotEmpty) {
      final oldest = _orphanQueues.removeFirst();
      if (oldest.expiry.isAfter(now)) {
        return oldest.queue;
      }
      oldest.queue.dispose();
    }
    return null;
  }

  Future<void> Function(SesoriSseEvent) _createSendFunction(
    int connID,
    RelayClient client,
  ) {
    SessionEncryptor? encryptor;

    return (SesoriSseEvent event) async {
      Log.v("[sse] dequeuing event for connID=$connID: ${event.runtimeType}");
      if (_roomKey == null) {
        Log.w("[sse] dropping — roomKey is null");
        return;
      }

      encryptor ??= () {
        final roomKey = List<int>.from(_roomKey!);
        final cryptoService = RelayCryptoService();
        final secretKey = SecretKey(roomKey);
        return cryptoService.createSessionEncryptor(secretKey);
      }();

      final eventData = jsonEncode(_toOpenCodeFormat(event));
      final relayMessage = RelayMessage.sseEvent(data: eventData);
      final payloadBytes = utf8.encode(jsonEncode(relayMessage.toJson()));
      Log.v("[sse] sending ${payloadBytes.length} bytes to connID=$connID");
      _onBytesSent(payloadBytes.length);
      final framed = await frame(payloadBytes, encryptor!);
      client.send(connID, framed);
    };
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
