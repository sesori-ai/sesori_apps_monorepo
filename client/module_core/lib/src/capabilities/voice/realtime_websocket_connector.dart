import "package:web_socket_channel/web_socket_channel.dart";

abstract interface class RealtimeWebSocketConnector() {
  WebSocketChannel connect(Uri uri, {required Map<String, String> headers});
}
