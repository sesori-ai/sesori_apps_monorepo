import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
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
