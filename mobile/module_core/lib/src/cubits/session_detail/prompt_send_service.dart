import "dart:async";

import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/session/session_service.dart";
import "prompt_send_queue.dart";
import "queued_session_submission.dart";

typedef PromptSendStateSnapshot = ({
  String? agent,
  String? providerID,
  String? modelID,
  bool isConnected,
  bool isLoaded,
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

  List<QueuedSessionSubmission> get queuedMessages => _promptQueue.items;

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
    final submission = QueuedSessionSubmission(text: trimmed);

    if (!isConnected) {
      _promptQueue.enqueue(submission);
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
      _promptQueue.requeue(submission);
      _onQueueChanged();
    }
  }

  Future<void> sendCommand({
    required String command,
    required String arguments,
    required bool isConnected,
  }) async {
    if (command.trim().isEmpty) return;
    final submission = QueuedSessionSubmission(
      text: arguments,
      command: command,
    );

    if (!isConnected) {
      _promptQueue.enqueue(submission);
      _onQueueChanged();
      return;
    }

    final result = await _service.sendCommand(
      sessionId: _sessionId,
      command: command,
      arguments: arguments,
    );

    if (result case ErrorResponse()) {
      _promptQueue.requeue(submission);
      _onQueueChanged();
    }
  }

  QueuedSessionSubmission? cancelQueuedMessage(int index) {
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
    if (!current.isLoaded) return;
    unawaited(_sendNextQueued());
  }

  Future<void> _sendNextQueued() async {
    if (_isSending) return;

    final current = _stateProvider();
    if (!current.isConnected) return;
    if (!current.isLoaded) return;

    final submission = _promptQueue.dequeue();
    if (submission == null) return;

    _isSending = true;
    _onQueueChanged();

    var sendSucceeded = false;
    try {
      final result = await (submission.isCommand
          ? _service.sendCommand(
              sessionId: _sessionId,
              command: submission.command!,
              arguments: submission.text,
            )
          : _service.sendMessage(
              _sessionId,
              submission.text,
              agent: current.agent,
              providerID: current.providerID,
              modelID: current.modelID,
            ));

      if (result case ErrorResponse()) {
        _promptQueue.requeue(submission);
        _onQueueChanged();
      } else {
        sendSucceeded = true;
      }
    } finally {
      _isSending = false;
    }

    if (sendSucceeded) {
      final current = _stateProvider();
      if (!current.isConnected) return;
      if (!current.isLoaded) return;
      unawaited(_sendNextQueued());
    }
  }
}
