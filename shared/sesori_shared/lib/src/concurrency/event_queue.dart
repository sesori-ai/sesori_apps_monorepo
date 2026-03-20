import "dart:async";
import "dart:collection";

/// A FIFO queue that drains events through [onDequeue], with pause/resume
/// flow control.
///
/// Events are always dequeued in order. When paused, the drain loop holds
/// per-entry until resumed — no events are skipped or reordered. When
/// resumed, draining continues from where it left off.
///
/// If [onDequeue] throws, the event stays at the head for retry on the
/// next drain cycle. After [maxAttempts] consecutive failures on the same
/// event it is dropped (logged via [onError]) so a single poisoned event
/// cannot block the entire queue.
///
/// Typical lifecycle:
/// 1. Create with [onDequeue] callback and optional [maxSize]/[maxAttempts].
/// 2. [enqueue] events — drain loop starts automatically.
/// 3. [pause] to stop dequeuing (events keep accumulating).
/// 4. [resume] to continue draining (backlog first, then new events).
/// 5. [dispose] to release resources when no longer needed.
class EventQueue<T extends Object> {
  /// Called for each dequeued event. Must complete before the next event
  /// is dequeued to preserve ordering.
  Future<void> Function(T event) onDequeue;

  /// Called when [onDequeue] throws. Defaults to [print].
  void Function(T event, Object error) onError;

  /// Maximum number of events to retain. When exceeded, oldest events are
  /// dropped. `null` means unlimited.
  final int? maxSize;

  /// Maximum consecutive failures allowed for the same head event before
  /// it is dropped.
  final int maxAttempts;

  final Queue<T> _events = Queue<T>();
  bool _draining = false;
  bool _paused;
  bool _disposed = false;
  Completer<void>? _resumeCompleter;

  /// Consecutive failure count for the current head event.
  int _headAttempts = 0;

  EventQueue({
    required this.onDequeue,
    this.maxSize,
    this.maxAttempts = 5,
    void Function(T, Object)? onError,
    bool startPaused = false,
  }) : onError = onError ?? _defaultOnError,
       _paused = startPaused {
    if (startPaused) {
      _resumeCompleter = Completer<void>();
    }
  }

  static void _defaultOnError<T>(T event, Object error) {
    final eventData = event.toString();
    final preview = eventData.length > 80 ? "${eventData.substring(0, 80)}..." : eventData;
    // ignore: avoid_print
    print("EventQueue: onDequeue failed: $error (event: $preview)");
  }

  /// Adds [eventData] to the back of the queue.
  ///
  /// If [maxSize] is set and exceeded, the oldest event is dropped.
  /// If the queue is not paused and not already draining, the drain loop
  /// is started automatically.
  void enqueue(T event) {
    if (_disposed) return;
    _events.addLast(event);
    if (maxSize != null) {
      while (_events.length > maxSize!) {
        _events.removeFirst();
      }
    }
    if (!_draining && !_paused) {
      unawaited(_drain());
    }
  }

  /// Pauses the drain loop. Events continue to accumulate but are not
  /// dequeued until [resume] is called.
  ///
  /// The pause takes effect before the *next* event — the currently
  /// in-flight [onDequeue] call (if any) will complete normally.
  void pause() {
    if (_paused || _disposed) return;
    _paused = true;
    _resumeCompleter = Completer<void>();
  }

  /// Resumes the drain loop. If events are pending, draining starts or
  /// continues immediately.
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
    }
    _resumeCompleter = null;
    if (!_draining && _events.isNotEmpty) {
      unawaited(_drain());
    }
  }

  /// Releases resources.
  ///
  /// Clears pending events and unblocks any waiting drain loop so it can
  /// exit cleanly. The queue should not be used after calling this.
  void dispose() {
    _disposed = true;
    _events.clear();
    _paused = false;
    _headAttempts = 0;
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
    }
    _resumeCompleter = null;
  }

  /// Number of events currently in the queue.
  int get length => _events.length;

  /// Whether the queue is currently paused.
  bool get isPaused => _paused;

  // ---------------------------------------------------------------------------

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;

    try {
      while (_events.isNotEmpty && !_disposed) {
        // Per-entry pause check: hold here until resumed or disposed.
        if (_paused) {
          final completer = _resumeCompleter;
          if (completer == null) break;
          await completer.future;
          // After resume, re-check — queue may have been cleared by dispose.
          continue;
        }

        final event = _events.first;
        try {
          await onDequeue(event);
          _events.removeFirst();
          _headAttempts = 0;
        } catch (e) {
          _headAttempts++;
          onError(event, e);

          if (_headAttempts >= maxAttempts) {
            // Poisoned event — drop it so the queue can make progress.
            _events.removeFirst();
            _headAttempts = 0;
            continue;
          }

          // Retry on next drain trigger (enqueue / resume).
          break;
        }
      }
    } finally {
      _draining = false;
    }
  }
}
