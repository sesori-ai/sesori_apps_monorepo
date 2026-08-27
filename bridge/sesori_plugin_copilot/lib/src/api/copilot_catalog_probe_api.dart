import "dart:async";

import "package:acp_plugin/acp_plugin.dart";

import "../copilot_binary.dart";

/// One isolated Copilot process lease used only for option discovery.
class CopilotCatalogProbeApi({
  required final AcpLaunchSpec _launchSpec,
  required final AcpProcessFactory _processFactory,
}) {
  AcpStdioClient? _client;
  bool _disposed = false;

  Stream<AcpNotification> get notifications => _openClient().notifications;

  Future<AcpInitializeResult> open({required Duration timeout}) async {
    if (_disposed) throw StateError("CopilotCatalogProbeApi is disposed");
    if (_client != null) throw StateError("GitHub Copilot catalog lease is already open");
    final stopwatch = Stopwatch()..start();
    final client = AcpStdioClient(
      launchSpec: _launchSpec,
      processFactory: _processFactory,
      logTag: "copilot-catalog",
    );
    _client = client;
    await client.connect().timeout(_remaining(timeout: timeout, stopwatch: stopwatch));
    return await AcpAgentApi(client: client).initialize(
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
    final client = _client;
    _client = null;
    if (client != null) await client.dispose();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await settle();
  }

  AcpAgentApi _api() => AcpAgentApi(client: _openClient());

  AcpStdioClient _openClient() {
    final client = _client;
    if (client == null || !client.isConnected) throw StateError("GitHub Copilot catalog lease is not open");
    return client;
  }

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException("GitHub Copilot catalog lease exceeded its deadline");
    return remaining;
  }
}
