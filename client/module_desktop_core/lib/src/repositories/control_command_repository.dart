import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/control_channel_api.dart";

/// Layer-2 owner of outbound desktop-to-helper control commands.
///
/// Expected process shutdown remains the bridge-process repository's atomic
/// operation. This repository exposes prompt answers and the logout-specific
/// unregister request.
@lazySingleton
class ControlCommandRepository({required final ControlChannelApi _api}) {
  void answerPrompt({required String id, required bool accepted}) {
    _api.send(
      message: ControlMessage.promptResponse(id: id, accepted: accepted),
    );
  }

  /// Requests the supervised helper to unregister and then exit.
  void unregisterAndExit() {
    _api.send(message: const ControlMessage.unregisterAndExit());
  }
}
