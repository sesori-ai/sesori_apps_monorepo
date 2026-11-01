import "package:injectable/injectable.dart";

import "../foundation/models/voice/voice_realtime.dart";
import "../foundation/platform/embedded_speech_source.dart";
import "../foundation/platform/on_device_speech_source.dart";

@lazySingleton
class EmbeddedSpeechApi({required final EmbeddedSpeechSource _source}) {
  Future<bool> prepare() => _source.prepare();

  Future<OnDeviceSpeechSession> open({required VoiceRealtimeSampleRate sampleRate}) =>
      _source.open(sampleRate: sampleRate);
}
