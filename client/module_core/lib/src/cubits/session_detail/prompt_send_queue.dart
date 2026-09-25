import "dart:collection";

import "../../foundation/models/composer/composer_attachment.dart";
import "../../repositories/models/prompt_send_failure.dart";
import "local_send_phase.dart";
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

  /// The head submission whose send really failed. It stays out of the
  /// pending list so later submissions wait behind it until the user retries
  /// or removes it.
  LocalSendFailed? _failed;

  /// Retained bridge previews may hold at most one maximum-size submission
  /// across the whole session. Older previews fall back to attachment counts.
  static const maxBridgePreviewBytes = maxComposerPromptAttachmentBytes;
  final Map<String, List<ComposerAttachment>> _bridgePromptAttachments = {};

  Map<String, List<ComposerAttachment>> get bridgePromptAttachments => Map.unmodifiable(_bridgePromptAttachments);

  /// Transfers local previews before bridge ownership removes staged copies.
  /// This runs at reconciliation, independent of which states a UI renders.
  void reconcileBridgeQueue({required Set<String> promptIds}) {
    _bridgePromptAttachments.removeWhere((promptId, _) => !promptIds.contains(promptId));
    var retainedBytes = _bridgePromptAttachments.values.fold(
      0,
      (total, items) => total + _attachmentBytes(attachments: items),
    );
    for (final submission in [
      for (final entry in _awaitingBridge) entry.submission,
      if (!isActiveSettledElsewhere) ?_active,
      ?_failed?.submission,
      ..._items,
    ]) {
      final attachments = submission.attachments;
      if (!promptIds.contains(submission.promptId) ||
          attachments.isEmpty ||
          _bridgePromptAttachments.containsKey(submission.promptId)) {
        continue;
      }
      final bytes = _attachmentBytes(attachments: attachments);
      if (bytes <= maxBridgePreviewBytes) {
        while (retainedBytes + bytes > maxBridgePreviewBytes) {
          final oldest = _bridgePromptAttachments.entries.first;
          retainedBytes -= _attachmentBytes(attachments: oldest.value);
          _bridgePromptAttachments.remove(oldest.key);
        }
        _bridgePromptAttachments[submission.promptId] = List.unmodifiable(attachments);
        retainedBytes += bytes;
      }
    }
    for (final promptId in promptIds) {
      _removeStagedByPromptId(promptId: promptId);
    }
  }

  static int _attachmentBytes({required List<ComposerAttachment> attachments}) =>
      attachments.fold(0, (total, attachment) => total + attachment.bytes.length);

  /// Unmodifiable snapshot of the current queue contents.
  List<QueuedSessionSubmission> get items => List.unmodifiable(_items.toList());

  /// The submission currently awaiting bridge acceptance.
  QueuedSessionSubmission? get active => _active;

  bool get isSending => _active != null;

  /// The failed head submission, shown with Retry until the user acts on it.
  LocalSendFailed? get failed => _failed;

  /// Whether the queue has no pending messages.
  bool get isEmpty => _items.isEmpty;

  /// Whether the queue has pending messages.
  bool get isNotEmpty => _items.isNotEmpty;

  /// Add a submission to the end of the queue.
  void enqueue(QueuedSessionSubmission submission) => _items.addLast(submission);

  /// Moves the first pending submission into the active slot.
  QueuedSessionSubmission? beginSend() {
    if (_active != null || _failed != null || _items.isEmpty || _items.first is UnavailableQueuedCommandSubmission) {
      return null;
    }
    return _active = _items.removeFirst();
  }

  void completeSend() {
    final active = _active;
    if (active != null) _settledElsewhere.remove(active.promptId);
    _active = null;
  }

  /// Parks the accepted in-flight submission until [reconcileBridgeQueue]
  /// transfers it to the bridge-owned view, or [removeByPromptId] settles its
  /// delivered message or explicit terminal outcome. Rendering from here
  /// covers the gap when the acceptance response outruns the
  /// `session.queued-prompts` event, so the bubble never blanks between
  /// "sending" and "queued". A submission the bridge already settled is
  /// consumed instead of parked.
  ///
  /// [epoch] is the caller's monotonic park counter; a snapshot whose fetch
  /// began after this park is authoritative for the prompt and may settle it
  /// via [settleAwaitingAbsent].
  void parkAccepted({required int epoch}) {
    final active = _active;
    _active = null;
    if (active == null) return;
    if (_settledElsewhere.remove(active.promptId)) return;
    _awaitingBridge.add((submission: active, epoch: epoch));
  }

  /// Accepted submissions whose bridge-side representation has not arrived
  /// yet, oldest first.
  List<QueuedSessionSubmission> get awaitingBridge =>
      List.unmodifiable([for (final entry in _awaitingBridge) entry.submission]);

  /// Settles parked submissions an authoritative snapshot proves gone: parked
  /// at or before [parkedAtOrBeforeEpoch] (so the snapshot's fetch could see
  /// them) yet absent from [ownedPromptIds]. Later parks stay — the fetch
  /// predates them and proves nothing.
  void settleAwaitingAbsent({required Set<String> ownedPromptIds, required int parkedAtOrBeforeEpoch}) {
    _awaitingBridge.removeWhere(
      (entry) => entry.epoch <= parkedAtOrBeforeEpoch && !ownedPromptIds.contains(entry.submission.promptId),
    );
  }

  final List<({QueuedSessionSubmission submission, int epoch})> _awaitingBridge = [];

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

  /// Holds the active submission in the failed slot after a real send failure.
  ///
  /// Returns whether it was held. Like [failSend], a submission the bridge
  /// already settled is discarded instead.
  bool holdFailedSend({required PromptSendFailure failure}) {
    final active = _active;
    if (active == null) return false;
    _active = null;
    if (_settledElsewhere.remove(active.promptId)) return false;
    _failed = LocalSendFailed(submission: active, failure: failure);
    return true;
  }

  /// Puts the failed submission back at the head, unchanged, so its resend
  /// carries the same prompt id and the bridge's dedup can never run it twice.
  void retryFailedSend() {
    final failed = _failed;
    if (failed == null) return;
    _failed = null;
    _items.addFirst(failed.submission);
  }

  /// Drops the failed submission (user removal) and returns it.
  QueuedSessionSubmission? removeFailedSend() {
    final failed = _failed;
    _failed = null;
    return failed?.submission;
  }

  /// Rewrites pending submissions in place while preserving FIFO order.
  void replacePending({required QueuedSessionSubmission Function(QueuedSessionSubmission submission) update}) {
    final replacements = _items.map(update).toList(growable: false);
    _items
      ..clear()
      ..addAll(replacements);
  }

  /// Marks one pending command as unavailable while retaining its authored
  /// text and FIFO position for explicit user removal.
  void markCommandUnavailable({required String promptId}) {
    replacePending(
      update: (submission) => switch (submission) {
        QueuedCommandSubmission(
          promptId: final submissionPromptId,
          :final text,
          :final command,
          :final agent,
          :final agentModel,
          :final fastMode,
        )
            when submissionPromptId == promptId =>
          QueuedSessionSubmission.unavailableCommand(
            promptId: submissionPromptId,
            text: text,
            command: command,
            agent: agent,
            agentModel: agentModel,
            fastMode: fastMode,
          ),
        QueuedTextSubmission() || QueuedCommandSubmission() || UnavailableQueuedCommandSubmission() => submission,
      },
    );
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

  /// Drops staged copies and retained previews of terminally settled [promptId].
  /// A local retry would only duplicate or resurrect it. The active slot keeps settling through
  /// complete/fail so the drain loop stays single-flight; it is marked so
  /// rendering hides it and a late transport failure discards it.
  void removeByPromptId(String promptId) {
    _bridgePromptAttachments.remove(promptId);
    _removeStagedByPromptId(promptId: promptId);
  }

  void _removeStagedByPromptId({required String promptId}) {
    _items.removeWhere((item) => item.promptId == promptId);
    _awaitingBridge.removeWhere((entry) => entry.submission.promptId == promptId);
    if (_failed?.submission.promptId == promptId) _failed = null;
    if (_active?.promptId == promptId) _settledElsewhere.add(promptId);
  }

  /// Drops everything staged locally (the user stopped the session).
  void clear() {
    _items.clear();
    _awaitingBridge.clear();
    _active = null;
    _failed = null;
    _settledElsewhere.clear();
    _bridgePromptAttachments.clear();
  }
}
