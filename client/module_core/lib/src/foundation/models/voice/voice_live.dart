import "package:meta/meta.dart";

import "voice_dictation_outcome.dart";
import "voice_transcription_error.dart";

/// The words of a live dictation so far. Either part can be an empty string,
/// which here means nothing was heard yet rather than unknown.
@immutable
final class const LiveWords({
  /// Final words. They only ever grow.
  required final String confirmed,

  /// Tentative words after [confirmed], which the next update replaces.
  required final String provisional,
}) {
  static const LiveWords none = LiveWords(confirmed: "", provisional: "");

  /// Everything heard so far. The server's words carry their own spacing.
  String get text => "$confirmed$provisional";

  @override
  bool operator ==(Object other) =>
      other is LiveWords && other.confirmed == confirmed && other.provisional == provisional;

  @override
  int get hashCode => Object.hash(confirmed, provisional);
}

/// What a live dictation reports while the user may still be holding. Once the
/// user has released, `stopAndTranscribe` reports the ending instead.
sealed class const VoiceLiveEvent();

final class const VoiceLiveWordsChanged({required final LiveWords words}) extends VoiceLiveEvent;

/// Live could not start, so the dictation now records a file instead (D21).
final class const VoiceLiveFellBack() extends VoiceLiveEvent;

/// The session ended by itself, with words to hand over.
final class const VoiceLiveEnded({
  required final String transcript,
  required final VoiceDictationOutcome outcome,
  required final VoiceDictationMode mode,
}) extends VoiceLiveEvent;

/// The session ended by itself and left nothing to hand over. There is no
/// recording to retry.
final class const VoiceLiveFailed({required final VoiceTranscriptionError error}) extends VoiceLiveEvent;
