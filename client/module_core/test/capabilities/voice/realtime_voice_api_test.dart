import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

// ignore: use_primary_constructors, fake state is clearer with field declarations
class _TokenProvider extends Mock implements AuthTokenProvider {
  final List<bool> forceRefreshes = [];

  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async {
    forceRefreshes.add(forceRefresh);
    return "fresh-token-${forceRefreshes.length}";
  }
}

class _NullTokenProvider() extends Mock implements AuthTokenProvider {
  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async {
    return null;
  }
}

// ignore: use_primary_constructors, fake state is clearer with field declarations
class _Connector implements RealtimeWebSocketConnector {
  final channel = _FakeChannel();
  final Completer<WebSocketChannel> connectCompleter = Completer<WebSocketChannel>();
  Uri? uri;
  Map<String, String>? headers;
  Duration? connectTimeout;
  bool useDelayedConnect = false;

  @override
  Future<WebSocketChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
    required Duration connectTimeout,
  }) async {
    this.uri = uri;
    this.headers = headers;
    this.connectTimeout = connectTimeout;
    if (useDelayedConnect) {
      return await connectCompleter.future;
    }
    return channel;
  }

  void completeConnect() {
    channel.completeReady();
    if (!connectCompleter.isCompleted) {
      connectCompleter.complete(channel);
    }
  }
}

// ignore: use_primary_constructors, WebSocket fake exposes mutable test hooks
class _FakeChannel extends Mock implements WebSocketChannel {
  final StreamController<Object?> inbound = StreamController<Object?>();
  final List<Object?> outbound = [];
  final Completer<void> readyCompleter = Completer<void>();
  final _sinkDone = Completer<void>();
  int? _closeCode;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => readyCompleter.future;

  @override
  Stream<dynamic> get stream => inbound.stream;

  @override
  WebSocketSink get sink => _Sink(outbound, _sinkDone, (code) => _closeCode = code);

  void completeReady() {
    if (!readyCompleter.isCompleted) readyCompleter.complete();
  }

  void failReady(Object error) {
    if (!readyCompleter.isCompleted) readyCompleter.completeError(error);
  }
}

class _Sink(
  final List<Object?> outboundItems,
  final Completer<void> sinkDone,
  final void Function(int? code) closeCodeSetter,
) implements WebSocketSink {
  final List<Object?> outbound = outboundItems;
  final Completer<void> doneCompleter = sinkDone;
  final void Function(int? code) setCloseCode = closeCodeSetter;

  @override
  Future<void> get done => doneCompleter.future;

  @override
  void add(Object? event) => outbound.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async => await stream.forEach(outbound.add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    setCloseCode(closeCode);
    if (!doneCompleter.isCompleted) doneCompleter.complete();
  }
}

void main() {
  late _TokenProvider tokenProvider;
  late _Connector connector;
  late RealtimeVoiceApi api;

  setUp(() {
    tokenProvider = _TokenProvider();
    connector = _Connector();
    connector.channel.completeReady();
    api = RealtimeVoiceApi(connector: connector, tokenProvider: tokenProvider);
  });

  test("Given a realtime start When connecting Then uses fresh bearer upgrade header and start frame only", () async {
    final session = await api.start(
      audio: const RealtimeAudioFormat(sampleRate: 16000),
      projectKey: deriveProjectGlossaryKey("project-123"),
    );

    expect(connector.uri, Uri.parse("wss://api.sesori.com/voice/realtime"));
    expect(connector.headers, {"Authorization": "Bearer fresh-token-1"});
    expect(connector.connectTimeout, realtimeVoiceConnectTimeout);
    expect(tokenProvider.forceRefreshes, [false]);
    expect(connector.uri.toString(), isNot(contains("fresh-token")));
    expect(connector.uri.toString(), isNot(contains("project-123")));
    final start = jsonDecode(connector.channel.outbound.single! as String) as Map<String, Object?>;
    expect(connector.channel.outbound.single.toString(), isNot(contains("fresh-token")));
    expect(start, {
      "type": "start",
      "protocolVersion": 1,
      "projectKey": deriveProjectGlossaryKey("project-123"),
      "audio": {"encoding": "pcm_s16le", "sampleRate": 16000, "channels": 1},
    });
    await session.close();
  });

  test("Given an async WebSocket connection When starting Then waits for ready before sending start", () async {
    connector = _Connector();
    connector.useDelayedConnect = true;
    api = RealtimeVoiceApi(connector: connector, tokenProvider: tokenProvider);

    final startFuture = api.start(audio: const RealtimeAudioFormat(sampleRate: 16000), projectKey: null);
    await pumpEventQueue();

    expect(connector.channel.outbound, isEmpty);

    connector.completeConnect();
    final session = await startFuture;

    expect(jsonDecode(connector.channel.outbound.single! as String), {
      "type": "start",
      "protocolVersion": 1,
      "projectKey": null,
      "audio": {"encoding": "pcm_s16le", "sampleRate": 16000, "channels": 1},
    });
    await session.close();
  });

  test(
    "Given the WebSocket handshake fails asynchronously When starting Then closes and propagates ready error",
    () async {
      connector = _Connector();
      connector.useDelayedConnect = true;
      api = RealtimeVoiceApi(connector: connector, tokenProvider: tokenProvider);
      final error = RealtimeVoiceOpenAuthenticationException(cause: StateError("unauthorized"), httpStatus: 401);

      final startFuture = api.start(audio: const RealtimeAudioFormat(sampleRate: 16000), projectKey: null);
      await pumpEventQueue();
      connector.connectCompleter.completeError(error);

      await expectLater(startFuture, throwsA(same(error)));
      expect(connector.channel.outbound, isEmpty);
    },
  );

  test("Given no fresh token When starting Then throws provider-neutral authentication open failure", () async {
    api = RealtimeVoiceApi(connector: connector, tokenProvider: _NullTokenProvider());

    await expectLater(
      api.start(audio: const RealtimeAudioFormat(sampleRate: 16000), projectKey: null),
      throwsA(
        isA<RealtimeVoiceOpenAuthenticationException>()
            .having((error) => error.cause, "cause", isNull)
            .having((error) => error.httpStatus, "httpStatus", isNull),
      ),
    );
    expect(connector.uri, isNull);
  });

  test("Given a realtime session When sending audio and finish Then forwards binary and waits for terminal", () async {
    final session = await api.start(audio: const RealtimeAudioFormat(sampleRate: 48000), projectKey: null);

    session.sendAudio(Uint8List.fromList([1, 2, 3, 4]));
    final terminal = session.finish();

    expect(connector.channel.outbound[1], isA<Uint8List>());
    expect(jsonDecode(connector.channel.outbound[2]! as String), {"type": "finish"});
    connector.channel.inbound.add(jsonEncode({"type": "complete", "reason": "finished", "dailySecondsRemaining": 99}));
    expect(await terminal, isA<RealtimeVoiceCompleteEvent>());
  });

  test("Given malformed inbound data When received Then emits stream error and closes", () async {
    final session = await api.start(audio: const RealtimeAudioFormat(sampleRate: 16000), projectKey: null);
    final errors = <Object>[];
    final subscription = session.events.listen(null, onError: errors.add);

    connector.channel.inbound.add(Uint8List.fromList([1, 2]));
    await pumpEventQueue(times: 3);

    expect(errors.single, isA<RealtimeVoiceProtocolException>());
    expect(connector.channel.closeCode, 1000);
    await subscription.cancel();
  });

  test("Given transport closes before finish When finish is requested Then it fails promptly", () async {
    final session = await api.start(audio: const RealtimeAudioFormat(sampleRate: 16000), projectKey: null);

    await connector.channel.inbound.close();
    await pumpEventQueue(times: 3);

    await expectLater(session.finish(), throwsA(isA<RealtimeVoiceTransportClosedException>()));
    expect(connector.channel.outbound, hasLength(1));
  });

  test("Given transport closes after finish When waiting for terminal Then it fails promptly", () async {
    final session = await api.start(audio: const RealtimeAudioFormat(sampleRate: 16000), projectKey: null);

    final terminal = session.finish();
    expect(jsonDecode(connector.channel.outbound[1]! as String), {"type": "finish"});
    await connector.channel.inbound.close();

    await expectLater(terminal, throwsA(isA<RealtimeVoiceTransportClosedException>()));
  });

  test("Given invalid audio frames When sending audio Then rejects client-side before socket send", () async {
    final session = await api.start(audio: const RealtimeAudioFormat(sampleRate: 16000), projectKey: null);

    expect(() => session.sendAudio(Uint8List(0)), throwsA(isA<RealtimeVoiceProtocolException>()));
    expect(() => session.sendAudio(Uint8List(3)), throwsA(isA<RealtimeVoiceProtocolException>()));
    expect(() => session.sendAudio(Uint8List(65538)), throwsA(isA<RealtimeVoiceProtocolException>()));

    expect(connector.channel.outbound, hasLength(1));
    await session.close();
  });

  test("Given server events When received Then parses provider-neutral sealed events and terminal close", () async {
    final session = await api.start(audio: const RealtimeAudioFormat(sampleRate: 24000), projectKey: null);
    final events = <RealtimeVoiceEvent>[];
    final subscription = session.events.listen(events.add);

    connector.channel.inbound.add(
      jsonEncode({
        "type": "ready",
        "protocolVersion": 1,
        "maxSessionSeconds": 900,
        "dailySecondsRemaining": 100,
      }),
    );
    connector.channel.inbound.add(jsonEncode({"type": "transcript", "confirmedDelta": "hello", "provisional": ""}));
    connector.channel.inbound.add(jsonEncode({"type": "complete", "reason": "finished", "dailySecondsRemaining": 99}));
    await pumpEventQueue(times: 3);

    expect(events, [
      isA<RealtimeVoiceReadyEvent>(),
      isA<RealtimeVoiceTranscriptEvent>(),
      isA<RealtimeVoiceCompleteEvent>(),
    ]);
    await subscription.cancel();
  });

  test("Given drag cancellation When cancelling Then sends strict cancel and closes normally", () async {
    final session = await api.start(audio: const RealtimeAudioFormat(sampleRate: 44100), projectKey: null);

    await session.cancel();

    expect(jsonDecode(connector.channel.outbound[1]! as String), {"type": "cancel"});
    expect(connector.channel.closeCode, 1000);
  });
}
