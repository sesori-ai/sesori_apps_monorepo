import "dart:async";

import "package:acp_plugin/acp_plugin.dart";

/// Cursor's isolated catalog-probe capability over its own ACP transport.
class CursorCatalogApi {
  CursorCatalogApi({
    required AcpStdioClient client,
    required AcpApi api,
  }) : _client = client,
       _api = api;

  static const AcpInitializeRequest _initializeRequest = AcpInitializeRequest(
    clientName: "sesori-bridge",
    clientVersion: "0.0.0",
    clientTitle: null,
    capabilityMeta: {"parameterizedModelPicker": true},
  );
  static const String _authMethodId = "cursor_login";

  final AcpStdioClient _client;
  final AcpApi _api;
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
      result = await _api.initialize(
        request: _initializeRequest,
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
      if (result.protocolVersion != acpProtocolVersion) {
        throw StateError(
          "ACP agent negotiated protocol version ${result.protocolVersion}, "
          "but this client only speaks v$acpProtocolVersion",
        );
      }
      if (result.requiresAuth) {
        await _api.authenticate(
          methodId: _authMethodId,
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
  }) {
    _requireOpen();
    return _api.listSessions(
      directory: directory,
      cursor: cursor,
      timeout: timeout,
    );
  }

  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String directory,
    required Duration timeout,
  }) {
    _requireOpen();
    return _api.loadSession(
      sessionId: sessionId,
      directory: directory,
      timeout: timeout,
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
