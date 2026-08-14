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

  test("request envelope bounded encoding preserves exact bytes and yields", () async {
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
    const request = RelayRequest(
      id: "request-1",
      method: "POST",
      path: "/session/create",
      headers: {"content-type": "application/json"},
      body: '{"parts":[{"base64":"AQIDBAUGBwg="}]}',
    );
    final expected = utf8.encode(jsonEncode(request.toJson()));

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
            const RelayMessage.response(
              id: "request-1",
              status: 200,
              headers: <String, String>{},
              body: "{}",
            ).toJson(),
          ),
        ),
        encryptor: encryptor,
      ),
    );
    await responseFuture;
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
  });
}

class _FakeWebSocket() {
  this
    : _clientToServer = StreamController<Object?>.broadcast(), _serverToClient = StreamController<Object?>.broadcast() {
    channel = _StubChannel(
      stream: _serverToClient.stream,
      sink: _SinkAdapter(_clientToServer),
    );
  }

  final StreamController<Object?> _clientToServer;
  final StreamController<Object?> _serverToClient;
  late final WebSocketChannel channel;

  Stream<Object?> get outgoing => _clientToServer.stream;
  Sink<Object?> get serverSink => _serverToClient.sink;

  Future<void> close() async {
    if (!_serverToClient.isClosed) await _serverToClient.close();
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

class _SinkAdapter(final StreamController<Object?> _controller) implements WebSocketSink {
  @override
  void add(Object? data) => _controller.add(data);

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
