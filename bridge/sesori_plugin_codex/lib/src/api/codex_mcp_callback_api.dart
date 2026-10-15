import "dart:async";

import "package:http/http.dart" as http;

final class const CodexMcpCallbackHttpException({required final int statusCode}) implements Exception {
  @override
  String toString() => "Codex MCP callback returned HTTP $statusCode";
}

/// Delivers only repository-validated callbacks to the native loopback listener.
class CodexMcpCallbackApi({required final http.Client _client, required final Duration _budget}) {
  Future<void> submit({required Uri callbackUri}) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest("GET", callbackUri, abortTrigger: abort.future)..followRedirects = false;
    try {
      await _deliver(request: request).timeout(
        _budget,
        onTimeout: () {
          abort.complete();
          throw TimeoutException("Codex MCP callback delivery timed out", _budget);
        },
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<void> _deliver({required http.BaseRequest request}) async {
    final response = await _client.send(request);
    await response.stream.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CodexMcpCallbackHttpException(statusCode: response.statusCode);
    }
  }

  void close() => _client.close();
}
