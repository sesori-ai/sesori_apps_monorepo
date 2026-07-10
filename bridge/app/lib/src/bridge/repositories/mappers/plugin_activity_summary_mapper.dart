import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginActiveSession;
import "package:sesori_shared/sesori_shared.dart" show ActiveSession;

extension PluginActiveSessionMapper on PluginActiveSession {
  ActiveSession toSharedActiveSession() {
    return ActiveSession(
      id: id,
      mainAgentRunning: mainAgentRunning,
      awaitingInput: awaitingInput,
      isRetrying: isRetrying,
      childSessionIds: childSessionIds,
    );
  }
}
