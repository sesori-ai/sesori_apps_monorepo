import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/control_channel_server.dart";
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
  required final ControlChannelServer _server,
  required final BridgePromptTracker _promptTracker,
}) {
  void answerPrompt({required String id, required bool accepted}) {
    if (!_promptTracker.prompts.any((prompt) => prompt.id == id)) {
      throw ControlPromptNotPendingException(id: id);
    }

    final ControlMessage response = ControlMessage.promptResponse(
      id: id,
      accepted: accepted,
    );
    _server.send(jsonEncode(response.toJson()));
    _promptTracker.removePrompt(id: id);
  }
}
