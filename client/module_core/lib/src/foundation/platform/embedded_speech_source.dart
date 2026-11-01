import "on_device_speech_source.dart";

/// The speech model shipped inside the app, which keeps audio on the device. It
/// honours the same contract as the operating system's engine, and a build without
/// the model answers false from `prepare`.
abstract interface class EmbeddedSpeechSource() implements OnDeviceSpeechSource;
