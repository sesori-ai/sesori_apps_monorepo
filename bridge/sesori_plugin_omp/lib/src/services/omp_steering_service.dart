import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../omp_identity.dart";
import "../repositories/omp_steering_repository.dart";

/// Steers busy follow-ups into a running OMP turn when the process advertises it.
class const OmpSteeringService({required final OmpSteeringRepository repository}) {
  static const Duration _steeringTimeout = Duration(seconds: 30);

  /// An unreadable capability is treated as unsupported, so follow-ups keep
  /// the shared stop-and-send.
  bool supportsSteering({required AcpInitializeResult result}) {
    try {
      return repository.parseSteeringSupported(initializeResult: result);
    } on Object catch (error, stack) {
      Log.w("[${OmpPluginIdentity.id}] unreadable steering capability; using stop-and-send", error, stack);
      return false;
    }
  }

  Future<AcpSteeringOutcome> steer({
    required AcpStdioClient client,
    required String sessionId,
    required List<Map<String, dynamic>> prompt,
  }) => repository.steer(client: client, sessionId: sessionId, prompt: prompt, timeout: _steeringTimeout);
}
