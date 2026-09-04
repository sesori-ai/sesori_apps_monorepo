import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/antigravity_acp_api.dart";
import "../api/models/antigravity_initialize_dto.dart";
import "../builders/antigravity_launch_spec_builder.dart";
import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../storage/antigravity_runtime_storage.dart";

/// Maps runtime filesystem and ACP boundaries into Antigravity domain results.
class AntigravityRuntimeRepository({
  required final AntigravityRuntimeStorage _runtimeStorage,
  required final AntigravityAcpApi _acpApi,
  required final AntigravityLaunchSpecBuilder _launchSpecBuilder,
}) {
  AntigravityRuntimeCandidateResult inspectPair({
    required AntigravityRuntimeSource source,
    required String serverPath,
    required PlatformTarget target,
  }) {
    final result = _runtimeStorage.inspectPair(serverPath: serverPath, target: target);
    return _mapPairReadResult(source: source, result: result);
  }

  AntigravityRuntimeCandidateResult inspectPath({
    required Map<String, String> environment,
    required PlatformTarget target,
  }) {
    final result = _runtimeStorage.findOnPath(environment: environment, target: target);
    return _mapPairReadResult(source: AntigravityRuntimeSource.path, result: result);
  }

  Future<AntigravityRuntimeProbeResult> probe({
    required AntigravityRuntimeSource source,
    required AntigravityRuntimePair pair,
    required Map<String, String> environment,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) async {
    try {
      final dto = await _acpApi.initializeOnly(
        launchSpec: _launchSpecBuilder.build(pair: pair, cwd: null, environment: environment),
        timeout: timeout,
        abortSignal: abortSignal,
      );
      final capabilities = dto.agentCapabilities;
      return AntigravityRuntimeProbeCompleted(
        source: source,
        pair: pair,
        snapshot: AntigravityRuntimeProbeSnapshot(
          protocolVersion: dto.protocolVersion,
          agentName: dto.agentInfo?.name,
          agentVersion: dto.agentInfo?.version,
          loadsSessions: capabilities?.loadSession ?? false,
          listsSessions: capabilities?.sessionCapabilities?.list ?? false,
          resumesSessions: capabilities?.sessionCapabilities?.resume ?? false,
          closesSessions: capabilities?.sessionCapabilities?.close ?? false,
          logsOutAuthentication: capabilities?.auth?.logout ?? false,
          authenticationMethodIds: {
            for (final method in dto.authMethods ?? const <AntigravityAuthMethodDto>[])
              if (method.id case final String id) id,
          },
        ),
      );
    } on PluginStartAbortedException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on Object catch (error, stackTrace) {
      return AntigravityRuntimeProbeBoundaryFailed(
        source: source,
        pair: pair,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  AntigravityRuntimeCandidateResult _mapPairReadResult({
    required AntigravityRuntimeSource source,
    required AntigravityRuntimePairReadResult result,
  }) => switch (result) {
    AntigravityRuntimePairFound(:final pair) => AntigravityRuntimeCandidateFound(source: source, pair: pair),
    AntigravityRuntimePairMissing(:final component) => AntigravityRuntimeCandidateMissing(
      source: source,
      component: component,
    ),
    AntigravityRuntimePairInvalid(:final component, :final reason) => AntigravityRuntimeCandidateRejected(
      source: source,
      component: component,
      issue: switch (reason) {
        AntigravityRuntimePairInvalidReason.wrongName => AntigravityRuntimePairIssue.wrongName,
        AntigravityRuntimePairInvalidReason.notAFile => AntigravityRuntimePairIssue.notAFile,
        AntigravityRuntimePairInvalidReason.notSiblings => AntigravityRuntimePairIssue.notSiblings,
        AntigravityRuntimePairInvalidReason.notDistinct => AntigravityRuntimePairIssue.notDistinct,
      },
    ),
    AntigravityRuntimeTargetUnsupported(:final target) => AntigravityRuntimeCandidateUnsupported(target: target),
    AntigravityRuntimeStorageFailure(:final cause, :final stackTrace) => AntigravityRuntimeCandidateStorageFailed(
      source: source,
      cause: cause,
      stackTrace: stackTrace,
    ),
  };
}
