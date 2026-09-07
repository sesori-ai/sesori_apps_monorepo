import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_authentication_budget.dart";
import "../foundation/antigravity_release.dart";
import "models/antigravity_initialize_dto.dart";

/// Layer-1 ACP process boundary used by unauthenticated runtime probes.
class AntigravityAcpApi({
  required final AcpProcessFactory _processFactory,
  required final AcpOutputInterceptor _stderrInterceptor,
}) {
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
      stderrInterceptor: _stderrInterceptor,
    );
    final connecting = client.connect();
    final connected = connecting.then<AsyncError?>((_) => null, onError: AsyncError.new);
    try {
      await _awaitPhase(
        operation: connecting,
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
      // A cancelled runtime probe must also reap an already-started late spawn.
      await connected;
    }
  }

  /// Owns one interactive scratch process until authenticate settles or aborts.
  Future<void> authenticate({
    required AcpLaunchSpec launchSpec,
    required AcpOutputInterceptor stdoutInterceptor,
    required AntigravityAuthenticationBudget budget,
  }) async {
    budget.remaining;
    final client = AcpStdioClient(
      launchSpec: launchSpec,
      processFactory: _processFactory,
      stdoutInterceptor: stdoutInterceptor,
      stderrInterceptor: _stderrInterceptor,
      logTag: "antigravity-auth",
    );
    Future<void> run() async {
      await client.connect();
      final agent = AcpAgentApi(client: client);
      final initialized = await agent.initializeOnly(
        formElicitation: false,
        capabilityMeta: null,
        timeout: budget.remaining,
      );
      await agent.authenticate(
        initializeResult: initialized,
        authMethodId: AntigravityRelease.personalOauthMethodId,
        authMethodAllowlist: const {AntigravityRelease.personalOauthMethodId},
        timeout: budget.remaining,
      );
    }

    // Retain settlement even when abort wins during process spawn. Disposal
    // makes a late connect reap its child, and completion must wait for that.
    final settled = run().then<AsyncError?>(
      (_) => null,
      onError: AsyncError.new,
    );
    try {
      final failure = await Future.any<AsyncError?>([
        settled,
        budget.abortSignal.whenAborted.then<AsyncError?>((_) => throw const PluginStartAbortedException()),
      ]).timeout(budget.remaining);
      if (failure != null) Error.throwWithStackTrace(failure.error, failure.stackTrace);
    } finally {
      await client.dispose();
      // A closure-induced failure is secondary to the controlling abort/timeout.
      await settled;
    }
    budget.remaining;
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
