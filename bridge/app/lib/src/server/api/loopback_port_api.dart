import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class const LoopbackPortApi() {
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
    } on Object catch (error, stackTrace) {
      Log.w("Unexpected error when trying to bind port $port", error, stackTrace);
      return false;
    } finally {
      await socket?.close();
    }
  }
}
