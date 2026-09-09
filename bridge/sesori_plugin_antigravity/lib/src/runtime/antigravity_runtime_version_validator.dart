import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../builders/antigravity_environment_builder.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../services/antigravity_runtime_service.dart";

/// Adapts the official pair's initialize-only probe to managed installation.
///
/// The installer owns and later removes the supplied cwd and state directory.
/// This adapter prevents ambient credentials from reaching the candidate,
/// launches through the runtime service's existing supervised ACP boundary and
/// returns only after initialize and process teardown have settled.
class AntigravityRuntimeVersionValidator({
  required final AntigravityRuntimeService _runtimeService,
  final Duration _probeTimeout = const Duration(seconds: 90),
}) implements RuntimeCandidateValidator {
  @override
  Future<bool> validate({required RuntimeCandidateValidationContext context}) async {
    _throwIfAborted(context: context);
    final environment = const AntigravityEnvironmentBuilder().build(
      hostEnvironment: context.environment,
      geminiHome: context.stateDirectory,
      additions: const {},
    );
    final result = await _runtimeService.validateManagedCandidate(
      serverPath: context.executablePath,
      probeEnvironment: environment,
      workingDirectory: context.workingDirectory,
      target: PlatformTarget.current(),
      timeout: _probeTimeout,
      abortSignal: context.abortSignal,
    );
    _throwIfAborted(context: context);
    switch (result) {
      case AntigravityRuntimeSelected():
        return true;
      case AntigravityRuntimeProbeFailed(:final pair, :final cause, :final stackTrace):
        Log.w('[antigravity] managed candidate initialize failed for "${pair.serverPath}"', cause, stackTrace);
      case AntigravityRuntimeStorageFailed(:final cause, :final stackTrace):
        Log.w("[antigravity] managed candidate pair inspection failed", cause, stackTrace);
      case AntigravityRuntimeContractRejected(:final violations):
        Log.w(
          "[antigravity] managed candidate initialize contract rejected: "
          "${violations.map((violation) => violation.name).join(", ")}",
        );
      case AntigravityRuntimeMissing(:final component):
        Log.w("[antigravity] managed candidate is missing its ${component.name}");
      case AntigravityRuntimePairRejected(:final component, :final issue):
        Log.w("[antigravity] managed candidate ${component.name} was rejected: ${issue.name}");
      case AntigravityRuntimeUnsupported(:final target):
        Log.w("[antigravity] managed candidate validation is unsupported on ${target.key}");
    }
    return false;
  }

  void _throwIfAborted({required RuntimeCandidateValidationContext context}) {
    if (context.abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
