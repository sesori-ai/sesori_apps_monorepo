/// How dictation runs, chosen by the voice mode switch.
sealed class const VoiceMode();

/// Records first, then transcribes the recording.
final class const VoiceModeAfterRecording() extends VoiceMode;

/// Shows the words live while the user speaks.
final class const VoiceModeLive() extends VoiceMode;
