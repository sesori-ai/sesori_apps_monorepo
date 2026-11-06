import "package:acp_plugin/acp_plugin.dart";

import "../models/omp_steering_models.dart";

/// OMP's `_session/steering` extension. It runs on the plugin's live client,
/// not on a scratch lease, because steering only reaches a turn that client runs.
class const OmpSteeringApi() {
  static const String sessionSteeringMethod = "_session/steering";

  Future<OmpSteeringResultDto> steerSession({
    required AcpStdioClient liveClient,
    required String sessionId,
    required List<Map<String, dynamic>> prompt,
    required Duration timeout,
  }) async {
    final raw = await liveClient.request(
      method: sessionSteeringMethod,
      params: OmpSteeringParams(sessionId: sessionId, prompt: prompt).toJson(),
      timeout: timeout,
    );
    return switch (raw) {
      final Map<dynamic, dynamic> map => OmpSteeringResultDto.fromJson(map.cast<String, dynamic>()),
      _ => throw FormatException("$sessionSteeringMethod result is not an object: ${raw.runtimeType}"),
    };
  }
}
