import "package:web_socket_channel/web_socket_channel.dart";

final class const RealtimeWebSocketOpenException({
  // ignore: no_slop_linter/prefer_specific_type, caught transport failures may be any object
  required final Object? cause,
  required final int? httpStatus,
  required final bool timedOut,
}) implements Exception;

abstract interface class RealtimeWebSocketConnector() {
  /// Opens a WebSocket and resolves only after [WebSocketChannel.ready] succeeds.
  Future<WebSocketChannel> connect({
    required Uri uri,
    required Map<String, String> headers,
    required Duration connectTimeout,
  });
}
