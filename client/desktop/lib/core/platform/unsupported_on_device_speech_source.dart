import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Desktop dictation stays on the server.
@LazySingleton(as: OnDeviceSpeechSource)
class UnsupportedOnDeviceSpeechSource() implements OnDeviceSpeechSource {
  @override
  Future<bool> prepare() async => false;

  @override
  Future<OnDeviceSpeechSession> open({required VoiceRealtimeSampleRate sampleRate}) =>
      throw UnsupportedError("Desktop has no on-device speech engine");
}
