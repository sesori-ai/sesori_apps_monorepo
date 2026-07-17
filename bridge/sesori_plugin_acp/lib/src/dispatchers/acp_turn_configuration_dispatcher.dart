import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_protocol.dart";
import "../repositories/acp_session_repository.dart";

/// Applies backend-specific turn configuration without coupling it to
/// [AcpPlugin]'s queue or transport lifecycle.
///
/// Generic ACP has no standard model/mode selection, so this implementation is
/// intentionally a no-op. Harnesses such as Cursor compose a specialized peer.
class AcpTurnConfigurationDispatcher {
  const AcpTurnConfigurationDispatcher();

  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) {}

  Future<void> apply({
    required AcpSessionRepository repository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
    required bool failOnError,
  }) async {}

  void reset() {}
}
