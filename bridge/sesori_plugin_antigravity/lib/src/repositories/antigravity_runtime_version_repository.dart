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
      return AntigravityRuntimeVersionProbeCompleted(
        source: source,
        command: dto.command,
        version: dto.buildLabel,
      );
    } on Object catch (error, stackTrace) {
      return AntigravityRuntimeVersionProbeFailed(source: source, cause: error, stackTrace: stackTrace);
    }
  }
}
