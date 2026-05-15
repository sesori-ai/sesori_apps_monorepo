import "dart:io";

class LoopbackPortApi {
  const LoopbackPortApi();

  Future<bool> isBindable({
    required String host,
    required int port,
  }) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(host, port);
      return true;
    } on SocketException {
      return false;
    } finally {
      await socket?.close();
    }
  }
}
