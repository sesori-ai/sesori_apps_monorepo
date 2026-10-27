import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/api_paths.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

/// A bridge on the far side of a fake relay socket, so that a real
/// [RelayClient] and [ConnectionService] carry requests to it. It resumes the
/// stored room key and answers the health probe itself; [_answer] answers
/// every other request, and a request it returns null for waits, unanswered,
/// until the socket closes.
final class FakeRelayBridge({required final RelayResponse? Function(RelayRequest request) _answer}) {
  final Uint8List _roomKey = Uint8List.fromList(List<int>.generate(32, (index) => index));
  final StreamController<Object?> _fromPhone = StreamController<Object?>.broadcast();
  final StreamController<Object?> _toPhone = StreamController<Object?>.broadcast();
  final StreamController<RelayRequest> _unanswered = StreamController<RelayRequest>.broadcast();

  this {
    _fromPhone.stream.listen((frame) => unawaited(_onFrame(frame)));
  }

  late final SessionEncryptor _encryptor = RelayCryptoService().createSessionEncryptor(SecretKey(_roomKey));

  /// The requests the bridge leaves unanswered, as they arrive.
  Stream<RelayRequest> get unansweredRequests => _unanswered.stream;

  /// Closes the socket from the relay's side, as a network drop would.
  Future<void> closeSocket() async {
    if (!_toPhone.isClosed) await _toPhone.close();
  }

  /// A [ConnectionService] connected to this bridge. Its token refresh never
  /// answers, so after a drop it stays reconnecting.
  Future<ConnectionService> connect() async {
    final roomKeyStorage = MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => _roomKey);
    final relayClient = RelayClient.withChannelConnector(
      relayHost: "relay.example.com",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
      bridgeId: null,
      channelConnector: (_) => _FakeChannel(
        stream: _toPhone.stream,
        sink: _FakeSink(controller: _fromPhone),
      ),
      boundedJsonEncoder: null,
      maxPlaintextMessageBytes: RelayProtocol.maxPlaintextMessageBytes,
    );
    final authTokenProvider = MockAuthTokenProvider();
    when(
      () => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
    ).thenAnswer((_) => Completer<String?>().future);
    final lifecycleSource = FakeLifecycleSource();
    final authSession = FakeAuthSession(initialState: const AuthState.initial());
    final service = ConnectionService(
      RelayCryptoService(),
      roomKeyStorage,
      FakeTargetBridgeStorage(),
      authTokenProvider,
      authSession,
      lifecycleSource,
      MockFailureReporter(),
      relayClientFactory: _SingleRelayClientFactory(client: relayClient),
    );
    addTearDown(() async {
      service.dispose();
      await closeSocket();
      await _unanswered.close();
      await lifecycleSource.close();
      await authSession.dispose();
    });
    await service.connect(
      const ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token", bridgeId: null),
    );
    return service;
  }

  Future<void> _onFrame(Object? frameBytes) async {
    if (frameBytes is! List<int>) return;
    final message = RelayMessage.fromJson(
      jsonDecodeMap(utf8.decode(await unframe(frameBytes, encryptor: _encryptor))),
    );
    final reply = switch (message) {
      RelayResume() => const RelayMessage.resumeAck(),
      RelayRequest(:final id, path: ApiPaths.health) => RelayMessage.response(
        id: id,
        status: 200,
        headers: const {},
        body: jsonEncode(testHealthResponse().toJson()),
      ),
      final RelayRequest request => _answer(request),
      _ => null,
    };
    if (reply == null) {
      if (message is RelayRequest) _unanswered.add(message);
      return;
    }
    final replyFrame = await frame(utf8.encode(jsonEncode(reply.toJson())), encryptor: _encryptor);
    if (!_toPhone.isClosed) _toPhone.add(replyFrame);
  }
}

class _SingleRelayClientFactory({required final RelayClient _client}) extends RelayClientFactory {
  @override
  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
    required String? bridgeId,
  }) => _client;
}

class _FakeChannel({@override required final Stream<dynamic> stream, @override required final WebSocketSink sink})
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

class _FakeSink({required final StreamController<Object?> _controller}) implements WebSocketSink {
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
