import "dart:async";
import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

class _MockRoomKeyStorage extends Mock implements RoomKeyStorage;

void main() {
  test("failed WebSocket handshake does not escape as an uncaught async error", () async {
    final roomKeyStorage = _MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => null);
    final client = RelayClient(
      relayHost: "127.0.0.1:0",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
    );
    final uncaughtErrors = <Object>[];

    await runZonedGuarded(
      () async {
        await expectLater(client.connect(), throwsA(isA<WebSocketChannelException>()));
        await client.disconnect();
        await Future<void>.delayed(Duration.zero);
      },
      (error, stackTrace) => uncaughtErrors.add(error),
    );

    expect(uncaughtErrors, isEmpty);
  });

  test("disconnect during a stalled WebSocket upgrade does not leave connect pending", () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final acceptedSocket = Completer<Socket>();
    final serverSubscription = server.listen((socket) {
      if (acceptedSocket.isCompleted) {
        socket.destroy();
      } else {
        acceptedSocket.complete(socket);
      }
    });
    final roomKeyStorage = _MockRoomKeyStorage();
    when(roomKeyStorage.getRoomKey).thenAnswer((_) async => null);
    final client = RelayClient(
      relayHost: "127.0.0.1:${server.port}",
      cryptoService: RelayCryptoService(),
      roomKeyStorage: roomKeyStorage,
      authToken: null,
    );
    final connectFuture = client.connect();
    final socket = await acceptedSocket.future.timeout(const Duration(seconds: 2));

    try {
      await client.disconnect().timeout(const Duration(seconds: 4));
      socket.destroy();
      await connectFuture.timeout(const Duration(seconds: 2));
    } finally {
      socket.destroy();
      await serverSubscription.cancel();
      await server.close();
      await connectFuture.catchError((Object _) {}).timeout(const Duration(seconds: 2), onTimeout: () {});
    }
  });
}
