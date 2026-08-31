import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/control_command_repository.dart";
import "../trackers/bridge_prompt_tracker.dart";

/// The named prompt no longer belongs to the connected helper.
final class const ControlPromptNotPendingException({required final String id}) implements Exception {
  @override
  String toString() => "ControlPromptNotPendingException: prompt $id is not pending";
}

/// Layer-3 owner of conversational GUI-to-helper control messages.
///
/// Expected process shutdown remains the repository's atomic operation. This
/// service owns user answers such as `prompt_response`, and only removes a
/// pending prompt after the frame was accepted by the live control socket.
@lazySingleton
class ControlCommandService({
  required final ControlCommandRepository _repository,
  required final BridgePromptTracker _promptTracker,
}) {
  /// Answers the exact pending prompt instance read from [BridgePromptTracker].
  ///
  /// Wire ids restart with each helper process. Identity therefore acts as the
  /// local ownership token that prevents an old UI callback from approving a
  /// replacement helper's same-id prompt.
  void answerPrompt({required ControlPromptRequest prompt, required bool accepted}) {
    if (!_promptTracker.prompts.any((pending) => identical(pending, prompt))) {
      throw ControlPromptNotPendingException(id: prompt.id);
    }

    _repository.answerPrompt(id: prompt.id, accepted: accepted);
    _promptTracker.removePrompt(id: prompt.id);
  }

  /// Asks the live helper to unregister its server-side bridge and exit.
  ///
  /// The helper owns its own bounded unregister attempt; callers still stop
  /// the process through the process-service boundary because the control
  /// channel may be unavailable or the helper may disappear before handling
  /// this.
  void unregisterAndExit() {
    _repository.unregisterAndExit();
  }
}
