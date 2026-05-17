import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

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
    } catch (err) {
      Log.w("Unexpected error when trying to bind port $port\n${err.toString()}");
      return false;
    } finally {
      await socket?.close();
    }
  }
}
