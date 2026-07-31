import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:test/test.dart";

void main() {
  test("derives input mode from surviving voice spans", () {
    expect(ComposerDraft.typed(text: "typed").inputMode, ComposerInputMode.typed);
    expect(
      ComposerDraft(
        text: "voice",
        voiceSpans: [VoiceOriginSpan(start: 0, end: 5)],
      ).inputMode,
      ComposerInputMode.voiceAssisted,
    );
  });

  test("rejects spans outside the draft", () {
    expect(
      () => ComposerDraft(
        text: "short",
        voiceSpans: [VoiceOriginSpan(start: 0, end: 6)],
      ),
      throwsArgumentError,
    );
  });

  test("rejects overlapping or adjacent unmerged spans", () {
    expect(
      () => ComposerDraft(
        text: "abcdef",
        voiceSpans: [
          VoiceOriginSpan(start: 0, end: 2),
          VoiceOriginSpan(start: 2, end: 4),
        ],
      ),
      throwsArgumentError,
    );
  });
}
