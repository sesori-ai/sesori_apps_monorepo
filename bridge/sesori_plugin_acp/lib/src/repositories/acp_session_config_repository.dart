import "../acp_protocol.dart";
import "../api/acp_agent_api.dart";

/// Connection-scoped access to standard ACP session configuration writes — the
/// repository harness option services consume for `session/set_config_option`
/// (the wire shape itself lives in [AcpAgentApi]).
class AcpSessionConfigRepository({required final AcpAgentApi _api}) {
  /// Returns the agent's updated config state, or null when it answered
  /// without one.
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) => _api.setConfigOption(
    sessionId: sessionId,
    configId: configId,
    value: value,
    timeout: AcpAgentApi.defaultRequestTimeout,
  );
}
