import "dart:async";

import "package:acp_plugin/acp_plugin.dart";

import "../copilot_binary.dart";

/// Layer-1 ACP operations used by Copilot's isolated catalog-probe process.
class CopilotCatalogProbeApi({required final AcpStdioClient _client}) {
  AcpInitializeResult? _initializeResult;
  bool _disposed = false;

  Stream<AcpNotification> get notifications => _client.notifications;

  Future<AcpInitializeResult> open({required Duration timeout}) async {
    if (_disposed) throw StateError("CopilotCatalogProbeApi is disposed");
    final stopwatch = Stopwatch()..start();
    if (!_client.isConnected) {
      await _client.reset(gracefulTimeout: Duration.zero);
      _initializeResult = null;
      await _client.connect().timeout(_remaining(timeout: timeout, stopwatch: stopwatch));
    }
    return _initializeResult ??= await AcpAgentApi(client: _client).initialize(
      formElicitation: false,
      capabilityMeta: null,
      authMethodId: CopilotBinary.acpAuthMethodId,
      timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
    );
  }

  Future<AcpNewSessionResult> newSession({required String cwd, required Duration timeout}) =>
      _api().newSession(cwd: cwd, timeout: timeout);

  Future<void> closeSession({required String sessionId, required Duration timeout}) =>
      _api().closeSession(sessionId: sessionId, timeout: timeout);

  Future<void> settle() async {
    _initializeResult = null;
    await _client.reset(gracefulTimeout: Duration.zero);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initializeResult = null;
    await _client.dispose();
  }

  AcpAgentApi _api() {
    if (_initializeResult == null || !_client.isConnected) {
      throw StateError("GitHub Copilot catalog probe is not initialized");
    }
    return AcpAgentApi(client: _client);
  }

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException("GitHub Copilot catalog probe exceeded its deadline");
    return remaining;
  }
}
