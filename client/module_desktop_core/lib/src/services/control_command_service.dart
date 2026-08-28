import "package:injectable/injectable.dart";

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
  void answerPrompt({required String id, required bool accepted}) {
    if (!_promptTracker.prompts.any((prompt) => prompt.id == id)) {
      throw ControlPromptNotPendingException(id: id);
    }

    _repository.answerPrompt(id: id, accepted: accepted);
    _promptTracker.removePrompt(id: id);
  }
}
