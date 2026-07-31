import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/services/composer_draft_calculator.dart";
import "package:test/test.dart";

void main() {
  const calculator = ComposerDraftCalculator();

  ComposerDraft voiceDraft(String text, int start, int end) => ComposerDraft(
    text: text,
    voiceSpans: [VoiceOriginSpan(start: start, end: end)],
  );

  test("appends a transcript as one compact half-open voice span", () {
    final result = calculator.appendVoiceTranscript(
      draft: ComposerDraft.typed(text: "typed"),
      transcript: "voice words",
    );

    expect(result.text, "typed voice words");
    expect(result.voiceSpans, [VoiceOriginSpan(start: 6, end: 17)]);
  });

  test("typed insertion shifts an untouched voice fragment", () {
    final result = calculator.replaceTyped(
      draft: voiceDraft("voice", 0, 5),
      start: 0,
      end: 0,
      replacement: "typed ",
    );

    expect(result.text, "typed voice");
    expect(result.voiceSpans, [VoiceOriginSpan(start: 6, end: 11)]);
  });

  test("partial replacement preserves only untouched voice fragments", () {
    final result = calculator.replaceTyped(
      draft: voiceDraft("abcdefgh", 0, 8),
      start: 2,
      end: 6,
      replacement: "XY",
    );

    expect(result.text, "abXYgh");
    expect(result.voiceSpans, [
      VoiceOriginSpan(start: 0, end: 2),
      VoiceOriginSpan(start: 4, end: 6),
    ]);
  });

  test("full replacement resets the draft to typed", () {
    final result = calculator.replaceTyped(
      draft: voiceDraft("voice", 0, 5),
      start: 0,
      end: 5,
      replacement: "typed",
    );

    expect(result, ComposerDraft.typed(text: "typed"));
    expect(result.inputMode, ComposerInputMode.typed);
  });

  test("identical selected-text replacement still removes voice attribution", () {
    final result = calculator.replaceTyped(
      draft: voiceDraft("voice", 0, 5),
      start: 0,
      end: 5,
      replacement: "voice",
    );

    expect(result.text, "voice");
    expect(result.inputMode, ComposerInputMode.typed);
  });

  test("deletion compacts voice fragments that become adjacent", () {
    final result = calculator.replaceTyped(
      draft: ComposerDraft(
        text: "vo-ice",
        voiceSpans: [
          VoiceOriginSpan(start: 0, end: 2),
          VoiceOriginSpan(start: 3, end: 6),
        ],
      ),
      start: 2,
      end: 3,
      replacement: "",
    );

    expect(result.text, "voice");
    expect(result.voiceSpans, [VoiceOriginSpan(start: 0, end: 5)]);
  });

  test("selected partial edit uses the selection rather than shared text", () {
    final result = calculator.applyTypedEdit(
      draft: voiceDraft("voice text", 0, 5),
      newText: "voice typed",
      previousSelection: (start: 0, end: 10),
      currentSelection: (start: 11, end: 11),
    );

    expect(result.inputMode, ComposerInputMode.typed);
  });

  test("collapsed backspace uses caret positions to preserve repeated voice text", () {
    final result = calculator.applyTypedEdit(
      draft: voiceDraft("aa", 1, 2),
      newText: "a",
      previousSelection: (start: 1, end: 1),
      currentSelection: (start: 0, end: 0),
    );

    expect(result.text, "a");
    expect(result.voiceSpans, [VoiceOriginSpan(start: 0, end: 1)]);
  });

  test("an edit to whitespace-only text resets voice attribution", () {
    final result = calculator.applyTypedEdit(
      draft: voiceDraft("voice ", 0, 6),
      newText: " ",
      previousSelection: (start: 0, end: 5),
      currentSelection: (start: 0, end: 0),
    );

    expect(result, ComposerDraft.typed(text: " "));
  });

  test("trim removes voice attribution that exists only in omitted whitespace", () {
    final result = calculator.trim(
      draft: voiceDraft(" typed", 0, 1),
    );

    expect(result, ComposerDraft.typed(text: "typed"));
  });

  test("trim shifts retained voice attribution with the submitted text", () {
    final result = calculator.trim(
      draft: voiceDraft(" voice ", 1, 6),
    );

    expect(result.text, "voice");
    expect(result.voiceSpans, [VoiceOriginSpan(start: 0, end: 5)]);
  });
}
