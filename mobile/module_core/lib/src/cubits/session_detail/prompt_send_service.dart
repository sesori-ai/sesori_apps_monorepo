import "dart:async";

import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/session/session_service.dart";
import "prompt_send_queue.dart";

class PromptSendService {
  final SessionService _service;
  final String _sessionId;
  final void Function() _onQueueChanged;

  final PromptSendQueue _promptQueue = PromptSendQueue();
  bool _isSending = false;

  PromptSendService({
    required SessionService service,
    required String sessionId,
    required void Function() onQueueChanged,
  }) : _service = service,
       _sessionId = sessionId,
       _onQueueChanged = onQueueChanged;

  List<String> get queuedMessages => _promptQueue.items;

  bool get isEmpty => _promptQueue.isEmpty;

  Future<void> sendMessage({
    required String text,
    required String? agent,
    required String? providerID,
    required String? modelID,
    required bool isConnected,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!isConnected) {
      _promptQueue.enqueue(trimmed);
      _onQueueChanged();
      return;
    }

    final result = await _service.sendMessage(
      _sessionId,
      trimmed,
      agent: agent,
      providerID: providerID,
      modelID: modelID,
    );

    if (result case ErrorResponse()) {
      _promptQueue.requeue(trimmed);
      _onQueueChanged();
    }
  }

  String? cancelQueuedMessage(int index) {
    final removed = _promptQueue.cancel(index);
    if (removed != null) {
      _onQueueChanged();
    }
    return removed;
  }

  void drain({
    required String? agent,
    required String? providerID,
    required String? modelID,
    required bool isConnected,
  }) {
    if (_promptQueue.isEmpty) return;
    if (!isConnected) return;
    unawaited(
      _sendNextQueued(
        agent: agent,
        providerID: providerID,
        modelID: modelID,
        isConnected: isConnected,
      ),
    );
  }

  Future<void> _sendNextQueued({
    required String? agent,
    required String? providerID,
    required String? modelID,
    required bool isConnected,
  }) async {
    if (_isSending) return;
    if (!isConnected) return;

    final message = _promptQueue.dequeue();
    if (message == null) return;

    _isSending = true;
    _onQueueChanged();

    var sendSucceeded = false;
    try {
      final result = await _service.sendMessage(
        _sessionId,
        message,
        agent: agent,
        providerID: providerID,
        modelID: modelID,
      );

      if (result case ErrorResponse()) {
        _promptQueue.requeue(message);
        _onQueueChanged();
      } else {
        sendSucceeded = true;
      }
    } finally {
      _isSending = false;
    }

    if (sendSucceeded) {
      drain(
        agent: agent,
        providerID: providerID,
        modelID: modelID,
        isConnected: isConnected,
      );
    }
  }
}
