import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_identity.dart";
import "../foundation/antigravity_release.dart";
import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../repositories/antigravity_runtime_repository.dart";

/// Owns Antigravity runtime precedence, exact contract policy, and sequencing.
class AntigravityRuntimeService({required final AntigravityRuntimeRepository _runtimeRepository}) {
  Future<AntigravityRuntimeResolution> resolve({
    required String? explicitServerPath,
    required String? managedServerPath,
    required Map<String, String> pathEnvironment,
    required Map<String, String> probeEnvironment,
    required PlatformTarget target,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) async {
    final deadline = Stopwatch()..start();
    _throwIfAborted(abortSignal: abortSignal);

    if (explicitServerPath != null) {
      final candidate = _runtimeRepository.inspectPair(
        source: AntigravityRuntimeSource.explicit,
        serverPath: explicitServerPath,
        target: target,
      );
      return await _resolveCandidate(
        candidate: candidate,
        probeEnvironment: probeEnvironment,
        timeout: _remaining(timeout: timeout, deadline: deadline),
        abortSignal: abortSignal,
      );
    }

    final pathCandidate = _runtimeRepository.inspectPath(environment: pathEnvironment, target: target);
    final pathResolution = await _resolveCandidate(
      candidate: pathCandidate,
      probeEnvironment: probeEnvironment,
      timeout: _remaining(timeout: timeout, deadline: deadline),
      abortSignal: abortSignal,
    );
    if (pathResolution is AntigravityRuntimeSelected || pathResolution is AntigravityRuntimeUnsupported) {
      return pathResolution;
    }

    _throwIfAborted(abortSignal: abortSignal);
    if (managedServerPath == null) return pathResolution;
    _remaining(timeout: timeout, deadline: deadline);
    final managedCandidate = _runtimeRepository.inspectPair(
      source: AntigravityRuntimeSource.managed,
      serverPath: managedServerPath,
      target: target,
    );
    return await _resolveCandidate(
      candidate: managedCandidate,
      probeEnvironment: probeEnvironment,
      timeout: _remaining(timeout: timeout, deadline: deadline),
      abortSignal: abortSignal,
    );
  }

  Future<AntigravityRuntimeResolution> validatePair({
    required AntigravityRuntimeSource source,
    required AntigravityRuntimePair pair,
    required Map<String, String> probeEnvironment,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) async {
    _throwIfAborted(abortSignal: abortSignal);
    final result = await _runtimeRepository.probe(
      source: source,
      pair: pair,
      environment: probeEnvironment,
      timeout: timeout,
      abortSignal: abortSignal,
    );
    _throwIfAborted(abortSignal: abortSignal);
    return switch (result) {
      AntigravityRuntimeProbeCompleted(:final source, :final pair, :final snapshot) => _validateSnapshot(
        source: source,
        pair: pair,
        snapshot: snapshot,
      ),
      AntigravityRuntimeProbeBoundaryFailed(
        :final source,
        :final pair,
        :final cause,
        :final stackTrace,
      ) =>
        AntigravityRuntimeProbeFailed(
          source: source,
          pair: pair,
          cause: cause,
          stackTrace: stackTrace,
        ),
    };
  }

  Future<AntigravityRuntimeResolution> _resolveCandidate({
    required AntigravityRuntimeCandidateResult candidate,
    required Map<String, String> probeEnvironment,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) async {
    _throwIfAborted(abortSignal: abortSignal);
    switch (candidate) {
      case AntigravityRuntimeCandidateFound(:final source, :final pair):
        return await validatePair(
          source: source,
          pair: pair,
          probeEnvironment: probeEnvironment,
          timeout: timeout,
          abortSignal: abortSignal,
        );
      case AntigravityRuntimeCandidateMissing(:final source, :final component):
        return AntigravityRuntimeMissing(source: source, component: component);
      case AntigravityRuntimeCandidateRejected(:final source, :final component, :final issue):
        return AntigravityRuntimePairRejected(source: source, component: component, issue: issue);
      case AntigravityRuntimeCandidateStorageFailed(:final source, :final cause, :final stackTrace):
        return AntigravityRuntimeStorageFailed(source: source, cause: cause, stackTrace: stackTrace);
      case AntigravityRuntimeCandidateUnsupported(:final target):
        return AntigravityRuntimeUnsupported(target: target);
    }
  }

  AntigravityRuntimeResolution _validateSnapshot({
    required AntigravityRuntimeSource source,
    required AntigravityRuntimePair pair,
    required AntigravityRuntimeProbeSnapshot snapshot,
  }) {
    final violations = <AntigravityRuntimeContractViolation>[
      if (snapshot.protocolVersion != AntigravityRelease.protocolVersion)
        AntigravityRuntimeContractViolation.protocolVersion,
      if (snapshot.agentName != AntigravityIdentity.upstreamAgentName) AntigravityRuntimeContractViolation.agentName,
      if (snapshot.agentVersion != AntigravityRelease.agentVersion) AntigravityRuntimeContractViolation.agentVersion,
      if (!snapshot.loadsSessions) AntigravityRuntimeContractViolation.loadSession,
      if (!snapshot.listsSessions) AntigravityRuntimeContractViolation.listSessions,
      if (!snapshot.resumesSessions) AntigravityRuntimeContractViolation.resumeSession,
      if (snapshot.closesSessions) AntigravityRuntimeContractViolation.closeSession,
      if (!snapshot.logsOutAuthentication) AntigravityRuntimeContractViolation.authLogout,
      if (!snapshot.authenticationMethodIds.contains(AntigravityRelease.personalOauthMethodId))
        AntigravityRuntimeContractViolation.personalOauth,
    ];
    if (violations.isNotEmpty) {
      return AntigravityRuntimeContractRejected(source: source, pair: pair, violations: violations);
    }
    return AntigravityRuntimeSelected(
      source: source,
      pair: pair,
      contract: AntigravityRuntimeContract(
        version: AntigravityRelease.agentVersion,
        listsSessions: snapshot.listsSessions,
        closesSessions: snapshot.closesSessions,
      ),
    );
  }

  Duration _remaining({required Duration timeout, required Stopwatch deadline}) {
    final remaining = timeout - deadline.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Antigravity runtime resolution exceeded its deadline");
    }
    return remaining;
  }

  void _throwIfAborted({required StartAbortSignal abortSignal}) {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
