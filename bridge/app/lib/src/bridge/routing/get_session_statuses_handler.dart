import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /session/status` — returns statuses for sessions.
///
/// Returns statuses for ALL sessions globally — not filtered by session or project.
class GetSessionStatusesHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetSessionStatusesHandler(this._plugin) : super(HttpMethod.get, "/session/status");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
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

    final body = jsonEncode(mapped.map((k, v) => MapEntry(k, v.toJson())));
    return buildOkJsonResponse(request, body);
  }
}
