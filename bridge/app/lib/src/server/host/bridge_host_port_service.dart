import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show HostPortService;

import "../api/loopback_port_api.dart";

class BridgeHostPortService implements HostPortService {
  const BridgeHostPortService({
    required LoopbackPortApi loopbackPortApi,
  }) : _loopbackPortApi = loopbackPortApi;

  final LoopbackPortApi _loopbackPortApi;

  @override
  Future<bool> isBindable({required String host, required int port}) {
    return _loopbackPortApi.isBindable(host: host, port: port);
  }
}
