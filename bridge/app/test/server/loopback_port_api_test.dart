import "dart:io";

import "package:sesori_bridge/src/server/api/loopback_port_api.dart";
import "package:test/test.dart";

void main() {
  group("LoopbackPortApi.isBindable", () {
    const api = LoopbackPortApi();

    test("returns true when a loopback port can be bound", () async {
      final reservedSocket = await ServerSocket.bind("127.0.0.1", 0);
      final port = reservedSocket.port;
      await reservedSocket.close();

      final isBindable = await api.isBindable(host: "127.0.0.1", port: port);

      expect(isBindable, isTrue);
    });

    test("returns false when a loopback port is already occupied", () async {
      final occupiedSocket = await ServerSocket.bind("127.0.0.1", 0);
      addTearDown(occupiedSocket.close);

      final isBindable = await api.isBindable(
        host: "127.0.0.1",
        port: occupiedSocket.port,
      );

      expect(isBindable, isFalse);
    });
  });
}
