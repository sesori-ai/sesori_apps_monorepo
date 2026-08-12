import "../acp_protocol.dart";
import "../acp_stdio_client.dart";

/// Connection-scoped access to standard ACP session configuration writes.
class AcpSessionConfigRepository {
  AcpSessionConfigRepository({required AcpStdioClient client}) : _client = client;

  final AcpStdioClient _client;

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
}
