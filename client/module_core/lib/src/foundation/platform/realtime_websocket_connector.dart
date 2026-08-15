import "package:web_socket_channel/web_socket_channel.dart";

sealed class RealtimeVoiceOpenException implements Exception {
  // ignore: use_primary_constructors, unnecessary_type_name_in_constructor, explicit fields keep the taxonomy readable
  const RealtimeVoiceOpenException({required this.cause, required this.httpStatus});

  // ignore: no_slop_linter/prefer_specific_type, caught transport failures may be any object
  final Object? cause;
  final int? httpStatus;
}

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
