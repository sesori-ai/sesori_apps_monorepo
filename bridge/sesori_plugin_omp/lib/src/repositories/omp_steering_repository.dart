import "package:acp_plugin/acp_plugin.dart";

import "../api/omp_steering_api.dart";
import "../models/omp_steering_models.dart";

class const OmpSteeringRepository({required final OmpSteeringApi api}) {
  /// Whether an OMP `initialize` result advertises `_session/steering`.
  bool parseSteeringSupported({required AcpInitializeResult initializeResult}) =>
      OmpInitializeMetaDto.fromJson(initializeResult.raw).meta?.steering?.supported ?? false;

  Future<AcpSteeringOutcome> steer({
    required AcpStdioClient client,
    required String sessionId,
    required List<Map<String, dynamic>> prompt,
    required Duration timeout,
  }) async {
    final result = await api.steerSession(liveClient: client, sessionId: sessionId, prompt: prompt, timeout: timeout);
    return switch (result.outcome) {
      OmpSteeringOutcome.injected => AcpSteeringOutcome.injected,
      OmpSteeringOutcome.promptRequired => AcpSteeringOutcome.notAdmitted,
      OmpSteeringOutcome.failed || OmpSteeringOutcome.unknown => throw OmpSteeringFailedException(
        outcome: result.outcome,
        reason: result.reason,
      ),
    };
  }
}
