/// How dictation runs, chosen by the voice mode switch.
sealed class const VoiceMode();

/// Records first, then transcribes the recording.
final class const VoiceModeAfterRecording() extends VoiceMode;

/// Shows the words live while the user speaks, in [presentation].
final class const VoiceModeLive({required final VoiceLivePresentation presentation}) extends VoiceMode;

/// Where live words appear.
enum VoiceLivePresentation() {
  /// Over the whole chat.
  focus,

  /// In a floating panel.
  panel,
}
