import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/voice/voice_engine.dart";
import "../../repositories/voice_mode_repository.dart";

/// The dictation engine picker. The state is null until the stored pick has been
/// read, so the page never shows a wrong engine as selected.
class VoiceEngineCubit({required final VoiceModeRepository _voiceModeRepository}) extends Cubit<VoiceEngine?> {
  this : super(null) {
    unawaited(_load());
  }

  Future<void> _load() async {
    await _voiceModeRepository.loadEngine();
    if (!isClosed && state == null) emit(_voiceModeRepository.engine);
  }

  Future<void> select({required VoiceEngine engine}) async {
    emit(engine);
    await _voiceModeRepository.setEngine(engine: engine);
  }
}
