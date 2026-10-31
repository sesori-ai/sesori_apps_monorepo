import "voice_dictation_outcome.dart";
import "voice_transcription_error.dart";

/// The rates the realtime endpoint accepts for PCM16 mono audio.
enum VoiceRealtimeSampleRate({required final int hertz}) {
  hz16000(hertz: 16000),
  hz24000(hertz: 24000),
  hz44100(hertz: 44100),
  hz48000(hertz: 48000),
}

/// The size of one audio frame the realtime endpoint accepts. A frame also has to
/// be even, since it holds whole PCM16 samples.
const int realtimeVoiceMinFrameBytes = 2;
const int realtimeVoiceMaxFrameBytes = 65536;

/// What a live dictation hears from the server. [VoiceRealtimeCompleted] and
/// [VoiceRealtimeFailed] are terminal: nothing follows either one.
sealed class const VoiceRealtimeEvent();

/// The server accepts audio from now on.
final class const VoiceRealtimeReady() extends VoiceRealtimeEvent;

/// New words. Empty strings are real values here: an empty [confirmedDelta] has
/// nothing to append, and an empty [provisional] clears the tentative words.
final class const VoiceRealtimeWords({
  /// Appended to the words confirmed so far.
  required final String confirmedDelta,

  /// Replaces the previous tentative words.
  required final String provisional,
}) extends VoiceRealtimeEvent;

final class const VoiceRealtimeCompleted({required final VoiceDictationOutcome outcome}) extends VoiceRealtimeEvent;

final class const VoiceRealtimeFailed({required final VoiceTranscriptionError error}) extends VoiceRealtimeEvent;
