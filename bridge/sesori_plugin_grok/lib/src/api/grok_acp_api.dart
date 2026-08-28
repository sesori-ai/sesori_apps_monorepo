import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../grok_binary.dart";

/// Grok's initialize-only catalog probe and legacy model-selection RPC.
class GrokAcpApi({
  required final String _binaryPath,
  required final AcpProcessFactory _processFactory,
  required final Map<String, String> _environment,
}) {
  static const String sessionSetModelMethod = "session/set_model";
  static const Set<String> headlessAuthMethodIds = {"xai.api_key", "cached_token"};

  Future<AcpInitializeResult> probeCatalog({
    required String cwd,
    required Duration timeout,
  }) async {
    final client = AcpStdioClient(
      launchSpec: GrokBinary.launchSpec(
        binary: _binaryPath,
        cwd: cwd,
        environment: _environment,
      ),
      processFactory: _processFactory,
      logTag: "grok-catalog",
    );
    final stopwatch = Stopwatch()..start();
    AcpInitializeResult? result;
    Object? operationError;
    StackTrace? operationStack;
    try {
      await client.connect().timeout(_remaining(timeout: timeout, stopwatch: stopwatch));
      result = await _initialize(
        client: client,
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
    } on Object catch (error, stackTrace) {
      operationError = error;
      operationStack = stackTrace;
    }

    try {
      await client.dispose(gracefulTimeout: const Duration(seconds: 5));
    } on Object catch (error, stackTrace) {
      if (operationError == null) Error.throwWithStackTrace(error, stackTrace);
      Log.w("[grok] catalog probe cleanup also failed", error, stackTrace);
    }
    if (operationError != null) {
      final stackTrace = operationStack;
      if (stackTrace == null) throw operationError;
      Error.throwWithStackTrace(operationError, stackTrace);
    }
    final completedResult = result;
    if (completedResult == null) throw StateError("Grok catalog probe produced no result");
    return completedResult;
  }

  Future<void> setModel({
    required AcpStdioClient liveClient,
    required String sessionId,
    required String modelId,
    required String? reasoningEffort,
    required Duration timeout,
  }) => liveClient.request(
    method: sessionSetModelMethod,
    params: {
      "sessionId": sessionId,
      "modelId": modelId,
      if (reasoningEffort != null) "_meta": {"reasoningEffort": reasoningEffort},
    },
    timeout: timeout,
  );

  Future<AcpInitializeResult> _initialize({
    required AcpStdioClient client,
    required Duration timeout,
  }) => AcpAgentApi(client: client).initialize(
    formElicitation: false,
    capabilityMeta: null,
    authMethodId: null,
    authMethodAllowlist: headlessAuthMethodIds,
    timeout: timeout,
  );

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException("Grok catalog probe exceeded its deadline");
    return remaining;
  }
}
