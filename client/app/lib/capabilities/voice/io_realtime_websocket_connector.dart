import "dart:async";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:web_socket_channel/io.dart";
import "package:web_socket_channel/status.dart" as status;
import "package:web_socket_channel/web_socket_channel.dart";

@lazySingleton
class IoRealtimeWebSocketClient() {
  WebSocketChannel connect(Uri uri, {required Map<String, String> headers, required Duration connectTimeout}) {
    return IOWebSocketChannel.connect(uri, headers: headers, connectTimeout: connectTimeout);
  }
}

@LazySingleton(as: RealtimeWebSocketConnector)
class IoRealtimeWebSocketConnector({required final IoRealtimeWebSocketClient client})
    implements RealtimeWebSocketConnector {
  final IoRealtimeWebSocketClient _client = client;

  @override
  Future<WebSocketChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
    required Duration connectTimeout,
  }) async {
    final channel = _client.connect(uri, headers: headers, connectTimeout: connectTimeout);
    try {
      await channel.ready;
      return channel;
    } on TimeoutException catch (error) {
      _closeAfterFailedReady(channel);
      throw RealtimeVoiceOpenTimeoutException(cause: error, httpStatus: null);
    } on WebSocketChannelException catch (error) {
      _closeAfterFailedReady(channel);
      throw _mapWebSocketChannelException(error);
    } on Object catch (error) {
      _closeAfterFailedReady(channel);
      throw RealtimeVoiceOpenTransportException(cause: error, httpStatus: null);
    }
  }

  void _closeAfterFailedReady(WebSocketChannel channel) {
    unawaited(channel.sink.close(status.normalClosure));
  }

  RealtimeVoiceOpenException _mapWebSocketChannelException(WebSocketChannelException error) {
    final inner = error.inner;
    if (inner is TimeoutException) {
      return RealtimeVoiceOpenTimeoutException(cause: error, httpStatus: null);
    }
    final httpStatus = inner is WebSocketException ? inner.httpStatusCode : null;
    return switch (httpStatus) {
      401 => RealtimeVoiceOpenAuthenticationException(cause: error, httpStatus: httpStatus),
      404 => RealtimeVoiceOpenHandshakeNotFoundException(cause: error, httpStatus: httpStatus),
      429 => RealtimeVoiceOpenHandshakeRateLimitedException(cause: error, httpStatus: httpStatus),
      _ => RealtimeVoiceOpenTransportException(cause: error, httpStatus: httpStatus),
    };
  }
}
