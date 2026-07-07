import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/control/bridge_control_message_dispatcher.dart";
import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_bridge/src/services/control_channel_token_service.dart";
import "package:sesori_bridge/src/services/control_prompt_service.dart";
import "package:sesori_bridge/src/services/control_unregister_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  // The service no longer subscribes to the client itself — the dispatcher is
  // the single inbound subscriber — so these behaviour tests wire one over the
  // same fake client to keep driving the service with raw emitted frames.
  ControlChannelTokenService buildService(
    _FakeControlChannelClient client, {
    Duration? requestTimeout,
  }) {
    final service = requestTimeout == null
        ? ControlChannelTokenService(client: client)
        : ControlChannelTokenService(client: client, requestTimeout: requestTimeout);
    final dispatcher = BridgeControlMessageDispatcher(
      client: client,
      tokenService: service,
      promptService: ControlPromptService(client: client),
      unregisterService: _NoopUnregisterService(),
    )..start();
    addTearDown(dispatcher.dispose);
    return service;
  }

  group("ControlChannelTokenService", () {
    test("sends a token_request and resolves with the matching token_response", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
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
      final service = buildService(client);
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
      final service = buildService(client);
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
      final service = buildService(client);
      addTearDown(service.dispose);

      expect(() => service.accessToken, throwsStateError);
    });

    test("a null access token surfaces a typed failure and leaves the cache empty", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
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
      final service = buildService(client);
      addTearDown(service.dispose);

      await expectLater(
        service.getAccessToken(),
        throwsA(isA<ControlTokenUnavailableException>()),
      );
    });

    test("a pushed token_update is adopted into accessToken and tokenStream", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
      addTearDown(service.dispose);

      final emitted = <String>[];
      final subscription = service.tokenStream.listen(emitted.add);
      addTearDown(subscription.cancel);

      // A GUI push with no preceding pull seeds the cache directly.
      client.emit(_encode(const ControlMessage.tokenUpdate(accessToken: "pushed-1")));
      await pumpEventQueue();
      expect(service.accessToken, equals("pushed-1"));

      // A later push overwrites — the push is the authoritative steady-state
      // writer (last write wins, no pull-sequence gate).
      client.emit(_encode(const ControlMessage.tokenUpdate(accessToken: "pushed-2")));
      await pumpEventQueue();
      expect(service.accessToken, equals("pushed-2"));
      expect(emitted, equals(<String>["pushed-1", "pushed-2"]));
    });

    test("a pushed token_update clears a prior sign-out invalidation", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
      addTearDown(service.dispose);

      // Seed, then sign out (null response) which invalidates the cache.
      final first = service.getAccessToken();
      await pumpEventQueue();
      final firstRequest = _decode(client.sentFrames.single) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: firstRequest.id, accessToken: "tok")));
      await first;
      expect(service.accessToken, equals("tok"));

      final second = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();
      final secondRequest = _decode(client.sentFrames[1]) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: secondRequest.id, accessToken: null)));
      await expectLater(second, throwsA(isA<ControlTokenUnavailableException>()));
      expect(() => service.accessToken, throwsStateError);

      // A subsequent push re-signs-in: the getter is usable again.
      client.emit(_encode(const ControlMessage.tokenUpdate(accessToken: "re-signed-in")));
      await pumpEventQueue();
      expect(service.accessToken, equals("re-signed-in"));
    });

    test("a null token_response invalidates a previously cached token", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
      addTearDown(service.dispose);

      final first = service.getAccessToken();
      await pumpEventQueue();
      final firstRequest = _decode(client.sentFrames.single) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: firstRequest.id, accessToken: "tok")));
      await first;
      expect(service.accessToken, equals("tok"));

      // Signed out: the cached token must no longer be readable, so a reconnect
      // can never re-authenticate the relay from the stale token.
      final second = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();
      final secondRequest = _decode(client.sentFrames[1]) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: secondRequest.id, accessToken: null)));
      await expectLater(second, throwsA(isA<ControlTokenUnavailableException>()));
      expect(() => service.accessToken, throwsStateError);

      // A fresh successful pull restores it.
      final third = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();
      final thirdRequest = _decode(client.sentFrames[2]) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: thirdRequest.id, accessToken: "fresh")));
      await third;
      expect(service.accessToken, equals("fresh"));
    });

    test("an older in-flight pull does not clear a newer sign-out invalidation", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
      addTearDown(service.dispose);

      final first = service.getAccessToken();
      await pumpEventQueue();
      final second = service.getAccessToken();
      await pumpEventQueue();

      final firstRequest = _decode(client.sentFrames[0]) as ControlTokenRequest;
      final secondRequest = _decode(client.sentFrames[1]) as ControlTokenRequest;

      // The newer (second) pull resolves first with a sign-out (null), which
      // invalidates the cache.
      client.emit(_encode(ControlMessage.tokenResponse(id: secondRequest.id, accessToken: null)));
      await expectLater(second, throwsA(isA<ControlTokenUnavailableException>()));
      expect(() => service.accessToken, throwsStateError);

      // The older (first) pull then resolves with a token that was captured
      // BEFORE the sign-out. Its caller still receives it, but it must NOT clear
      // the newer invalidation — a reconnect must not re-auth from a pre-sign-out
      // token. Only a pull issued after the sign-out (or a push) may re-cache.
      client.emit(_encode(ControlMessage.tokenResponse(id: firstRequest.id, accessToken: "pre-sign-out")));
      expect(await first, equals("pre-sign-out"));
      await pumpEventQueue();
      expect(() => service.accessToken, throwsStateError);

      // A fresh pull issued after the sign-out restores the cache.
      final third = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();
      final thirdRequest = _decode(client.sentFrames[2]) as ControlTokenRequest;
      client.emit(_encode(ControlMessage.tokenResponse(id: thirdRequest.id, accessToken: "fresh")));
      await third;
      expect(service.accessToken, equals("fresh"));
    });

    test("a pushed token_update wins over a slower older pull response", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
      addTearDown(service.dispose);

      // A pull is issued, then the GUI pushes a fresher token before the pull's
      // own response arrives.
      final pull = service.getAccessToken();
      await pumpEventQueue();
      final pullRequest = _decode(client.sentFrames.single) as ControlTokenRequest;

      client.emit(_encode(const ControlMessage.tokenUpdate(accessToken: "pushed")));
      await pumpEventQueue();
      expect(service.accessToken, equals("pushed"));

      // The older pull now resolves: its caller still gets its token, but it must
      // not revert the cache to the older value the push superseded.
      client.emit(_encode(ControlMessage.tokenResponse(id: pullRequest.id, accessToken: "older-pull")));
      expect(await pull, equals("older-pull"));
      await pumpEventQueue();
      expect(service.accessToken, equals("pushed"));
    });

    test("the newest-issued pull wins even when an older pull completes first", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
      addTearDown(service.dispose);

      // Two overlapping pulls: the older (first-issued) and the newer (e.g. a
      // forced reconnect refresh issued while a routine pull is still in flight).
      final older = service.getAccessToken();
      await pumpEventQueue();
      final newer = service.getAccessToken(forceRefresh: true);
      await pumpEventQueue();

      final olderRequest = _decode(client.sentFrames[0]) as ControlTokenRequest;
      final newerRequest = _decode(client.sentFrames[1]) as ControlTokenRequest;

      // The OLDER pull happens to complete first and caches its token.
      client.emit(_encode(ControlMessage.tokenResponse(id: olderRequest.id, accessToken: "older")));
      expect(await older, equals("older"));
      await pumpEventQueue();
      expect(service.accessToken, equals("older"));

      // The newer pull then completes: its fresher token must win, since it was
      // issued later — not be masked just because the older one finished first.
      client.emit(_encode(ControlMessage.tokenResponse(id: newerRequest.id, accessToken: "newer")));
      expect(await newer, equals("newer"));
      await pumpEventQueue();
      expect(service.accessToken, equals("newer"));
    });

    test("times out with a typed failure when no response arrives", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client, requestTimeout: const Duration(milliseconds: 20));
      addTearDown(service.dispose);

      await expectLater(
        service.getAccessToken(),
        throwsA(isA<ControlTokenUnavailableException>()),
      );
    });

    test("correlates by id — a mismatched response is ignored", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);
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
      final service = buildService(client);
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
      final service = buildService(client);

      final future = service.getAccessToken();
      await pumpEventQueue();
      final expectation = expectLater(future, throwsA(isA<ControlTokenUnavailableException>()));

      await service.dispose();
      await expectation;
    });

    test("getAccessToken after dispose fails fast without waiting for the timeout", () async {
      final client = _FakeControlChannelClient();
      // A long timeout proves the failure is the disposed guard, not the timer.
      final service = buildService(client, requestTimeout: const Duration(seconds: 30));
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
      final service = buildService(client);

      await service.dispose();
      await service.dispose();
    });

    test("concurrent dispose callers await the same teardown", () async {
      final client = _FakeControlChannelClient();
      final service = buildService(client);

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

/// The token-service tests wire a real dispatcher but never exercise the logout
/// command, so its unregister delegate is a no-op stand-in.
class _NoopUnregisterService implements ControlUnregisterService {
  @override
  Future<void> handleUnregisterAndExit() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
