import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../auth/auth_api.dart";
import "../auth/token_refresher.dart";

/// Owns startup outage recovery, independently of the supervisor crash budget.
class BridgeStartupRetryService() {
  static const retryInterval = Duration(minutes: 1);

  final BehaviorSubject<ControlStartupState> _state = BehaviorSubject.seeded(ControlStartupState.starting);
  final StreamController<void> _cancellation = StreamController<void>.broadcast(sync: true);

  ValueStream<ControlStartupState> get states => _state.stream;

  Future<T> run<T>({required Future<T> Function() operation}) async {
    while (true) {
      _checkCancelled();
      try {
        final result = await operation();
        // Return acquired resources to their caller even during cancellation:
        // the session owns closing a relay connection that just completed.
        if (!_cancellation.isClosed) _state.add(ControlStartupState.starting);
        return result;
      } on Object catch (error, stackTrace) {
        _checkCancelled();
        if (!_isRetryable(error: error)) rethrow;
        final waitingForToken = error is ControlTokenRetryLaterException;
        _state.add(
          waitingForToken ? ControlStartupState.waitingForAuthentication : ControlStartupState.waitingForServer,
        );
        Console.warning(
          waitingForToken
              ? "Waiting for the desktop app to supply an access token. The bridge will retry in 1 minute."
              : "Could not reach the Sesori server during startup. Your internet connection may be unavailable. "
                    "The bridge is waiting and will retry in 1 minute.",
        );
        Log.w("Startup server request failed; retrying in 1 minute", error, stackTrace);
        final elapsed = Completer<void>();
        void wake() {
          if (!elapsed.isCompleted) elapsed.complete();
        }

        final cancellation = _cancellation.stream.listen(null, onDone: wake);
        final timer = Timer(retryInterval, wake);
        try {
          await elapsed.future;
        } finally {
          timer.cancel();
          unawaited(cancellation.cancel());
        }
      }
    }
  }

  void markReady() => _state.add(ControlStartupState.ready);

  void cancel() => unawaited(_cancellation.close());

  Future<void> dispose() async {
    cancel();
    await _state.close();
  }

  void _checkCancelled() {
    if (_cancellation.isClosed) throw const PluginStartAbortedException();
  }

  bool _isRetryable({required Object error}) => switch (error) {
    http.ClientException() || SocketException() || TimeoutException() || ControlTokenRetryLaterException() => true,
    WebSocketChannelException(:final inner) when inner is Exception => _isRetryable(error: inner),
    AuthApiException(:final statusCode) ||
    BridgeRegistrationException(:final statusCode) ||
    WebSocketException(
      httpStatusCode: final statusCode?,
    ) => statusCode == 408 || statusCode == 429 || statusCode >= 500,
    _ => false,
  };
}
