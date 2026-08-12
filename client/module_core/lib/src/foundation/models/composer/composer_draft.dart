import "package:collection/collection.dart";
import "package:meta/meta.dart";

enum ComposerInputMode() { typed, voiceAssisted }

@immutable
final class const VoiceOriginSpan._({required this.start, required this.end}) {
  final int start;
  final int end;

  factory VoiceOriginSpan({required int start, required int end}) {
    if (start < 0 || end <= start) {
      throw ArgumentError.value((start: start, end: end), "span", "must be a non-empty half-open range");
    }
    return VoiceOriginSpan._(start: start, end: end);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VoiceOriginSpan && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Immutable composer text plus compact half-open ranges contributed by voice.
@immutable
final class const ComposerDraft._({required this.text, required this.voiceSpans}) {
  final String text;
  final List<VoiceOriginSpan> voiceSpans;

  factory ComposerDraft({
    required String text,
    required List<VoiceOriginSpan> voiceSpans,
  }) {
    var previousEnd = -1;
    for (final span in voiceSpans) {
      if (span.end > text.length) {
        throw ArgumentError.value(voiceSpans, "voiceSpans", "must stay within the draft text");
      }
      if (span.start <= previousEnd) {
        throw ArgumentError.value(
          voiceSpans,
          "voiceSpans",
          "must be sorted, non-overlapping, and merge adjacent ranges",
        );
      }
      previousEnd = span.end;
    }
    return ComposerDraft._(text: text, voiceSpans: List.unmodifiable(voiceSpans));
  }

  factory ComposerDraft.typed({required String text}) => ComposerDraft(text: text, voiceSpans: const []);

  ComposerInputMode get inputMode => voiceSpans.isEmpty ? ComposerInputMode.typed : ComposerInputMode.voiceAssisted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComposerDraft &&
          text == other.text &&
          const ListEquality<VoiceOriginSpan>().equals(voiceSpans, other.voiceSpans);

  @override
  int get hashCode => Object.hash(text, const ListEquality<VoiceOriginSpan>().hash(voiceSpans));
}
