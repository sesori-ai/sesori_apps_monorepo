import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/antigravity_initialize_dto.dart";

/// Layer-1 ACP process boundary used by unauthenticated runtime probes.
class AntigravityAcpApi({required final AcpProcessFactory _processFactory}) {
  Future<AntigravityInitializeDto> initializeOnly({
    required AcpLaunchSpec launchSpec,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) async {
    final deadline = Stopwatch()..start();
    _throwIfAborted(abortSignal: abortSignal);
    final client = AcpStdioClient(
      launchSpec: launchSpec,
      processFactory: _processFactory,
      logTag: "antigravity-probe",
    );
    try {
      await _awaitPhase(
        operation: client.connect(),
        timeout: timeout,
        deadline: deadline,
        abortSignal: abortSignal,
      );
      final initialized = await _awaitPhase(
        operation: AcpAgentApi(client: client).initializeOnly(
          formElicitation: false,
          capabilityMeta: null,
          timeout: _remaining(timeout: timeout, deadline: deadline),
        ),
        timeout: timeout,
        deadline: deadline,
        abortSignal: abortSignal,
      );
      final result = AntigravityInitializeDto.fromJson(initialized.raw);
      _throwIfAborted(abortSignal: abortSignal);
      return result;
    } finally {
      await client.dispose();
    }
  }

  Future<T> _awaitPhase<T>({
    required Future<T> operation,
    required Duration timeout,
    required Stopwatch deadline,
    required StartAbortSignal abortSignal,
  }) {
    _throwIfAborted(abortSignal: abortSignal);
    final remaining = _remaining(timeout: timeout, deadline: deadline);
    return Future.any<T>([
      operation,
      abortSignal.whenAborted.then<T>((_) => throw const PluginStartAbortedException()),
    ]).timeout(
      remaining,
      onTimeout: () => throw TimeoutException("Antigravity ACP initialize probe exceeded its deadline"),
    );
  }

  Duration _remaining({required Duration timeout, required Stopwatch deadline}) {
    final remaining = timeout - deadline.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Antigravity ACP initialize probe exceeded its deadline");
    }
    return remaining;
  }

  void _throwIfAborted({required StartAbortSignal abortSignal}) {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
