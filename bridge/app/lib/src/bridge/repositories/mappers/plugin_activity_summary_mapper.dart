import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginActiveSession;
import "package:sesori_shared/sesori_shared.dart" show ActiveSession;

extension PluginActiveSessionMapper on PluginActiveSession {
  ActiveSession toSharedActiveSession({
    required String sessionId,
    required List<String> childSessionIds,
    required int? lastUserActivityAt,
    required int updatedAt,
  }) {
    return ActiveSession(
      id: sessionId,
      mainAgentRunning: mainAgentRunning,
      awaitingInput: awaitingInput,
      isRetrying: isRetrying,
      childSessionIds: childSessionIds,
      lastUserActivityAt: lastUserActivityAt,
      updatedAt: updatedAt,
    );
  }
}
