import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:fake_async/fake_async.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_client.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_protocol.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "fake_realtime_voice_channel.dart";

const _ready = '{"type":"ready","protocolVersion":1,"maxSessionSeconds":900,"dailySecondsRemaining":420}';
const _complete = '{"type":"complete","reason":"finished","dailySecondsRemaining":419}';
const _error = '{"type":"error","code":"provider_unavailable","retryable":true}';
const _sampleRate = VoiceRealtimeSampleRate.hz16000;

void main() {
  group("with a fake channel", () {
    late FakeRealtimeVoiceChannel channel;
    late RealtimeVoiceClient client;
    Uri? connectedUri;
    Map<String, String>? connectedHeaders;

    setUp(() {
      channel = FakeRealtimeVoiceChannel();
      client = RealtimeVoiceClient.withChannelConnector(
        tokenProvider: FakeRealtimeVoiceTokenProvider(token: "secret-token"),
        channelConnector: ({required uri, required headers}) {
          connectedUri = uri;
          connectedHeaders = headers;
          return channel;
        },
      );
    });

    Future<RealtimeVoiceSession> openUpgraded() {
      channel.upgrade.complete();
      return client.open(sampleRate: _sampleRate, projectKey: null);
    }

    Future<RealtimeVoiceSession> openStreaming() async {
      final session = await openUpgraded();
      unawaited(session.events.drain<void>());
      channel.inbound.add(_ready);
      await pumpEventQueue();
      channel.outbound.clear();
      return session;
    }

    test("the token goes only in the upgrade header, and start is first, after the upgrade", () async {
      final opening = client.open(sampleRate: VoiceRealtimeSampleRate.hz24000, projectKey: null);
      await pumpEventQueue();
      expect(channel.outbound, isEmpty);

      channel.upgrade.complete();
      await opening;

      expect(connectedUri.toString(), "wss://api.sesori.com/voice/realtime");
      expect(connectedHeaders, {"Authorization": "Bearer secret-token"});
      expect(jsonDecode(channel.outbound.single! as String), {
        "type": "start",
        "protocolVersion": 1,
        "projectKey": null,
        "audio": {"encoding": "pcm_s16le", "sampleRate": 24000, "channels": 1},
      });
    });

    test("an upgrade that never answers fails after the timeout", () {
      fakeAsync((async) {
        Object? failure;
        unawaited(
          client
              .open(sampleRate: _sampleRate, projectKey: null)
              .then<void>((_) {}, onError: (Object error) => failure = error),
        );

        async.elapse(const Duration(seconds: 9));
        expect(failure, isNull);

        async.elapse(const Duration(seconds: 2));
        expect(
          failure,
          isA<RealtimeVoiceConnectionException>().having((error) => error.cause, "cause", isA<TimeoutException>()),
        );
      });
    });

    test("a failed upgrade closes the socket and sends nothing", () async {
      final opening = client.open(sampleRate: _sampleRate, projectKey: null);
      await pumpEventQueue();

      channel.upgrade.completeError(WebSocketChannelException("offline"));

      await expectLater(opening, throwsA(isA<RealtimeVoiceConnectionException>()));
      await pumpEventQueue();
      expect(channel.sinkCloseCode, realtimeVoiceNormalCloseCode);
      expect(channel.outbound, isEmpty);
    });

    test("frames and finish before ready are refused", () async {
      final session = await openUpgraded();
      channel.outbound.clear();

      expect(() => session.sendAudio(frame: Uint8List(2)), throwsStateError);
      expect(session.finish, throwsStateError);
      expect(channel.outbound, isEmpty);
    });

    test("after ready a frame must be 2..65536 bytes and even, and an error names only its size", () async {
      final session = await openStreaming();

      for (final size in [0, 1, 3, 65535, 65537, 65538]) {
        expect(
          () => session.sendAudio(frame: Uint8List(size)),
          throwsA(isA<ArgumentError>().having((error) => error.invalidValue, "invalidValue", size)),
        );
      }
      expect(channel.outbound, isEmpty);

      session.sendAudio(frame: Uint8List(2));
      session.sendAudio(frame: Uint8List(65536));
      expect(channel.outbound, hasLength(2));
    });

    test("finish sends one control, and audio after it is refused", () async {
      final session = await openStreaming();

      session.finish();
      session.finish();

      expect(channel.outbound, [realtimeVoiceFinishFrame]);
      expect(() => session.sendAudio(frame: Uint8List(2)), throwsStateError);
    });

    for (final (name, frame, matcher) in [
      ("complete", _complete, isA<RealtimeVoiceCompleteEvent>()),
      ("error", _error, isA<RealtimeVoiceErrorEvent>()),
    ]) {
      test("$name ends the session: the stream and socket close, and sends do nothing", () async {
        final session = await openUpgraded();
        final eventsDone = session.events.toList();
        channel.inbound
          ..add(_ready)
          ..add(frame)
          ..add('{"type":"transcript","confirmedDelta":"late","provisional":""}');

        expect(await eventsDone, [isA<RealtimeVoiceReadyEvent>(), matcher]);
        await pumpEventQueue();
        expect(channel.sinkCloseCode, realtimeVoiceNormalCloseCode);

        channel.outbound.clear();
        session.sendAudio(frame: Uint8List(2));
        session.finish();
        await session.cancel();
        expect(channel.outbound, isEmpty);
      });
    }

    test("a socket error is a failure that keeps its cause", () async {
      final session = await openUpgraded();
      final eventsDone = session.events.toList();
      final cause = StateError("socket broke");

      channel.inbound.addError(cause);

      final failure = (await eventsDone).single as RealtimeVoiceConnectionFailedEvent;
      expect(
        failure.exception,
        isA<RealtimeVoiceConnectionException>().having((error) => error.cause, "cause", same(cause)),
      );
    });

    for (final (name, frame) in <(String, Object)>[
      ("an unknown type", '{"type":"paused"}'),
      ("an unknown code", '{"type":"error","code":"rate_limited","retryable":true}'),
      ("a malformed frame", "{"),
      ("a binary frame", Uint8List(2)),
    ]) {
      test("$name fails the session and closes the socket", () async {
        final session = await openUpgraded();
        final eventsDone = session.events.toList();

        channel.inbound.add(frame);

        final failure = (await eventsDone).single as RealtimeVoiceConnectionFailedEvent;
        expect(failure.exception, isA<RealtimeVoiceProtocolException>());
        await pumpEventQueue();
        expect(channel.sinkCloseCode, realtimeVoiceNormalCloseCode);
      });
    }

    test("cancel before ready closes without a control the server would reject", () async {
      final session = await openUpgraded();
      final eventsDone = session.events.toList();
      channel.outbound.clear();

      await session.cancel();

      expect(channel.outbound, isEmpty);
      expect(channel.sinkCloseCode, realtimeVoiceNormalCloseCode);
      expect(await eventsDone, isEmpty);
    });

    test("cancel while streaming sends the control once, and after finish sends none", () async {
      final streaming = await openStreaming();
      await streaming.cancel();
      await streaming.cancel();
      expect(channel.outbound, [realtimeVoiceCancelFrame]);

      channel = FakeRealtimeVoiceChannel();
      final finishing = await openStreaming();
      finishing.finish();
      channel.outbound.clear();
      await finishing.cancel();
      expect(channel.outbound, isEmpty);
      expect(channel.sinkCloseCode, realtimeVoiceNormalCloseCode);
    });
  });

  group("over a real socket", () {
    late HttpServer server;
    late RealtimeVoiceClient client;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      client = RealtimeVoiceClient.withChannelConnector(
        tokenProvider: FakeRealtimeVoiceTokenProvider(token: "secret-token"),
        channelConnector: ({required uri, required headers}) => connectRealtimeVoiceChannel(
          uri: uri.replace(scheme: "ws", host: "127.0.0.1", port: port),
          headers: headers,
        ),
      );
    });

    tearDown(() => server.close(force: true));

    /// Upgrades every request, then hands each frame to [onFrame]. Completes with
    /// the close code the client sent.
    Future<int?> serve({required void Function(WebSocket socket, Object? frame) onFrame}) {
      final closed = Completer<int?>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((frame) => onFrame(socket, frame), onDone: () => closed.complete(socket.closeCode));
      });
      return closed.future;
    }

    for (final status in [401, 404, 429]) {
      test("an upgrade answered $status reports that status", () async {
        server.listen((request) {
          request.response.statusCode = status;
          unawaited(request.response.close());
        });

        await expectLater(
          client.open(sampleRate: _sampleRate, projectKey: null),
          throwsA(
            isA<RealtimeVoiceUpgradeRejectedException>()
                .having((error) => error.statusCode, "statusCode", status)
                .having((error) => error.toString(), "toString", isNot(contains("secret-token"))),
          ),
        );
      });
    }

    test("a refused connection is a connection failure", () async {
      await server.close(force: true);

      await expectLater(
        client.open(sampleRate: _sampleRate, projectKey: null),
        throwsA(isA<RealtimeVoiceConnectionException>()),
      );
    });

    test("a whole session: header, start first, audio after ready, finish, complete", () async {
      final received = <Object?>[];
      String? authorization;
      server.listen((request) async {
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((frame) {
          received.add(frame);
          if (received.length == 1) socket.add(_ready);
          if (frame == realtimeVoiceFinishFrame) {
            socket
              ..add('{"type":"transcript","confirmedDelta":"hello","provisional":""}')
              ..add(_complete);
            unawaited(socket.close(1000));
          }
        });
      });

      final session = await client.open(sampleRate: _sampleRate, projectKey: null);
      final seen = <RealtimeVoiceEvent>[];
      await for (final event in session.events) {
        seen.add(event);
        if (event is RealtimeVoiceReadyEvent) {
          session.sendAudio(frame: Uint8List.fromList([1, 2, 3, 4]));
          session.finish();
        }
      }

      expect(seen, [
        isA<RealtimeVoiceReadyEvent>(),
        isA<RealtimeVoiceTranscriptEvent>(),
        isA<RealtimeVoiceCompleteEvent>(),
      ]);
      expect(authorization, "Bearer secret-token");
      expect(jsonDecode(received[0]! as String), containsPair("type", "start"));
      expect(received[1], [1, 2, 3, 4]);
      expect(received[2], realtimeVoiceFinishFrame);
    });

    test("a close before ready is a failure carrying the real close code", () async {
      unawaited(serve(onFrame: (socket, _) => unawaited(socket.close(1011))));

      final session = await client.open(sampleRate: _sampleRate, projectKey: null);
      final events = await session.events.toList();

      expect(
        (events.single as RealtimeVoiceConnectionFailedEvent).exception,
        isA<RealtimeVoiceConnectionException>().having((error) => error.closeCode, "closeCode", 1011),
      );
    });

    test("a protocol violation closes the socket normally, with no stray error", () async {
      final closed = serve(onFrame: (socket, _) => socket.add('{"type":"paused"}'));

      final session = await client.open(sampleRate: _sampleRate, projectKey: null);
      final events = await session.events.toList();

      expect((events.single as RealtimeVoiceConnectionFailedEvent).exception, isA<RealtimeVoiceProtocolException>());
      expect(await closed, realtimeVoiceNormalCloseCode);
    });

    test("cancel reaches the server as the control, then a normal close", () async {
      final received = <Object?>[];
      final closed = serve(
        onFrame: (socket, frame) {
          received.add(frame);
          if (received.length == 1) socket.add(_ready);
        },
      );

      final session = await client.open(sampleRate: _sampleRate, projectKey: null);
      await session.events.firstWhere((event) => event is RealtimeVoiceReadyEvent);
      await session.cancel();

      expect(await closed, realtimeVoiceNormalCloseCode);
      expect(received.last, realtimeVoiceCancelFrame);
    });
  });
}
