import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Desktop ships no speech model, so its dictation stays on the server.
@LazySingleton(as: EmbeddedSpeechSource)
class UnsupportedEmbeddedSpeechSource() implements EmbeddedSpeechSource {
  @override
  Future<bool> prepare() async => false;

  @override
  Future<OnDeviceSpeechSession> open({required VoiceRealtimeSampleRate sampleRate}) =>
      throw UnsupportedError("Desktop has no embedded speech model");
}
