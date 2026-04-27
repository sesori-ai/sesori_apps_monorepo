import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /session/status` — returns statuses for sessions.
///
/// Returns statuses for ALL sessions globally — not filtered by session or project.
class GetSessionStatusesHandler extends GetRequestHandler<SessionStatusResponse> {
  final BridgePluginApi _plugin;

  GetSessionStatusesHandler(this._plugin) : super("/session/status");

  @override
  Future<SessionStatusResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final pluginStatuses = await _plugin.getSessionStatuses();

    final mapped = pluginStatuses.map(
      (k, v) => MapEntry(
        k,
        switch (v) {
          PluginSessionStatusIdle() => const SessionStatus.idle(),
          PluginSessionStatusBusy() => const SessionStatus.busy(),
          PluginSessionStatusRetry(:final attempt, :final message, :final next) => SessionStatus.retry(
            attempt: attempt,
            message: message,
            next: next,
          ),
        },
      ),
    );

    return SessionStatusResponse(statuses: mapped);
  }
}
