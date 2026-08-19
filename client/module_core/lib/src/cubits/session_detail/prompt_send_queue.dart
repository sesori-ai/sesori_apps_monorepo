import "dart:collection";

import "queued_session_submission.dart";

/// Manages a queue of queued submissions waiting to be sent.
///
/// This is a thin data structure — it owns the list of pending submissions and
/// provides methods to enqueue, dequeue, requeue, and cancel items. The send
/// logic and condition checks (connection alive) remain in the
/// cubit that owns this queue.
class PromptSendQueue() {
  final Queue<QueuedSessionSubmission> _items = Queue<QueuedSessionSubmission>();
  QueuedSessionSubmission? _active;

  /// Unmodifiable snapshot of the current queue contents.
  List<QueuedSessionSubmission> get items => List.unmodifiable(_items.toList());

  /// The submission currently awaiting bridge acceptance.
  QueuedSessionSubmission? get active => _active;

  bool get isSending => _active != null;

  /// Whether the queue has no pending messages.
  bool get isEmpty => _items.isEmpty;

  /// Whether the queue has pending messages.
  bool get isNotEmpty => _items.isNotEmpty;

  /// Add a submission to the end of the queue.
  void enqueue(QueuedSessionSubmission submission) => _items.addLast(submission);

  /// Moves the first pending submission into the active slot.
  QueuedSessionSubmission? beginSend() {
    if (_active != null || _items.isEmpty) return null;
    return _active = _items.removeFirst();
  }

  void completeSend() {
    final active = _active;
    if (active != null) _settledElsewhere.remove(active.promptId);
    _active = null;
  }

  /// Parks the accepted in-flight submission until the bridge's own view of
  /// the prompt arrives — a queue event, a snapshot, or its delivered
  /// message, all of which land in [removeByPromptId]. Rendering from here
  /// covers the gap when the acceptance response outruns the
  /// `session.queued-prompts` event, so the bubble never blanks between
  /// "sending" and "queued". A submission the bridge already settled is
  /// consumed instead of parked.
  void parkAccepted() {
    final active = _active;
    _active = null;
    if (active == null) return;
    if (_settledElsewhere.remove(active.promptId)) return;
    _awaitingBridge.add(active);
  }

  /// Accepted submissions whose bridge-side representation has not arrived
  /// yet, oldest first.
  List<QueuedSessionSubmission> get awaitingBridge => List.unmodifiable(_awaitingBridge);

  final List<QueuedSessionSubmission> _awaitingBridge = [];

  /// Restores the active submission at the head after a failed send.
  ///
  /// Returns whether it was requeued. A submission the bridge settled while
  /// its send was in flight (accepted, dispatched, or cancelled there) is
  /// discarded instead — its transport failure proves nothing, and a retry
  /// would resurrect a prompt the bridge no longer queues.
  bool failSend() {
    final active = _active;
    if (active == null) return false;
    _active = null;
    if (_settledElsewhere.remove(active.promptId)) return false;
    _items.addFirst(active);
    return true;
  }

  /// Remove a submission by index (user cancellation).
  /// Returns the removed submission, or `null` if the index is invalid.
  QueuedSessionSubmission? cancel(int index) {
    if (index < 0 || index >= _items.length) return null;
    final item = _items.elementAt(index);
    var i = 0;
    _items.removeWhere((_) => i++ == index);
    return item;
  }

  /// Prompt ids the bridge settled while their send was still in flight; the
  /// active slot's own settle consumes the mark (discarding on failure).
  final Set<String> _settledElsewhere = {};

  /// Whether the in-flight submission was already settled by the bridge and
  /// therefore renders nowhere.
  bool get isActiveSettledElsewhere {
    final active = _active;
    return active != null && _settledElsewhere.contains(active.promptId);
  }

  /// Drops every staged copy of [promptId] — the bridge settled that prompt
  /// (queued, dispatched, or cancelled it), so a local retry would only
  /// duplicate or resurrect it. The active slot keeps settling through
  /// complete/fail so the drain loop stays single-flight; it is marked so
  /// rendering hides it and a late transport failure discards it.
  void removeByPromptId(String promptId) {
    _items.removeWhere((item) => item.promptId == promptId);
    _awaitingBridge.removeWhere((item) => item.promptId == promptId);
    if (_active?.promptId == promptId) _settledElsewhere.add(promptId);
  }

  /// Drops everything staged locally (the user stopped the session).
  void clear() {
    _items.clear();
    _awaitingBridge.clear();
    _active = null;
    _settledElsewhere.clear();
  }
}
