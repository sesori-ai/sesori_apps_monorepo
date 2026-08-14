import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/capabilities/voice/io_realtime_websocket_connector.dart";
import "package:web_socket_channel/web_socket_channel.dart";

void main() {
  group("IoRealtimeWebSocketConnector", () {
    test("forwards URI and headers to the IO client and returns its channel", () {
      final channel = _FakeWebSocketChannel();
      final client = _CapturingIoRealtimeWebSocketClient(channel: channel);
      final connector = IoRealtimeWebSocketConnector(client: client);
      final uri = Uri.parse("wss://auth.example.test/voice/realtime");
      const headers = {"Authorization": "Bearer access-token", "X-Sesori-Device": "device-1"};
      const connectTimeout = Duration(seconds: 10);

      final result = connector.connect(uri, headers: headers, connectTimeout: connectTimeout);

      expect(result, same(channel));
      expect(client.uri, uri);
      expect(client.headers, headers);
      expect(client.connectTimeout, connectTimeout);
    });

    test("IO client surfaces network failure through channel.ready", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = Uri.parse("ws://127.0.0.1:${server.port}/voice/realtime");
      await server.close(force: true);
      final client = IoRealtimeWebSocketClient();

      final channel = client.connect(uri, headers: const {}, connectTimeout: const Duration(milliseconds: 100));

      await expectLater(channel.ready, throwsA(isA<Object>()));
    });

    test("does not place bearer credentials in the WebSocket URI", () {
      final channel = _FakeWebSocketChannel();
      final client = _CapturingIoRealtimeWebSocketClient(channel: channel);
      final connector = IoRealtimeWebSocketConnector(client: client);
      final uri = Uri.parse("wss://auth.example.test/voice/realtime?protocol=1");

      connector.connect(
        uri,
        headers: const {"Authorization": "Bearer secret-token"},
        connectTimeout: const Duration(seconds: 10),
      );

      expect(client.uri.toString(), isNot(contains("secret-token")));
      expect(client.uri!.queryParameters, {"protocol": "1"});
      expect(client.headers, {"Authorization": "Bearer secret-token"});
    });
  });
}

final class _CapturingIoRealtimeWebSocketClient({required final WebSocketChannel channel})
    extends IoRealtimeWebSocketClient {
  Uri? uri;
  Map<String, String>? headers;
  Duration? connectTimeout;

  @override
  WebSocketChannel connect(Uri uri, {required Map<String, String> headers, required Duration connectTimeout}) {
    this.uri = uri;
    this.headers = headers;
    this.connectTimeout = connectTimeout;
    return channel;
  }
}

final class _FakeWebSocketChannel() implements WebSocketChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
