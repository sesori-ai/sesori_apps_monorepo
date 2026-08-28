import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/io_realtime_websocket_connector.dart";
import "package:web_socket_channel/web_socket_channel.dart";

void main() {
  group("IoRealtimeWebSocketConnector", () {
    test("forwards URI and headers to the IO client and returns its channel", () async {
      final channel = _FakeWebSocketChannel();
      final client = _CapturingIoRealtimeWebSocketClient(channel: channel);
      final connector = IoRealtimeWebSocketConnector(client: client);
      final uri = Uri.parse("wss://auth.example.test/voice/realtime");
      const headers = {"Authorization": "Bearer access-token", "X-Sesori-Device": "device-1"};
      const connectTimeout = Duration(seconds: 10);

      final result = await connector.connect(uri: uri, headers: headers, connectTimeout: connectTimeout);

      expect(result, same(channel));
      expect(client.uri, uri);
      expect(client.headers, headers);
      expect(client.connectTimeout, connectTimeout);
    });

    test("maps channel ready timeout to provider-neutral timeout while preserving cause", () async {
      final cause = TimeoutException("connect timed out");
      final channel = _ReadyFailureWebSocketChannel(error: cause);
      final connector = IoRealtimeWebSocketConnector(client: _CapturingIoRealtimeWebSocketClient(channel: channel));

      await expectLater(
        connector.connect(
          uri: Uri.parse("wss://auth.example.test/voice/realtime"),
          headers: const {},
          connectTimeout: const Duration(seconds: 10),
        ),
        throwsA(isA<RealtimeVoiceOpenTimeoutException>().having((error) => error.cause, "cause", same(cause))),
      );
    });

    test("maps HTTP 401 handshake failure to authentication", () async {
      await _expectStatusClassification(
        statusCode: 401,
        matcher: isA<RealtimeVoiceOpenAuthenticationException>(),
      );
    });

    test("maps HTTP 404 handshake failure to notFound", () async {
      await _expectStatusClassification(
        statusCode: 404,
        matcher: isA<RealtimeVoiceOpenHandshakeNotFoundException>().having((error) => error.httpStatus, "status", 404),
      );
    });

    test("maps HTTP 429 handshake failure to rateLimited", () async {
      await _expectStatusClassification(
        statusCode: 429,
        matcher: isA<RealtimeVoiceOpenHandshakeRateLimitedException>().having(
          (error) => error.httpStatus,
          "status",
          429,
        ),
      );
    });

    test("maps generic ready failure to transport", () async {
      final cause = WebSocketChannelException("network failed");
      final channel = _ReadyFailureWebSocketChannel(error: cause);
      final connector = IoRealtimeWebSocketConnector(client: _CapturingIoRealtimeWebSocketClient(channel: channel));

      await expectLater(
        connector.connect(
          uri: Uri.parse("wss://auth.example.test/voice/realtime"),
          headers: const {},
          connectTimeout: const Duration(seconds: 10),
        ),
        throwsA(isA<RealtimeVoiceOpenTransportException>().having((error) => error.cause, "cause", same(cause))),
      );
    });

    test("maps real IO failed ready to provider-neutral transport", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = Uri.parse("ws://127.0.0.1:${server.port}/voice/realtime");
      await server.close(force: true);
      final connector = IoRealtimeWebSocketConnector(client: IoRealtimeWebSocketClient());

      await expectLater(
        connector.connect(uri: uri, headers: const {}, connectTimeout: const Duration(milliseconds: 100)),
        throwsA(isA<RealtimeVoiceOpenTransportException>()),
      );
    });

    test("does not place bearer credentials in the WebSocket URI", () async {
      final channel = _FakeWebSocketChannel();
      final client = _CapturingIoRealtimeWebSocketClient(channel: channel);
      final connector = IoRealtimeWebSocketConnector(client: client);
      final uri = Uri.parse("wss://auth.example.test/voice/realtime?protocol=1");

      await connector.connect(
        uri: uri,
        headers: const {"Authorization": "Bearer secret-token"},
        connectTimeout: const Duration(seconds: 10),
      );

      expect(client.uri.toString(), isNot(contains("secret-token")));
      expect(client.uri!.queryParameters, {"protocol": "1"});
      expect(client.headers, {"Authorization": "Bearer secret-token"});
    });
  });
}

Future<void> _expectStatusClassification({required int statusCode, required Matcher matcher}) async {
  final cause = WebSocketChannelException.from(WebSocketException("handshake failed", statusCode));
  final channel = _ReadyFailureWebSocketChannel(error: cause);
  final connector = IoRealtimeWebSocketConnector(client: _CapturingIoRealtimeWebSocketClient(channel: channel));

  await expectLater(
    connector.connect(
      uri: Uri.parse("wss://auth.example.test/voice/realtime"),
      headers: const {},
      connectTimeout: const Duration(seconds: 10),
    ),
    throwsA(
      allOf(
        matcher,
        predicate<RealtimeVoiceOpenException>((error) => identical(error.cause, cause), "preserves cause"),
      ),
    ),
  );
}

final class _CapturingIoRealtimeWebSocketClient({required final WebSocketChannel channel})
    extends IoRealtimeWebSocketClient {
  Uri? uri;
  Map<String, String>? headers;
  Duration? connectTimeout;

  @override
  WebSocketChannel connect({required Uri uri, required Map<String, String> headers, required Duration connectTimeout}) {
    this.uri = uri;
    this.headers = headers;
    this.connectTimeout = connectTimeout;
    return channel;
  }
}

class _FakeWebSocketChannel() implements WebSocketChannel {
  final _sink = _FakeWebSocketSink();

  @override
  Future<void> get ready => Future<void>.value();

  @override
  WebSocketSink get sink => _sink;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ReadyFailureWebSocketChannel({required final Object error}) extends _FakeWebSocketChannel {
  @override
  Future<void> get ready => Future<void>.error(error);
}

final class _FakeWebSocketSink() implements WebSocketSink {
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
