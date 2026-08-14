import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:web_socket_channel/io.dart";
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
  WebSocketChannel connect(Uri uri, {required Map<String, String> headers, required Duration connectTimeout}) {
    return _client.connect(uri, headers: headers, connectTimeout: connectTimeout);
  }
}
