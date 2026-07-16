import "dart:async";

import "package:acp_plugin/acp_plugin.dart";

/// Layer-1 ACP operations used by Cursor's isolated catalog-probe process.
class CursorCatalogProbeApi {
  CursorCatalogProbeApi({required AcpStdioClient client}) : _client = client;

  static const int _maxPages = 50;

  final AcpStdioClient _client;
  AcpInitializeResult? _initializeResult;
  bool _disposed = false;

  /// Connects and performs Cursor's ACP v1 initialize/authenticate handshake.
  Future<AcpInitializeResult> open({required Duration timeout}) async {
    if (_disposed) throw StateError("CursorCatalogProbeApi is disposed");
    final stopwatch = Stopwatch()..start();
    if (!_client.isConnected) {
      await _client.reset(gracefulTimeout: Duration.zero);
      _initializeResult = null;
      await _client.connect().timeout(_remaining(timeout: timeout, stopwatch: stopwatch));
    }

    var initializeResult = _initializeResult;
    if (initializeResult == null) {
      final raw = await _client.request(
        method: AcpMethods.initialize,
        params: buildInitializeParams(
          clientName: "sesori-bridge",
          clientVersion: "0.0.0",
          capabilityMeta: const {"parameterizedModelPicker": true},
        ),
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
      initializeResult = AcpInitializeResult.fromJson(
        raw is Map ? raw.cast<String, dynamic>() : const {},
      );
      if (initializeResult.protocolVersion != acpProtocolVersion) {
        throw StateError(
          "ACP agent negotiated protocol version ${initializeResult.protocolVersion}, "
          "but this client only speaks v$acpProtocolVersion",
        );
      }
      if (initializeResult.requiresAuth) {
        await _client.request(
          method: AcpMethods.authenticate,
          params: const {"methodId": "cursor_login"},
          timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
        );
      }
      _initializeResult = initializeResult;
    }

    return initializeResult;
  }

  /// Lists every page for the required nullable Cursor cwd filter.
  Future<List<AcpSessionInfo>> listSessions({
    required String? cwd,
    required Duration timeout,
  }) async {
    if (_initializeResult == null || !_client.isConnected) {
      throw StateError("Cursor catalog probe is not initialized");
    }
    final stopwatch = Stopwatch()..start();
    final sessions = <AcpSessionInfo>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final raw = await _client.request(
        method: AcpMethods.sessionList,
        params: {
          "cwd": ?cwd,
          "cursor": ?cursor,
        },
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
      final result = AcpSessionListResult.fromJson(
        raw is Map ? raw.cast<String, dynamic>() : const {},
      );
      sessions.addAll(result.sessions);
      final nextCursor = result.nextCursor;
      if (nextCursor == null || nextCursor.isEmpty) return sessions;
      cursor = nextCursor;
    }
    throw StateError("Cursor session/list exceeded $_maxPages pages");
  }

  /// Loads one existing session and parses its typed ACP result.
  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) async {
    if (_initializeResult == null || !_client.isConnected) {
      throw StateError("Cursor catalog probe is not initialized");
    }
    final raw = await _client.request(
      method: AcpMethods.sessionLoad,
      params: {
        "sessionId": sessionId,
        "cwd": cwd,
        "mcpServers": const <Object?>[],
      },
      timeout: timeout,
    );
    return AcpNewSessionResult.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
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

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Cursor catalog probe exceeded its operation deadline");
    }
    return remaining;
  }
}
