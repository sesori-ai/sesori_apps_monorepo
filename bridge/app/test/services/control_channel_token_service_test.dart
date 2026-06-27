import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_bridge/src/services/control_channel_token_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlChannelTokenService", () {
    test("sends a token_request and resolves with the matching token_response", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.getAccessToken();
      await pumpEventQueue();

      expect(client.sentFrames, hasLength(1));
      final request = _decode(client.sentFrames.single) as ControlTokenRequest;
      expect(request.forceRefresh, isFalse);

      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: "tok-123")));

      expect(await future, equals("tok-123"));
    });

    test("forwards forceRefresh in the request and returns the fresh token", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();

      final request = _decode(client.sentFrames.single) as ControlTokenRequest;
      expect(request.forceRefresh, isTrue);

      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: "fresh")));
      expect(await future, equals("fresh"));
    });

    test("caches the latest pulled token for accessToken and tokenStream", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final emitted = <String>[];
      final subscription = service.tokenStream.listen(emitted.add);
      addTearDown(subscription.cancel);

      final first = service.getAccessToken();
      await pumpEventQueue();
      final firstRequest = _decode(client.sentFrames[0]) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: firstRequest.id, accessToken: "tok-1")));
      await first;

      expect(service.accessToken, equals("tok-1"));

      final second = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();
      final secondRequest = _decode(client.sentFrames[1]) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: secondRequest.id, accessToken: "tok-2")));
      await second;

      // The synchronous getter reflects the most recent pull, and the stream saw
      // both tokens in order.
      expect(service.accessToken, equals("tok-2"));
      await pumpEventQueue();
      expect(emitted, equals(<String>["tok-1", "tok-2"]));
    });

    test("accessToken throws before the first successful pull", () {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      expect(() => service.accessToken, throwsStateError);
    });

    test("a null access token surfaces a typed failure and leaves the cache empty", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.getAccessToken();
      await pumpEventQueue();
      final request = _decode(client.sentFrames.single) as ControlTokenRequest;

      client.emit(_encode(ControlMessage.tokenResponse(id: request.id, accessToken: null)));

      await expectLater(future, throwsA(isA<ControlTokenUnavailableException>()));
      expect(() => service.accessToken, throwsStateError);
    });

    test("maps a disconnected-channel send failure to a typed token failure", () async {
      final client = _FakeControlChannelClient()..throwOnSend = true;
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      await expectLater(
        service.getAccessToken(),
        throwsA(isA<ControlTokenUnavailableException>()),
      );
    });

    test("a slower older pull does not overwrite the newer cached token", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final first = service.getAccessToken();
      await pumpEventQueue();
      final second = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();

      final firstRequest = _decode(client.sentFrames[0]) as ControlTokenRequest;
      final secondRequest = _decode(client.sentFrames[1]) as ControlTokenRequest;

      // The newer (second, latest-issued) pull resolves first and caches its
      // token.
      client.emit(_encode(ControlMessage.tokenResponse(id: secondRequest.id, accessToken: "new")));
      expect(await second, equals("new"));
      expect(service.accessToken, equals("new"));

      // The older (first) pull's response arrives late: its caller still gets it,
      // but it must NOT clobber the newer cached token.
      client.emit(_encode(ControlMessage.tokenResponse(id: firstRequest.id, accessToken: "old")));
      expect(await first, equals("old"));
      await pumpEventQueue();
      expect(service.accessToken, equals("new"));
    });

    test("a failed newer pull does not block an older successful pull from caching", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final first = service.getAccessToken();
      await pumpEventQueue();
      final second = service.getAccessToken();
      await pumpEventQueue();

      final firstRequest = _decode(client.sentFrames[0]) as ControlTokenRequest;
      final secondRequest = _decode(client.sentFrames[1]) as ControlTokenRequest;

      // The newer (second) pull fails — the GUI couldn't supply a token.
      client.emit(_encode(ControlMessage.tokenResponse(id: secondRequest.id, accessToken: null)));
      await expectLater(second, throwsA(isA<ControlTokenUnavailableException>()));

      // The older (first) pull then succeeds: its valid token must still be
      // cached even though a newer request was issued (and failed) after it.
      client.emit(_encode(ControlMessage.tokenResponse(id: firstRequest.id, accessToken: "older-but-valid")));
      expect(await first, equals("older-but-valid"));
      await pumpEventQueue();
      expect(service.accessToken, equals("older-but-valid"));
    });

    test("times out with a typed failure when no response arrives", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(
        client: client,
        requestTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.getAccessToken(),
        throwsA(isA<ControlTokenUnavailableException>()),
      );
    });

    test("correlates by id — a mismatched response is ignored", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);
      addTearDown(service.dispose);

      final future = service.getAccessToken();
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

      final future = service.getAccessToken();
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

      final future = service.getAccessToken();
      await pumpEventQueue();
      final expectation = expectLater(future, throwsA(isA<ControlTokenUnavailableException>()));

      await service.dispose();
      await expectation;
    });

    test("getAccessToken after dispose fails fast without waiting for the timeout", () async {
      final client = _FakeControlChannelClient();
      // A long timeout proves the failure is the disposed guard, not the timer.
      final service = ControlChannelTokenService(
        client: client,
        requestTimeout: const Duration(seconds: 30),
      );
      await service.dispose();

      await expectLater(
        service.getAccessToken(),
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

    test("concurrent dispose callers await the same teardown", () async {
      final client = _FakeControlChannelClient();
      final service = ControlChannelTokenService(client: client);

      final first = service.dispose();
      final second = service.dispose();

      // Memoized: both callers observe the same in-progress teardown, so a
      // second caller can't complete before the first finishes.
      expect(identical(first, second), isTrue);
      await Future.wait<void>([first, second]);
    });
  });
}

ControlMessage _decode(String frame) => ControlMessage.fromJson(jsonDecodeMap(frame));

String _encode(ControlMessage message) => jsonEncode(message.toJson());

class _FakeControlChannelClient implements ControlChannelClient {
  final StreamController<String> _inbound = StreamController<String>.broadcast();
  final List<String> sentFrames = <String>[];

  /// Mimics [ControlChannelClient.send] throwing when the channel is down.
  bool throwOnSend = false;

  void emit(String frame) => _inbound.add(frame);

  @override
  Stream<String> get inbound => _inbound.stream;

  @override
  void send(String frame) {
    if (throwOnSend) {
      throw const ControlChannelNotConnectedException("Control channel is not connected");
    }
    sentFrames.add(frame);
  }

  @override
  Stream<ControlChannelConnectionState> get connectionState => const Stream<ControlChannelConnectionState>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    await _inbound.close();
  }
}
