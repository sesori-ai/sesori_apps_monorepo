import "dart:async";

import "package:acp_plugin/acp_plugin.dart";

import "../cursor_binary.dart";
import "models/cursor_available_models_dto.dart";

/// Layer-1 ACP operations used by Cursor's isolated catalog-probe process.
class CursorCatalogProbeApi({required final AcpStdioClient _client}) {
  static const int _maxPages = 50;
  static const String _listAvailableModelsMethod = "cursor/list_available_models";

  AcpInitializeResult? _initializeResult;
  bool _disposed = false;

  Stream<AcpNotification> get notifications => _client.notifications;

  /// Connects and performs Cursor's ACP v1 initialize/authenticate handshake.
  Future<AcpInitializeResult> open({required Duration timeout}) async {
    if (_disposed) throw StateError("CursorCatalogProbeApi is disposed");
    final stopwatch = Stopwatch()..start();
    if (!_client.isConnected) {
      await _client.reset(gracefulTimeout: Duration.zero);
      _initializeResult = null;
      await _client.connect().timeout(_remaining(timeout: timeout, stopwatch: stopwatch));
    }
    return _initializeResult ??= await AcpAgentApi(client: _client).initialize(
      formElicitation: false,
      capabilityMeta: CursorBinary.acpCapabilityMeta,
      authMethodId: CursorBinary.acpAuthMethodId,
      authMethodAllowlist: null,
      timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
    );
  }

  /// Lists every page for the required nullable Cursor cwd filter.
  Future<List<AcpSessionInfo>> listSessions({
    required String? cwd,
    required Duration timeout,
  }) async {
    final api = _initializedApi();
    final stopwatch = Stopwatch()..start();
    final sessions = <AcpSessionInfo>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final result = await api.listSessionsPage(
        cwd: cwd,
        cursor: cursor,
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
      sessions.addAll(result.sessions);
      final nextCursor = result.nextCursor;
      if (nextCursor == null || nextCursor.isEmpty) return sessions;
      cursor = nextCursor;
    }
    throw StateError("Cursor session/list exceeded $_maxPages pages");
  }

  /// Reads Cursor's account model catalog without creating a session.
  Future<CursorAvailableModelsDto> listAvailableModels({required Duration timeout}) async {
    final raw = await _initializedApi().client.request(
      method: _listAvailableModelsMethod,
      timeout: timeout,
    );
    return CursorAvailableModelsDto.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
    );
  }

  /// Loads one existing session and parses its typed ACP result.
  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) => _initializedApi().loadSession(sessionId: sessionId, cwd: cwd, timeout: timeout);

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

  AcpAgentApi _initializedApi() {
    if (_initializeResult == null || !_client.isConnected) {
      throw StateError("Cursor catalog probe is not initialized");
    }
    return AcpAgentApi(client: _client);
  }

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Cursor catalog probe exceeded its operation deadline");
    }
    return remaining;
  }
}
