// ignore_for_file: no_slop_linter/prefer_specific_type

import "dart:async";
import "dart:collection";

/// A buffered FIFO queue that delivers events sequentially to a single listener.
///
/// Events added via [enqueue] are buffered until a listener is attached with
/// [listen]. Once attached, buffered events are flushed in order and new events
/// are delivered immediately. If the listener is detached (via
/// [EventQueueSubscription.cancel]), events resume buffering until a new
/// listener is attached.
///
/// The listener callback is awaited before the next event is delivered,
/// guaranteeing ordered, sequential processing.
///
/// If the listener throws, the event stays at the head for retry on the
/// next drain cycle. After [maxAttempts] consecutive failures on the same
/// event it is dropped (logged via `onError`) so a single poisoned event
/// cannot block the entire queue.
///
/// Typical lifecycle:
/// 1. Create queue with optional [maxSize]/[maxAttempts].
/// 2. [enqueue] events — they buffer until a listener is attached.
/// 3. [listen] to start draining (flushes backlog, then processes new events).
/// 4. [EventQueueSubscription.cancel] to detach — events buffer again.
/// 5. [listen] again to re-attach a (possibly different) listener.
/// 6. [dispose] to release resources when no longer needed.
class EventQueue<T extends Object>({
  /// Maximum number of events to buffer. When exceeded, oldest events are
  /// dropped. `null` means unlimited.
  final int? maxSize,

  /// Maximum consecutive failures allowed for the same head event before
  /// it is dropped.
  final int maxAttempts = 5,
}) {
  final Queue<T> _buffer = Queue<T>();
  bool _draining = false;
  bool _disposed = false;
  int _headAttempts = 0;

  // Active listener state — all private.
  Future<void> Function(T event)? _onData;
  void Function(T event, Object error) _onError = _defaultOnError;
  EventQueueSubscription<T>? _activeSubscription;

  /// Attaches a listener that will receive buffered and future events.
  ///
  /// If events have been buffered while no listener was attached, they are
  /// drained immediately (in order) through [onData].
  ///
  /// Only one listener can be active at a time. Cancel the returned
  /// [EventQueueSubscription] before attaching a new listener.
  EventQueueSubscription<T> listen(
    Future<void> Function(T event) onData, {
    void Function(T event, Object error)? onError,
  }) {
    if (_activeSubscription != null) {
      throw StateError(
        "EventQueue already has a listener. Cancel the existing subscription first.",
      );
    }
    if (_disposed) {
      throw StateError("Cannot listen on a disposed EventQueue.");
    }
    _onData = onData;
    _onError = onError ?? _defaultOnError;
    final subscription = EventQueueSubscription<T>._(this);
    _activeSubscription = subscription;

    if (_buffer.isNotEmpty && !_draining) {
      unawaited(_drain());
    }
    return subscription;
  }

  /// Adds [event] to the back of the queue.
  ///
  /// If [maxSize] is set and exceeded, the oldest event is dropped.
  /// If a listener is attached, the drain loop starts automatically. If no
  /// listener is attached, the event is buffered.
  void enqueue(T event) {
    if (_disposed) return;
    _buffer.addLast(event);
    if (maxSize case final maxSize?) {
      while (_buffer.length > maxSize) {
        _buffer.removeFirst();
      }
    }
    if (_onData != null && !_draining) {
      unawaited(_drain());
    }
  }

  /// Releases resources.
  ///
  /// Clears pending events so the drain loop exits after the in-flight event.
  /// The queue should not be used after calling this.
  void dispose() {
    _disposed = true;
    _buffer.clear();
    _headAttempts = 0;
    _onData = null;
    _activeSubscription = null;
  }

  /// Number of events currently buffered.
  int get length => _buffer.length;

  // ---------------------------------------------------------------------------

  void _detach() {
    _onData = null;
    _onError = _defaultOnError;
    _activeSubscription = null;
  }

  // ignore: no_slop_linter/prefer_required_named_parameters
  static void _defaultOnError<T>(T event, Object error) {
    final eventData = event.toString();
    final preview = eventData.length > 80 ? "${eventData.substring(0, 80)}..." : eventData;
    // ignore: avoid_print
    print("EventQueue: drain failed: ${error.toString()} (event: $preview)");
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;

    try {
      while (_buffer.isNotEmpty && !_disposed) {
        // No listener? Stop draining — events stay buffered.
        final onData = _onData;
        if (onData == null) break;
        final activeSubscription = _activeSubscription;

        final event = _buffer.first;
        try {
          await onData(event);
          _buffer.removeFirst();
          _headAttempts = 0;
        } catch (e) {
          // A detached listener no longer owns the in-flight delivery. Keep
          // the head untouched so a replacement listener can retry it without
          // charging the obsolete attempt against the poison-event limit.
          if (!identical(_activeSubscription, activeSubscription)) {
            continue;
          }
          _headAttempts++;
          _onError(event, e);

          if (_headAttempts >= maxAttempts) {
            _buffer.removeFirst();
            _headAttempts = 0;
            continue;
          }

          // Retry on next drain trigger (enqueue / listen).
          break;
        }
      }
    } finally {
      _draining = false;
    }
  }
}

/// Handle returned by [EventQueue.listen] to manage the subscription.
///
/// Call [cancel] to detach the listener — pending events remain buffered
/// in the queue and will be delivered to the next listener.
class EventQueueSubscription<T extends Object>._(final EventQueue<T> _queue) {
  bool get _isActive => identical(_queue._activeSubscription, this);

  /// Detaches the listener. Pending events remain buffered in the queue.
  /// No-op if this subscription is no longer active.
  void cancel() {
    if (_isActive) _queue._detach();
  }
}
