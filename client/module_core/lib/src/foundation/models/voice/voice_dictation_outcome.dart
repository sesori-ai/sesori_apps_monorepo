/// How a dictation ended, as far as what may happen to its words.
enum VoiceDictationOutcome() {
  /// The dictation ran to the end the user asked for.
  finished,

  /// The recording limit stopped it, so its words are not sent unseen.
  limitReached,
}
