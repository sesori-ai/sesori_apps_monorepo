import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show BridgePlugin;

class ServerHealthRepository {
  final BridgePlugin _plugin;

  ServerHealthRepository({required BridgePlugin plugin}) : _plugin = plugin;

  Future<bool> healthCheck() => _plugin.healthCheck();
}
