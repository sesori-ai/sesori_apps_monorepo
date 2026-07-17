import "dart:async";

import "package:acp_plugin/acp_plugin.dart";

/// Cursor's isolated catalog-probe capability over its own ACP transport.
class CursorCatalogApi {
  CursorCatalogApi({required AcpStdioClient client}) : _client = client;

  final AcpStdioClient _client;
  AcpInitializeResult? _initializeResult;
  bool _disposed = false;

  Future<AcpInitializeResult> open({required Duration timeout}) async {
    if (_disposed) throw StateError("CursorCatalogApi is disposed");
    final stopwatch = Stopwatch()..start();
    if (!_client.isConnected) {
      await _client.reset(gracefulTimeout: Duration.zero);
      _initializeResult = null;
      await _client.connect().timeout(
        _remaining(timeout: timeout, stopwatch: stopwatch),
      );
    }

    var result = _initializeResult;
    if (result == null) {
      final response = await _client.request(
        method: AcpMethods.initialize,
        params: const {
          "protocolVersion": acpProtocolVersion,
          "clientCapabilities": {
            "fs": {"readTextFile": false, "writeTextFile": false},
            "terminal": false,
            "_meta": {"parameterizedModelPicker": true},
          },
          "clientInfo": {
            "name": "sesori-bridge",
            "version": "0.0.0",
          },
        },
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
      result = AcpInitializeResult.fromJson(
        _responseMap(method: AcpMethods.initialize, response: response),
      );
      if (result.protocolVersion != acpProtocolVersion) {
        throw StateError(
          "ACP agent negotiated protocol version ${result.protocolVersion}, "
          "but this client only speaks v$acpProtocolVersion",
        );
      }
      if (result.requiresAuth) {
        await _client.request(
          method: AcpMethods.authenticate,
          params: const {"methodId": "cursor_login"},
          timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
        );
      }
      _initializeResult = result;
    }
    return result;
  }

  Future<AcpSessionListResult> listSessions({
    required String? directory,
    required String? cursor,
    required Duration timeout,
  }) async {
    _requireOpen();
    final response = await _client.request(
      method: AcpMethods.sessionList,
      params: {
        "cwd": ?directory,
        "cursor": ?cursor,
      },
      timeout: timeout,
    );
    return AcpSessionListResult.fromJson(
      _responseMap(method: AcpMethods.sessionList, response: response),
    );
  }

  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String directory,
    required Duration timeout,
  }) async {
    _requireOpen();
    final response = await _client.request(
      method: AcpMethods.sessionLoad,
      params: {
        "sessionId": sessionId,
        "cwd": directory,
        "mcpServers": const <Object?>[],
      },
      timeout: timeout,
    );
    return AcpNewSessionResult.fromJson(
      _responseMap(method: AcpMethods.sessionLoad, response: response),
    );
  }

  Future<void> reset() async {
    if (_disposed) return;
    _initializeResult = null;
    await _client.reset(gracefulTimeout: Duration.zero);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initializeResult = null;
    await _client.dispose();
  }

  void _requireOpen() {
    if (_initializeResult == null || !_client.isConnected) {
      throw StateError("Cursor catalog probe is not initialized");
    }
  }

  Map<String, dynamic> _responseMap({
    required String method,
    required Object? response,
  }) {
    if (response is Map) return response.cast<String, dynamic>();
    throw FormatException("$method returned a non-object result");
  }

  Duration _remaining({
    required Duration timeout,
    required Stopwatch stopwatch,
  }) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Cursor catalog probe exceeded its operation deadline");
    }
    return remaining;
  }
}
