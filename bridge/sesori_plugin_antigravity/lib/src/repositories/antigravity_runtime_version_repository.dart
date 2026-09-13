import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/antigravity_acp_api.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../models/antigravity_runtime_version.dart";

/// Maps inert Antigravity CLI inspection into runtime-domain results.
class AntigravityRuntimeVersionRepository({required final AntigravityAcpApi _api}) {
  Future<AntigravityRuntimeVersionProbeResult> probe({
    required AntigravityRuntimeSource source,
    required String serverPath,
    required Map<String, String> environment,
    required Duration timeout,
  }) async {
    try {
      final dto = await _api.version(serverPath: serverPath, environment: environment, timeout: timeout);
      final buildLabel = dto.buildLabel;
      final version = buildLabel == null ? null : AntigravityRuntimeVersion.tryParse(buildLabel: buildLabel);
      if (dto.exitCode == 0 && version != null) {
        return AntigravityRuntimeVersionProbeSucceeded(source: source, version: version);
      }
      Log.w("[antigravity] runtime version probe returned no usable build label (exit ${dto.exitCode})");
      return AntigravityRuntimeVersionProbeRejected(source: source, exitCode: dto.exitCode);
    } on Object catch (error, stackTrace) {
      Log.w('[antigravity] runtime version probe failed for "$serverPath"', error, stackTrace);
      return AntigravityRuntimeVersionProbeFailed(source: source, cause: error, stackTrace: stackTrace);
    }
  }
}
