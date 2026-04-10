import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession;

import "models/session.dart";

class SessionPluginMapper {
  const SessionPluginMapper();

  PluginSession toPluginSession({required Session session}) {
    return session.toPlugin();
  }

  Map<String, dynamic> toBridgeSessionInfo({required Session session}) {
    return session.toJson();
  }
}
