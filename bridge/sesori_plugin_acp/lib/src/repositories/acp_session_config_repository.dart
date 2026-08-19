import "../acp_protocol.dart";
import "../acp_stdio_client.dart";

/// Connection-scoped access to standard ACP session configuration writes.
class AcpSessionConfigRepository({required final AcpStdioClient _client}) {
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    final raw = await _client.request(
      method: AcpMethods.sessionSetConfigOption,
      params: {
        "sessionId": sessionId,
        "configId": configId,
        "value": value,
      },
    );
    return raw is Map ? AcpNewSessionResult.fromJson(raw.cast<String, dynamic>()) : null;
  }

  /// Issues a standard ACP `session/set_model` to switch [sessionId] to the
  /// agent-advertised [modelId]. Returns the (typically empty) result.
  Future<AcpNewSessionResult?> setModel({
    required String sessionId,
    required String modelId,
  }) async {
    final raw = await _client.request(
      method: AcpMethods.sessionSetModel,
      params: {
        "sessionId": sessionId,
        "modelId": modelId,
      },
    );
    return raw is Map ? AcpNewSessionResult.fromJson(raw.cast<String, dynamic>()) : null;
  }
}
