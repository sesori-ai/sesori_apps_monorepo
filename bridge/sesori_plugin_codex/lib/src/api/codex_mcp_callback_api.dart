import "package:http/http.dart" as http;

final class const CodexMcpCallbackHttpException({required final int statusCode}) implements Exception {
  @override
  String toString() => "Codex MCP callback returned HTTP $statusCode";
}

/// Delivers only repository-validated callbacks to the native loopback listener.
class CodexMcpCallbackApi({required final http.Client _client, required final Duration _budget}) {
  Future<void> submit({required Uri callbackUri}) async {
    final request = http.Request("GET", callbackUri)..followRedirects = false;
    final response = await _client.send(request).timeout(_budget);
    await response.stream.drain<void>().timeout(_budget);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CodexMcpCallbackHttpException(statusCode: response.statusCode);
    }
  }

  void close() => _client.close();
}
