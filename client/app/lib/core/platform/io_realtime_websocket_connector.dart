import "dart:async";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:web_socket_channel/io.dart";
import "package:web_socket_channel/status.dart" as status;
import "package:web_socket_channel/web_socket_channel.dart";

@lazySingleton
class IoRealtimeWebSocketClient() {
  WebSocketChannel connect({
    required Uri uri,
    required Map<String, String> headers,
    required Duration connectTimeout,
  }) {
    return IOWebSocketChannel.connect(uri, headers: headers, connectTimeout: connectTimeout);
  }
}

@LazySingleton(as: RealtimeWebSocketConnector)
class IoRealtimeWebSocketConnector({required final IoRealtimeWebSocketClient client})
    implements RealtimeWebSocketConnector {
  final IoRealtimeWebSocketClient _client = client;

  @override
  Future<WebSocketChannel> connect({
    required Uri uri,
    required Map<String, String> headers,
    required Duration connectTimeout,
  }) async {
    final channel = _client.connect(uri: uri, headers: headers, connectTimeout: connectTimeout);
    try {
      await channel.ready;
      return channel;
    } on TimeoutException catch (error) {
      _closeAfterFailedReady(channel);
      throw RealtimeWebSocketOpenException(cause: error, httpStatus: null, timedOut: true);
    } on WebSocketChannelException catch (error) {
      _closeAfterFailedReady(channel);
      throw _mapWebSocketChannelException(error);
    } on Object catch (error) {
      _closeAfterFailedReady(channel);
      throw RealtimeWebSocketOpenException(cause: error, httpStatus: null, timedOut: false);
    }
  }

  void _closeAfterFailedReady(WebSocketChannel channel) {
    // Best-effort cleanup on an already-failed socket. Without a handler a
    // throwing close becomes an unhandled async error that masks the mapped
    // RealtimeWebSocketOpenException the caller is about to receive.
    unawaited(
      channel.sink.close(status.normalClosure).catchError((Object error, StackTrace stackTrace) {
        logw("Realtime voice socket close after failed ready failed", error, stackTrace);
      }),
    );
  }

  RealtimeWebSocketOpenException _mapWebSocketChannelException(WebSocketChannelException error) {
    final inner = error.inner;
    return RealtimeWebSocketOpenException(
      cause: error,
      httpStatus: inner is WebSocketException ? inner.httpStatusCode : null,
      timedOut: inner is TimeoutException,
    );
  }
}
