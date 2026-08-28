import "package:web_socket_channel/web_socket_channel.dart";

sealed class const RealtimeVoiceOpenException({
  // ignore: no_slop_linter/prefer_specific_type, caught transport failures may be any object
  required final Object? cause,
  required final int? httpStatus,
}) implements Exception;

final class const RealtimeVoiceOpenAuthenticationException({required super.cause, required super.httpStatus})
    extends RealtimeVoiceOpenException;

sealed class const RealtimeVoiceOpenHandshakeException({required super.cause, required super.httpStatus})
    extends RealtimeVoiceOpenException;

final class const RealtimeVoiceOpenHandshakeNotFoundException({required super.cause, required super.httpStatus})
    extends RealtimeVoiceOpenHandshakeException;

final class const RealtimeVoiceOpenHandshakeRateLimitedException({required super.cause, required super.httpStatus})
    extends RealtimeVoiceOpenHandshakeException;

final class const RealtimeVoiceOpenTimeoutException({required super.cause, required super.httpStatus})
    extends RealtimeVoiceOpenException;

final class const RealtimeVoiceOpenTransportException({required super.cause, required super.httpStatus})
    extends RealtimeVoiceOpenException;

abstract interface class RealtimeWebSocketConnector() {
  /// Opens a WebSocket and resolves only after [WebSocketChannel.ready] succeeds.
  Future<WebSocketChannel> connect({
    required Uri uri,
    required Map<String, String> headers,
    required Duration connectTimeout,
  });
}
