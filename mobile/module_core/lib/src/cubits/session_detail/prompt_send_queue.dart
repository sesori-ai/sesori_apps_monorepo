import "dart:collection";

/// Manages a queue of prompt messages waiting to be sent.
///
/// This is a thin data structure — it owns the list of pending messages and
/// provides methods to enqueue, dequeue, requeue, and cancel items. The send
/// logic and condition checks (connection alive) remain in the
/// cubit that owns this queue.
class PromptSendQueue {
  final Queue<String> _items = Queue<String>();

  /// Unmodifiable snapshot of the current queue contents.
  List<String> get items => List.unmodifiable(_items.toList());

  /// Whether the queue has no pending messages.
  bool get isEmpty => _items.isEmpty;

  /// Whether the queue has pending messages.
  bool get isNotEmpty => _items.isNotEmpty;

  /// Add a message to the end of the queue.
  void enqueue(String text) => _items.addLast(text);

  /// Remove and return the first message for sending.
  /// Returns `null` if the queue is empty.
  String? dequeue() => _items.isEmpty ? null : _items.removeFirst();

  /// Re-insert a message at the front after a failed send attempt.
  void requeue(String text) => _items.addFirst(text);

  /// Remove a message by index (user cancellation).
  /// Returns the removed message, or `null` if the index is invalid.
  String? cancel(int index) {
    if (index < 0 || index >= _items.length) return null;
    final item = _items.elementAt(index);
    var i = 0;
    _items.removeWhere((_) => i++ == index);
    return item;
  }
}
