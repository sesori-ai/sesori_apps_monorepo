import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/utils/bounded_json_encoder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

class _MockRoomKeyStorage() extends Mock implements RoomKeyStorage;

void main() {
  test("replays resume when the bridge reconnects during handshake", () async {
    final roomKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final roomKeyStorage = _MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => roomKey);
    final socket = _FakeWebSocket();
    final client = RelayClient.withChannelConnector(
      relayHost: "relay.example.com",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
      channelConnector: (_) => socket.channel,
      boundedJsonEncoder: null,
      maxPlaintextMessageBytes: RelayProtocol.maxPlaintextMessageBytes,
    );
    final outgoing = StreamIterator<Object?>(socket.outgoing);
    addTearDown(() async {
      await outgoing.cancel();
      await client.disconnect();
      await socket.close();
    });

    final firstFrameReady = outgoing.moveNext();
    final connectFuture = client.connect();
    expect(await firstFrameReady.timeout(const Duration(seconds: 1)), isTrue);
    final firstFrame = Uint8List.fromList(outgoing.current! as List<int>);

    socket.serverSink.add('{"type":"${RelayProtocol.typeBridgeConnected}"}');
    await Future<void>.delayed(Duration.zero);

    final replayReady = outgoing.moveNext();
    socket.serverSink.add('{"type":"${RelayProtocol.typeBridgeConnected}"}');
    expect(await replayReady.timeout(const Duration(seconds: 1)), isTrue);
    final replayedFrame = Uint8List.fromList(outgoing.current! as List<int>);
    expect(replayedFrame, firstFrame);

    final encryptor = RelayCryptoService().createSessionEncryptor(SecretKey(roomKey));
    final resumeAck = await frame(
      utf8.encode(jsonEncode(const RelayMessage.resumeAck().toJson())),
      encryptor: encryptor,
    );
    socket.serverSink.add(resumeAck);

    await connectFuture.timeout(const Duration(seconds: 1));
    expect(client.isConnected, isTrue);
    expect(client.didResume, isTrue);
    verifyNever(roomKeyStorage.clearRoomKey);
  });

  test("representative offer preserves plaintext through encryption and correlates answer", () async {
    final roomKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final roomKeyStorage = _MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => roomKey);
    final socket = _FakeWebSocket();
    var yields = 0;
    final serializationStarted = Completer<void>();
    final serializationGate = Completer<void>();
    final client = RelayClient.withChannelConnector(
      relayHost: "relay.example.com",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
      channelConnector: (_) => socket.channel,
      boundedJsonEncoder: BoundedJsonEncoder(
        chunkSize: 16,
        yieldTurn: () async {
          yields++;
          if (!serializationStarted.isCompleted) {
            serializationStarted.complete();
            await serializationGate.future;
          }
        },
      ),
      maxPlaintextMessageBytes: RelayProtocol.maxPlaintextMessageBytes,
    );
    final outgoing = StreamIterator<Object?>(socket.outgoing);
    addTearDown(() async {
      await outgoing.cancel();
      await client.disconnect();
      await socket.close();
    });
    final resumeReady = outgoing.moveNext();
    final connectFuture = client.connect();
    expect(await resumeReady.timeout(const Duration(seconds: 1)), isTrue);
    final encryptor = RelayCryptoService().createSessionEncryptor(SecretKey(roomKey));
    socket.serverSink.add(
      await frame(utf8.encode(jsonEncode(const RelayMessage.resumeAck().toJson())), encryptor: encryptor),
    );
    await connectFuture.timeout(const Duration(seconds: 1));
    final requestBody = jsonEncode(_offerFixture());
    final request = RelayRequest(
      id: "request-1",
      method: "POST",
      path: "/test/device-canvas/signaling",
      headers: const {"content-type": "application/json"},
      body: requestBody,
    );
    final expected = utf8.encode(jsonEncode(request.toJson()));
    final responseBody = jsonEncode(_answerFixture());

    final frameReady = outgoing.moveNext();
    final responseFuture = client.sendRequest(request: request, timeout: const Duration(seconds: 1));
    await serializationStarted.future;
    expect(client.pendingRequestCount, 0);
    serializationGate.complete();
    expect(await frameReady.timeout(const Duration(seconds: 1)), isTrue);
    final plaintext = await unframe(Uint8List.fromList(outgoing.current! as List<int>), encryptor: encryptor);
    expect(plaintext, expected);
    expect(yields, (expected.length - 1) ~/ 16);
    socket.serverSink.add(
      await frame(
        utf8.encode(
          jsonEncode(
            RelayMessage.response(
              id: "different-request",
              status: 200,
              headers: const <String, String>{},
              body: jsonEncode({"unexpected": true}),
            ).toJson(),
          ),
        ),
        encryptor: encryptor,
      ),
    );
    socket.serverSink.add(
      await frame(
        utf8.encode(
          jsonEncode(
            RelayMessage.response(
              id: "request-1",
              status: 200,
              headers: const <String, String>{},
              body: responseBody,
            ).toJson(),
          ),
        ),
        encryptor: encryptor,
      ),
    );
    final response = await responseFuture;
    expect(response.id, "request-1");
    expect(response.body, responseBody);
    expect(_hasMatchingFingerprint(jsonDecode(response.body!) as Map<String, dynamic>), isTrue);
  });

  test("request prepared before socket disconnect is not dispatched", () async {
    final roomKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final roomKeyStorage = _MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => roomKey);
    final socket = _FakeWebSocket();
    final serializationStarted = Completer<void>();
    final serializationGate = Completer<void>();
    final client = RelayClient.withChannelConnector(
      relayHost: "relay.example.com",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
      channelConnector: (_) => socket.channel,
      boundedJsonEncoder: BoundedJsonEncoder(
        chunkSize: 8,
        yieldTurn: () async {
          if (!serializationStarted.isCompleted) {
            serializationStarted.complete();
            await serializationGate.future;
          }
        },
      ),
      maxPlaintextMessageBytes: RelayProtocol.maxPlaintextMessageBytes,
    );
    final outgoing = StreamIterator<Object?>(socket.outgoing);
    addTearDown(() async {
      if (!serializationGate.isCompleted) serializationGate.complete();
      await outgoing.cancel();
      await client.disconnect();
      await socket.close();
    });
    final resumeReady = outgoing.moveNext();
    final connectFuture = client.connect();
    expect(await resumeReady.timeout(const Duration(seconds: 1)), isTrue);
    final encryptor = RelayCryptoService().createSessionEncryptor(SecretKey(roomKey));
    socket.serverSink.add(
      await frame(utf8.encode(jsonEncode(const RelayMessage.resumeAck().toJson())), encryptor: encryptor),
    );
    await connectFuture.timeout(const Duration(seconds: 1));
    const request = RelayRequest(
      id: "disconnected-request",
      method: "POST",
      path: "/session/create",
      headers: {"content-type": "application/json"},
      body: "abcdefghijklmnopqrstuvwxyz",
    );

    final responseFuture = client.sendRequest(request: request, timeout: const Duration(seconds: 1));
    await serializationStarted.future;
    await socket.closeServer();
    serializationGate.complete();

    await expectLater(
      responseFuture,
      throwsA(isA<StateError>()),
    );
    expect(client.pendingRequestCount, 0);
    expect(await outgoing.moveNext(), isFalse);
  });

  test("request envelope reports exact bytes through reduced max seam", () async {
    final roomKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final roomKeyStorage = _MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => roomKey);
    final socket = _FakeWebSocket();
    const request = RelayRequest(
      id: "max-request",
      method: "POST",
      path: "/session/create",
      headers: {"content-type": "application/json"},
      body: "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz",
    );
    final expectedBytes = utf8.encode(jsonEncode(request.toJson()));
    final client = RelayClient.withChannelConnector(
      relayHost: "relay.example.com",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
      channelConnector: (_) => socket.channel,
      boundedJsonEncoder: BoundedJsonEncoder(chunkSize: 8, yieldTurn: () async {}),
      maxPlaintextMessageBytes: expectedBytes.length - 1,
    );
    final outgoing = StreamIterator<Object?>(socket.outgoing);
    addTearDown(() async {
      await outgoing.cancel();
      await client.disconnect();
      await socket.close();
    });
    final resumeReady = outgoing.moveNext();
    final connectFuture = client.connect();
    expect(await resumeReady.timeout(const Duration(seconds: 1)), isTrue);
    final encryptor = RelayCryptoService().createSessionEncryptor(SecretKey(roomKey));
    socket.serverSink.add(
      await frame(utf8.encode(jsonEncode(const RelayMessage.resumeAck().toJson())), encryptor: encryptor),
    );
    await connectFuture.timeout(const Duration(seconds: 1));

    await expectLater(
      client.sendRequest(request: request, timeout: const Duration(seconds: 1)),
      throwsA(
        isA<RelayMessageTooLargeException>()
            .having((error) => error.plaintextBytes, "plaintextBytes", expectedBytes.length)
            .having((error) => error.maxPlaintextBytes, "maxPlaintextBytes", expectedBytes.length - 1),
      ),
    );
  });

  test("SSE subscription requests stored attachment references", () async {
    final roomKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final roomKeyStorage = _MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => roomKey);
    final socket = _FakeWebSocket();
    final client = RelayClient.withChannelConnector(
      relayHost: "relay.example.com",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
      channelConnector: (_) => socket.channel,
      boundedJsonEncoder: null,
      maxPlaintextMessageBytes: RelayProtocol.maxPlaintextMessageBytes,
    );
    final outgoing = StreamIterator<Object?>(socket.outgoing);
    addTearDown(() async {
      await outgoing.cancel();
      await client.disconnect();
      await socket.close();
    });

    final resumeReady = outgoing.moveNext();
    final connectFuture = client.connect();
    expect(await resumeReady.timeout(const Duration(seconds: 1)), isTrue);
    final encryptor = RelayCryptoService().createSessionEncryptor(SecretKey(roomKey));
    socket.serverSink.add(
      await frame(utf8.encode(jsonEncode(const RelayMessage.resumeAck().toJson())), encryptor: encryptor),
    );
    await connectFuture.timeout(const Duration(seconds: 1));

    client.subscribeSse("/event");
    expect(await outgoing.moveNext().timeout(const Duration(seconds: 1)), isTrue);
    final payload = await unframe(Uint8List.fromList(outgoing.current! as List<int>), encryptor: encryptor);
    final message = RelayMessage.fromJson(jsonDecode(utf8.decode(payload)) as Map<String, dynamic>);

    expect(
      message,
      const RelayMessage.sseSubscribe(path: "/event", attachmentDelivery: MessageAttachmentDelivery.storedReference),
    );

    final uncaughtErrors = <Object>[];
    await runZonedGuarded(
      () async {
        socket.failSends();
        client.subscribeSse("/replacement");
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      (error, _) => uncaughtErrors.add(error),
    )!;
    expect(uncaughtErrors, isEmpty);
  });
}

const _offerFingerprint =
    "sha-256 00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:10:21:32:43:54:65:76:87:98:A9:BA:CB:DC:ED:FE:0F";
const _answerFingerprint =
    "sha-256 FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00:0F:1E:2D:3C:4B:5A:69:78:87:96:A5:B4:C3:D2:E1:F0";

Map<String, dynamic> _offerFixture() {
  return {
    "bridgeId": "bridge-1",
    "claimRevision": 42,
    "leaseId": "lease-1",
    "description": {
      "type": "offer",
      "sdp": _sdp(
        fingerprint: _offerFingerprint,
        setup: "actpass",
        direction: "recvonly",
        iceUfrag: "offerufrag",
        icePwd: "offerpassword123456789012",
      ),
      "fingerprint": _offerFingerprint,
    },
    "iceCandidates": [
      {
        "candidate": "candidate:1 1 udp 2122260223 192.0.2.1 50000 typ host",
        "sdpMid": "0",
        "sdpMLineIndex": 0,
      },
    ],
  };
}

Map<String, dynamic> _answerFixture() {
  return {
    "bridgeId": "bridge-1",
    "claimRevision": 42,
    "leaseId": "lease-1",
    "description": {
      "type": "answer",
      "sdp": _sdp(
        fingerprint: _answerFingerprint,
        setup: "active",
        direction: "sendonly",
        iceUfrag: "answerufrag",
        icePwd: "answerpassword1234567890",
      ),
      "fingerprint": _answerFingerprint,
    },
    "iceCandidates": [
      {
        "candidate": "candidate:2 1 udp 16777215 192.0.2.2 50001 typ relay raddr 0.0.0.0 rport 0",
        "sdpMid": "0",
        "sdpMLineIndex": 0,
      },
    ],
    "turn": {
      "urls": ["turn:relay.example.com:3478?transport=udp"],
      "username": "ephemeral-user",
      "credential": "ephemeral-secret",
      "expiresAt": "2026-08-25T17:15:00Z",
    },
  };
}

String _sdp({
  required String fingerprint,
  required String setup,
  required String direction,
  required String iceUfrag,
  required String icePwd,
}) {
  return "v=0\r\n"
      "o=- 1 2 IN IP4 127.0.0.1\r\n"
      "s=-\r\n"
      "t=0 0\r\n"
      "m=video 9 UDP/TLS/RTP/SAVPF 96\r\n"
      "c=IN IP4 0.0.0.0\r\n"
      "a=fingerprint:$fingerprint\r\n"
      "a=setup:$setup\r\n"
      "a=ice-ufrag:$iceUfrag\r\n"
      "a=ice-pwd:$icePwd\r\n"
      "a=mid:0\r\n"
      "a=rtcp-mux\r\n"
      "a=$direction\r\n"
      "a=rtpmap:96 H264/90000\r\n";
}

bool _hasMatchingFingerprint(Map<String, dynamic> signaling) {
  final description = signaling["description"] as Map<String, dynamic>?;
  final fingerprint = description?["fingerprint"] as String?;
  final sdp = description?["sdp"] as String?;
  if (fingerprint == null || sdp == null) return false;
  final fingerprintLines = sdp.split("\r\n").where((line) => line.startsWith("a=fingerprint:")).toList();
  return fingerprintLines.length == 1 && fingerprintLines.single == "a=fingerprint:$fingerprint";
}

class _FakeWebSocket() {
  this
    : _clientToServer = StreamController<Object?>.broadcast(), _serverToClient = StreamController<Object?>.broadcast() {
    channel = _StubChannel(
      stream: _serverToClient.stream,
      sink: _SinkAdapter(_clientToServer, shouldFail: () => _failSends),
    );
  }

  final StreamController<Object?> _clientToServer;
  final StreamController<Object?> _serverToClient;
  bool _failSends = false;
  late final WebSocketChannel channel;

  Stream<Object?> get outgoing => _clientToServer.stream;
  Sink<Object?> get serverSink => _serverToClient.sink;

  void failSends() {
    _failSends = true;
  }

  Future<void> closeServer() async {
    if (!_serverToClient.isClosed) await _serverToClient.close();
  }

  Future<void> close() async {
    await closeServer();
    if (!_clientToServer.isClosed) await _clientToServer.close();
  }
}

class _StubChannel({@override required final Stream<dynamic> stream, @override required final WebSocketSink sink})
    implements WebSocketChannel {
  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SinkAdapter(
  final StreamController<Object?> _controller, {
  required final bool Function() shouldFail,
}) implements WebSocketSink {
  @override
  void add(Object? data) {
    if (shouldFail()) throw StateError("socket disconnected");
    _controller.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Object?> stream) => _controller.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> get done => _controller.done;
}
