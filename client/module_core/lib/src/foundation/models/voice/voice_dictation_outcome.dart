/// How a dictation ended, as far as what may happen to its words.
enum VoiceDictationOutcome() {
  /// The dictation ran to the end the user asked for.
  finished,

  /// The recording limit stopped it, so its words are not sent unseen.
  limitReached,

  /// Words may be missing, because a live session failed or fell back, so they
  /// are not sent unseen.
  interrupted,
}

/// How a dictation actually ran. A fallback counts as [afterRecording].
enum VoiceDictationMode() {
  live,
  afterRecording,
}

/// A dictation's words and how it ended, whichever way it ran.
final class const VoiceDictationResult({
  required final String transcript,
  required final VoiceDictationOutcome outcome,
  required final VoiceDictationMode mode,
});
