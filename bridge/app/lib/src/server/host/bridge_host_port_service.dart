import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show HostPortService;

import "../api/loopback_port_api.dart";

class const BridgeHostPortService({
  required final LoopbackPortApi _loopbackPortApi,
}) implements HostPortService {
  @override
  Future<bool> isBindable({required String host, required int port}) {
    return _loopbackPortApi.isBindable(host: host, port: port);
  }
}
