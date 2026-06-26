import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/control/control_channel_token_service.dart";
import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlChannelTokenService", () {
    test("sends a token_request and resolves with the matching token_response", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.requestToken();
      await pumpEventQueue();

      expect(client.sentFrames, hasLength(1));
      final request = _decode(client.sentFrames.single) as ControlTokenRequest;
      expect(request.forceRefresh, isFalse);

      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: "tok-123")));

      expect(await future, equals("tok-123"));
    });

    test("forwards forceRefresh in the request", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.requestToken(forceRefresh: true);
      await pumpEventQueue();

      final request = _decode(client.sentFrames.single) as ControlTokenRequest;
      expect(request.forceRefresh, isTrue);

      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: "tok")));
      await future;
    });

    test("a null access token surfaces a typed failure", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.requestToken();
      await pumpEventQueue();
      final request = _decode(client.sentFrames.single) as ControlTokenRequest;

      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: null)));

      await expectLater(future, throwsA(isA<ControlTokenUnavailableException>()));
    });

    test("times out with a typed failure when no response arrives", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      await expectLater(
        service.requestToken(timeout: const Duration(milliseconds: 20)),
        throwsA(isA<ControlTokenUnavailableException>()),
      );
    });

    test("correlates by id — a mismatched response is ignored", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.requestToken(timeout: const Duration(seconds: 5));
      await pumpEventQueue();
      final request = _decode(client.sentFrames.single) as ControlTokenRequest;

      client.emit(_encode(const ControlMessage.tokenResponse(id: "someone-else", accessToken: "wrong")));
      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: "right")));

      expect(await future, equals("right"));
    });

    test("ignores unrelated and undecodable frames", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.requestToken(timeout: const Duration(seconds: 5));
      await pumpEventQueue();
      final request = _decode(client.sentFrames.single) as ControlTokenRequest;

      client.emit("not valid json");
      client.emit(
        _encode(
          const ControlMessage.status(
            relay: ControlRelayConnectionState.connected,
            plugin: ControlPluginHealthState.healthy,
          ),
        ),
      );
      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: "ok")));

      expect(await future, equals("ok"));
    });

    test("dispose fails any in-flight request", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);

      final future = service.requestToken(timeout: const Duration(seconds: 30));
      await pumpEventQueue();
      final expectation = expectLater(future, throwsA(isA<ControlTokenUnavailableException>()));

      await service.dispose();
      await expectation;
    });

    test("requestToken after dispose fails fast without waiting for the timeout", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      await service.dispose();

      // A long timeout proves the failure is the disposed guard, not the timer.
      await expectLater(
        service.requestToken(timeout: const Duration(seconds: 30)),
        throwsA(isA<ControlTokenUnavailableException>()),
      );
      // No request frame is sent once disposed.
      expect(client.sentFrames, isEmpty);
    });

    test("dispose is idempotent", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);

      await service.dispose();
      await service.dispose();
    });
  });
}

ControlMessage _decode(String frame) => ControlMessage.fromJson(jsonDecodeMap(frame));

String _encode(ControlMessage message) => jsonEncode(message.toJson());

class _FakeControlChannelClient implements ControlChannelClient {
  final StreamController<String> _inbound = StreamController<String>.broadcast();
  final List<String> sentFrames = <String>[];

  void emit(String frame) => _inbound.add(frame);

  @override
  Stream<String> get inbound => _inbound.stream;

  @override
  void send(String frame) => sentFrames.add(frame);

  @override
  Stream<ControlChannelConnectionState> get connectionState => const Stream<ControlChannelConnectionState>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    await _inbound.close();
  }
}
