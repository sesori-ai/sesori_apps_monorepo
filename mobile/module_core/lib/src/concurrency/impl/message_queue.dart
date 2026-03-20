// ignore_for_file: no_slop_linter/prefer_required_named_parameters
import "dart:async";
import "dart:collection";

import "../../logging/logging.dart";

extension CompleterWithTimeout<T> on Completer<T> {
  void setTimeout(
    Duration duration, {
    void Function()? onTimeout,
    T? returnOnTimeout,
  }) {
    unawaited(
      Future<void>.delayed(duration).then((_) {
        if (!isCompleted) {
          if (returnOnTimeout != null) {
            complete(returnOnTimeout);
          } else {
            completeError(TimeoutException("Operation timed out", duration));
          }
          onTimeout?.call();
        }
      }),
    );
  }

  void safeComplete(T value) {
    if (!isCompleted) {
      complete(value);
    }
  }
}

class MessageQueue<T, OUT> {
  final FutureOr<OUT> Function(T) sendFunction;
  final Completer<void> _isReady;

  /// Used to kill the message if it's taking too long to send/process
  final Duration? inFlightTimeout;

  final Queue<({T data, Completer<OUT> completer})> _messages = Queue();
  bool _isSending = false;

  MessageQueue({
    required this.sendFunction,
    this.inFlightTimeout,
    Completer<void>? isReady,
  }) : _isReady = isReady ?? (Completer()..complete()) {
    // ignore: discarded_futures
    _isReady.future.then((value) => _checkAndSendNext());
  }

  Future<OUT> enqueueMessage(T message) {
    final Completer<OUT> completer = Completer();
    _messages.add((data: message, completer: completer));
    if (!_isSending) {
      unawaited(_checkAndSendNext());
    }
    return completer.future;
  }

  Future<void> _checkAndSendNext() async {
    if (_isReady.isCompleted && !_isSending && _messages.isNotEmpty) {
      await _sendNext();
    }
  }

  Future<void> _sendNext() async {
    try {
      if (_messages.isEmpty) {
        _isSending = false;
        return;
      }
      _isSending = true;
      final (data: nextMessage, completer: completer) = _messages.removeFirst();

      try {
        final inFlightTimeout = this.inFlightTimeout;
        if (inFlightTimeout != null) {
          completer.setTimeout(inFlightTimeout);
        }

        final resultFuture = sendFunction(nextMessage);

        // Wait for either the future value to complete or the completer to complete
        // --- Note: The completer would complete before result only if it times out
        await Future.any([Future.value(resultFuture), completer.future]);
        completer.complete(await resultFuture);
      } catch (e) {
        loge("Error sending message ${nextMessage.toString()}", e);
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    } catch (e) {
      loge("Error fetching first message");
    }
    await _sendNext();
  }
}
