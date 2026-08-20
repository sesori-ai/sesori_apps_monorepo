import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show CommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;

import "../hermes_binary.dart";

/// Hermes CLI and ACP operations used by model discovery and selection.
class HermesAcpApi({
  required final String _binaryPath,
  required final AcpProcessFactory _processFactory,
  required final CommandExecutor _commandExecutor,
  required final Map<String, String> _environment,
}) {
  static const String _sessionSetModel = "session/set_model";
  AcpStdioClient? _scratchClient;
  bool _disposed = false;

  Future<void> openScratch({
    required String cwd,
    required Duration timeout,
  }) async {
    if (_disposed) throw StateError("HermesAcpApi is disposed");
    if (_scratchClient != null) throw StateError("Hermes scratch ACP lease is already open");
    final stopwatch = Stopwatch()..start();
    final client = AcpStdioClient(
      launchSpec: HermesBinary.launchSpec(
        binary: _binaryPath,
        cwd: cwd,
        environment: const {},
      ),
      processFactory: _processFactory,
      logTag: "hermes-catalog",
    );
    _scratchClient = client;
    await client.connect().timeout(_remaining(timeout: timeout, stopwatch: stopwatch));
    final raw = await client.request(
      method: AcpMethods.initialize,
      params: buildInitializeParams(
        clientName: "sesori-bridge",
        clientVersion: "0.0.0",
        formElicitation: false,
      ),
      timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
    );
    final result = AcpInitializeResult.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
    );
    if (result.protocolVersion != acpProtocolVersion) {
      throw StateError(
        "Hermes negotiated ACP v${result.protocolVersion}; expected v$acpProtocolVersion",
      );
    }
    if (!result.requiresAuth) return;
    final methodId = _authMethodId(result);
    if (methodId == null) {
      throw StateError("Hermes model discovery requires non-terminal authentication");
    }
    await client.request(
      method: AcpMethods.authenticate,
      params: {"methodId": methodId},
      timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
    );
  }

  Future<AcpNewSessionResult> newScratchSession({
    required String cwd,
    required Duration timeout,
  }) async {
    final raw = await _scratchRequest(
      method: AcpMethods.sessionNew,
      params: {"cwd": cwd, "mcpServers": const <Object?>[]},
      timeout: timeout,
    );
    return AcpNewSessionResult.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
    );
  }

  Future<void> setModel({
    required AcpStdioClient liveClient,
    required String sessionId,
    required String modelId,
    required Duration timeout,
  }) async {
    await liveClient.request(
      method: _sessionSetModel,
      params: {"sessionId": sessionId, "modelId": modelId},
      timeout: timeout,
    );
  }

  Future<void> settleScratch({required Duration timeout}) async {
    final client = _scratchClient;
    _scratchClient = null;
    if (client == null) return;
    final processExit = client.processExit;
    await client.dispose(gracefulTimeout: timeout);
    await processExit.timeout(timeout);
  }

  Future<void> deletePersistedSession({
    required String sessionId,
    required Duration timeout,
  }) async {
    final result = await _commandExecutor.run(
      _binaryPath,
      ["sessions", "delete", sessionId, "--yes"],
      environment: _environment,
      timeout: timeout,
    );
    if (result.exitCode == 0) return;
    throw PluginOperationException(
      "hermes sessions delete",
      message: "Hermes exited with code ${result.exitCode}: ${result.stderr.trim()}",
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await settleScratch(timeout: const Duration(seconds: 5));
  }

  Future<dynamic> _scratchRequest({
    required String method,
    required Object? params,
    required Duration timeout,
  }) {
    final client = _scratchClient;
    if (client == null || !client.isConnected) {
      throw StateError("Hermes scratch ACP lease is not open");
    }
    return client.request(method: method, params: params, timeout: timeout);
  }

  String? _authMethodId(AcpInitializeResult result) {
    for (final method in result.authMethods) {
      if (method.type != AcpAuthMethodType.terminal) return method.id;
    }
    return null;
  }

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Hermes scratch ACP lease exceeded its operation deadline");
    }
    return remaining;
  }
}
