import "dart:async";

import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/session/session_service.dart";
import "prompt_send_queue.dart";

typedef PromptSendStateSnapshot = ({
  String? agent,
  String? providerID,
  String? modelID,
  bool isConnected,
});

class PromptSendService {
  final SessionService _service;
  final String _sessionId;
  final void Function() _onQueueChanged;
  final PromptSendStateSnapshot Function() _stateProvider;

  final PromptSendQueue _promptQueue = PromptSendQueue();
  bool _isSending = false;

  PromptSendService({
    required SessionService service,
    required String sessionId,
    required void Function() onQueueChanged,
    required PromptSendStateSnapshot Function() stateProvider,
  }) : _service = service,
       _sessionId = sessionId,
       _onQueueChanged = onQueueChanged,
       _stateProvider = stateProvider;

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

  void drain() {
    if (_promptQueue.isEmpty) return;
    final current = _stateProvider();
    if (!current.isConnected) return;
    unawaited(_sendNextQueued());
  }

  Future<void> _sendNextQueued() async {
    if (_isSending) return;

    final current = _stateProvider();
    if (!current.isConnected) return;

    final message = _promptQueue.dequeue();
    if (message == null) return;

    _isSending = true;
    _onQueueChanged();

    var sendSucceeded = false;
    try {
      final result = await _service.sendMessage(
        _sessionId,
        message,
        agent: current.agent,
        providerID: current.providerID,
        modelID: current.modelID,
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
      drain();
    }
  }
}
