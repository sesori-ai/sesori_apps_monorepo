import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginAuthenticationRequiredException;

import "../grok_binary.dart";

/// Grok's initialize-only catalog probe and legacy model-selection RPC.
class GrokAcpApi({
  required final String _binaryPath,
  required final AcpProcessFactory _processFactory,
  required final Map<String, String> _environment,
}) {
  static const String sessionSetModelMethod = "session/set_model";
  static const Set<String> _headlessAuthMethodIds = {"xai.api_key", "cached_token"};

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
  }) async {
    final stopwatch = Stopwatch()..start();
    final raw = await client.request(
      method: AcpMethods.initialize,
      params: buildInitializeParams(formElicitation: false, capabilityMeta: null),
      timeout: timeout,
    );
    final result = AcpInitializeResult.fromJson(_json(raw: raw));
    if (result.protocolVersion != acpProtocolVersion) {
      throw StateError("Grok negotiated unsupported ACP version ${result.protocolVersion}");
    }
    if (!result.requiresAuth) return result;

    final methodId = _headlessMethod(result: result);
    if (methodId == null) {
      throw const PluginAuthenticationRequiredException(
        AcpMethods.authenticate,
        actionHint: "Authenticate Grok locally with a headless credential, then retry.",
        message: "Grok did not advertise a headless authentication method",
      );
    }
    try {
      await client.request(
        method: AcpMethods.authenticate,
        params: {"methodId": methodId},
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
    } on AcpRpcException catch (error) {
      if (error.method != "<response>") rethrow;
      throw PluginAuthenticationRequiredException(
        AcpMethods.authenticate,
        actionHint: "Authenticate Grok locally with a headless credential, then retry.",
        message: "Grok rejected the configured authentication method",
        cause: error,
      );
    }
    return result;
  }

  String? _headlessMethod({required AcpInitializeResult result}) {
    for (final method in result.authMethods) {
      if (_headlessAuthMethodIds.contains(method.id)) return method.id;
    }
    return null;
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP response and JSON object values are heterogeneous
  Map<String, dynamic> _json({required Object? raw}) {
    if (raw is! Map) throw const FormatException("Grok initialize returned a non-object result");
    // ignore: no_slop_linter/prefer_specific_type, JSON object values are heterogeneous
    return raw.cast<String, dynamic>();
  }

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException("Grok catalog probe exceeded its deadline");
    return remaining;
  }
}
