import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/control_channel_api.dart";

/// Layer-2 owner of outbound conversational control commands.
///
/// Expected process shutdown remains the bridge-process repository's atomic
/// operation. This repository exposes only commands initiated by the desktop
/// conversation flow.
@lazySingleton
class ControlCommandRepository({required final ControlChannelApi _api}) {
  void answerPrompt({required String id, required bool accepted}) {
    _api.send(
      message: ControlMessage.promptResponse(id: id, accepted: accepted),
    );
  }
}
