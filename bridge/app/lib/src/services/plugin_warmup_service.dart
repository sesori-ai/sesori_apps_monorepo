import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/plugin_lifecycle_repository.dart";
import "../repositories/session_repository.dart";
import "../runtime/plugin_runtime.dart";
import "plugin_warmup_settings_service.dart";

class PluginWarmupService({
  required final SessionRepository _sessionRepository,
  required final PluginLifecycleRepository _pluginLifecycleRepository,
  required final PluginWarmupSettingsService _settingsService,
}) {
  Future<void> warmForSession({required String sessionId}) async {
    if (!_settingsService.isEnabled) return;

    final session = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (session == null || !_settingsService.isEnabled) return;

    final pluginId = session.pluginId;
    final result = await _pluginLifecycleRepository.start(pluginId: pluginId);
    switch (result) {
      case PluginRuntimeCommandApplied() || PluginRuntimeCommandCurrent():
        break;
      case PluginRuntimeCommandConflict(:final reasons):
        Log.d(
          'Session-open warm-up deferred for plugin "$pluginId" '
          '(${reasons.map((reason) => reason.name).join(", ")})',
        );
      case PluginRuntimeCommandFailed(:final message):
        Log.w('Session-open warm-up failed for plugin "$pluginId": $message');
    }
  }
}
