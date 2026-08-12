import "dart:async";
import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../omp_binary.dart";

/// Layer-1 ACP operations used by OMP's bounded isolated workflows.
class OmpAcpApi({
    required String binaryPath,
    required AcpProcessFactory processFactory,
    required String logTag,
    required bool isolateSessionHistory,
    required String? scratchParent,
  }) {
  this : _binaryPath = binaryPath,
       _processFactory = processFactory,
       _logTag = logTag,
       _isolateSessionHistory = isolateSessionHistory,
       _scratchParent = scratchParent;

  final String _binaryPath;
  final AcpProcessFactory _processFactory;
  final String _logTag;
  final bool _isolateSessionHistory;
  final String? _scratchParent;
  AcpStdioClient? _client;
  Directory? _sessionDirectory;
  bool _disposed = false;

  Stream<AcpNotification> get notifications {
    final client = _client;
    if (client == null) throw StateError("OMP ACP lease is not open");
    return client.notifications;
  }

  Future<AcpInitializeResult> open({
    required String cwd,
    required Duration timeout,
  }) async {
    if (_disposed) throw StateError("OmpAcpApi is disposed");
    if (_client != null) throw StateError("OMP ACP lease is already open");
    final stopwatch = Stopwatch()..start();
    final sessionDirectory = _isolateSessionHistory ? await _createScratch(prefix: "omp-catalog-") : null;
    if (_disposed) {
      if (sessionDirectory != null) {
        await deleteScratchDirectory(directory: sessionDirectory);
      }
      throw StateError("OmpAcpApi is disposed");
    }
    _sessionDirectory = sessionDirectory;
    final client = AcpStdioClient(
      launchSpec: OmpBinary.launchSpec(
        binary: _binaryPath,
        cwd: cwd,
        sessionDirectory: sessionDirectory?.path,
      ),
      processFactory: _processFactory,
      logTag: _logTag,
    );
    _client = client;
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
        "OMP negotiated ACP v${result.protocolVersion}; expected v$acpProtocolVersion",
      );
    }
    if (result.requiresAuth) {
      await client.request(
        method: AcpMethods.authenticate,
        params: const {"methodId": "agent"},
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
    }
    return result;
  }

  Future<AcpNewSessionResult> newSession({
    required String cwd,
    required Duration timeout,
  }) async => _sessionResult(
    method: AcpMethods.sessionNew,
    params: {"cwd": cwd, "mcpServers": const <Object?>[]},
    timeout: timeout,
  );

  Future<AcpNewSessionResult> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
    required Duration timeout,
  }) async => _sessionResult(
    method: AcpMethods.sessionSetConfigOption,
    params: {"sessionId": sessionId, "configId": configId, "value": value},
    timeout: timeout,
  );

  Future<AcpSessionListResult> listSessionsPage({
    required String? cwd,
    required String? cursor,
    required Duration timeout,
  }) async {
    final raw = await _request(
      method: AcpMethods.sessionList,
      params: {"cwd": ?cwd, "cursor": ?cursor},
      timeout: timeout,
    );
    return AcpSessionListResult.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
    );
  }

  Future<AcpNewSessionResult> resumeSession({
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) async => _sessionResult(
    method: AcpMethods.sessionResume,
    params: {"sessionId": sessionId, "cwd": cwd, "mcpServers": const <Object?>[]},
    timeout: timeout,
  );

  Future<AcpPromptResult> prompt({
    required String sessionId,
    required String text,
    required Duration timeout,
  }) async {
    final raw = await _request(
      method: AcpMethods.sessionPrompt,
      params: {
        "sessionId": sessionId,
        "prompt": [textContentBlock(text)],
      },
      timeout: timeout,
    );
    return AcpPromptResult.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
    );
  }

  Future<void> closeSession({
    required String sessionId,
    required Duration timeout,
  }) => _request(
    method: AcpMethods.sessionClose,
    params: {"sessionId": sessionId},
    timeout: timeout,
  );

  Future<Directory> createScratchDirectory({required String prefix}) => _createScratch(prefix: prefix);

  Future<void> deleteScratchDirectory({required Directory directory}) async {
    if (!directory.existsSync()) return;
    directory.deleteSync(recursive: true);
  }

  Future<void> settle() async {
    final client = _client;
    _client = null;
    if (client != null) await client.dispose();
    final sessionDirectory = _sessionDirectory;
    _sessionDirectory = null;
    if (sessionDirectory != null) {
      try {
        await deleteScratchDirectory(directory: sessionDirectory);
      } on Object catch (error, stack) {
        Log.w("[$_logTag] failed to remove catalog scratch directory", error, stack);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await settle();
  }

  Future<AcpNewSessionResult> _sessionResult({
    required String method,
    required Map<String, dynamic> params,
    required Duration timeout,
  }) async {
    final raw = await _request(method: method, params: params, timeout: timeout);
    return AcpNewSessionResult.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
    );
  }

  Future<dynamic> _request({
    required String method,
    required Object? params,
    required Duration timeout,
  }) {
    final client = _client;
    if (client == null || !client.isConnected) {
      throw StateError("OMP ACP lease is not open");
    }
    return client.request(method: method, params: params, timeout: timeout);
  }

  Future<Directory> _createScratch({required String prefix}) async {
    final parent = _scratchParent == null ? Directory.systemTemp : Directory(_scratchParent);
    await parent.create(recursive: true);
    return parent.createTemp(prefix);
  }

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("OMP ACP lease exceeded its operation deadline");
    }
    return remaining;
  }
}
