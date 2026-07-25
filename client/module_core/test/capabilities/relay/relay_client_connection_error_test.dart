import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

class _MockRoomKeyStorage extends Mock implements RoomKeyStorage {}

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
}
