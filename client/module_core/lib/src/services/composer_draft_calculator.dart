import "../foundation/models/composer/composer_draft.dart";

/// Pure edit transformations for composer text and voice-origin spans.
final class ComposerDraftCalculator {
  const ComposerDraftCalculator();

  ComposerDraft applyTypedEdit({
    required ComposerDraft draft,
    required String newText,
    required ({int start, int end})? previousSelection,
    required ({int start, int end})? currentSelection,
  }) {
    if (draft.text == newText) return draft;

    final selection = previousSelection;
    if (selection != null &&
        selection.start >= 0 &&
        selection.end >= selection.start &&
        selection.end <= draft.text.length) {
      if (selection.start == selection.end) {
        final caretResult = _applyCollapsedCaretEdit(
          draft: draft,
          newText: newText,
          previousCaret: selection.start,
          currentSelection: currentSelection,
        );
        if (caretResult != null) return caretResult;
      }
      final prefix = draft.text.substring(0, selection.start);
      final suffix = draft.text.substring(selection.end);
      final replacementLength = newText.length - prefix.length - suffix.length;
      if (replacementLength >= 0 && newText.startsWith(prefix) && newText.endsWith(suffix)) {
        return replaceTyped(
          draft: draft,
          start: selection.start,
          end: selection.end,
          replacement: newText.substring(selection.start, selection.start + replacementLength),
        );
      }
    }

    var prefixLength = 0;
    while (prefixLength < draft.text.length &&
        prefixLength < newText.length &&
        draft.text.codeUnitAt(prefixLength) == newText.codeUnitAt(prefixLength)) {
      prefixLength++;
    }

    var suffixLength = 0;
    while (suffixLength < draft.text.length - prefixLength &&
        suffixLength < newText.length - prefixLength &&
        draft.text.codeUnitAt(draft.text.length - suffixLength - 1) ==
            newText.codeUnitAt(newText.length - suffixLength - 1)) {
      suffixLength++;
    }

    return replaceTyped(
      draft: draft,
      start: prefixLength,
      end: draft.text.length - suffixLength,
      replacement: newText.substring(prefixLength, newText.length - suffixLength),
    );
  }

  ComposerDraft? _applyCollapsedCaretEdit({
    required ComposerDraft draft,
    required String newText,
    required int previousCaret,
    required ({int start, int end})? currentSelection,
  }) {
    final current = currentSelection;
    if (current == null || current.start != current.end || current.start < 0 || current.start > newText.length) {
      return null;
    }
    final delta = newText.length - draft.text.length;
    if (delta > 0 && current.start == previousCaret + delta) {
      return _validatedTypedReplacement(
        draft: draft,
        newText: newText,
        start: previousCaret,
        end: previousCaret,
      );
    }
    if (delta < 0) {
      final deletedLength = -delta;
      if (current.start == previousCaret - deletedLength) {
        return _validatedTypedReplacement(
          draft: draft,
          newText: newText,
          start: current.start,
          end: previousCaret,
        );
      }
      if (current.start == previousCaret) {
        return _validatedTypedReplacement(
          draft: draft,
          newText: newText,
          start: previousCaret,
          end: previousCaret + deletedLength,
        );
      }
    }
    return null;
  }

  ComposerDraft? _validatedTypedReplacement({
    required ComposerDraft draft,
    required String newText,
    required int start,
    required int end,
  }) {
    if (start < 0 || end < start || end > draft.text.length) return null;
    final replacementLength = newText.length - (draft.text.length - (end - start));
    if (replacementLength < 0 || start + replacementLength > newText.length) return null;
    final prefix = draft.text.substring(0, start);
    final suffix = draft.text.substring(end);
    if (!newText.startsWith(prefix) || !newText.endsWith(suffix)) return null;
    return replaceTyped(
      draft: draft,
      start: start,
      end: end,
      replacement: newText.substring(start, start + replacementLength),
    );
  }

  ComposerDraft trim({required ComposerDraft draft}) {
    var result = draft;
    final trimmedRightLength = result.text.trimRight().length;
    if (trimmedRightLength != result.text.length) {
      result = replaceTyped(
        draft: result,
        start: trimmedRightLength,
        end: result.text.length,
        replacement: "",
      );
    }
    final leadingWhitespaceLength = result.text.length - result.text.trimLeft().length;
    if (leadingWhitespaceLength != 0) {
      result = replaceTyped(
        draft: result,
        start: 0,
        end: leadingWhitespaceLength,
        replacement: "",
      );
    }
    return result;
  }

  ComposerDraft replaceTyped({
    required ComposerDraft draft,
    required int start,
    required int end,
    required String replacement,
  }) => _replace(
    draft: draft,
    start: start,
    end: end,
    replacement: replacement,
    replacementIsVoice: false,
  );

  ComposerDraft appendVoiceTranscript({
    required ComposerDraft draft,
    required String transcript,
  }) {
    if (transcript.isEmpty) return draft;
    final separator = draft.text.isNotEmpty && !draft.text.endsWith(" ") ? " " : "";
    final withSeparator = separator.isEmpty
        ? draft
        : replaceTyped(
            draft: draft,
            start: draft.text.length,
            end: draft.text.length,
            replacement: separator,
          );
    return _replace(
      draft: withSeparator,
      start: withSeparator.text.length,
      end: withSeparator.text.length,
      replacement: transcript,
      replacementIsVoice: true,
    );
  }

  ComposerDraft _replace({
    required ComposerDraft draft,
    required int start,
    required int end,
    required String replacement,
    required bool replacementIsVoice,
  }) {
    if (start < 0 || end < start || end > draft.text.length) {
      throw RangeError.range(end, start, draft.text.length, "end");
    }

    final delta = replacement.length - (end - start);
    final transformed = <VoiceOriginSpan>[];
    for (final span in draft.voiceSpans) {
      if (span.end <= start) {
        transformed.add(span);
        continue;
      }
      if (span.start >= end) {
        transformed.add(VoiceOriginSpan(start: span.start + delta, end: span.end + delta));
        continue;
      }
      if (span.start < start) {
        transformed.add(VoiceOriginSpan(start: span.start, end: start));
      }
      if (span.end > end) {
        transformed.add(
          VoiceOriginSpan(
            start: start + replacement.length,
            end: span.end + delta,
          ),
        );
      }
    }
    if (replacementIsVoice && replacement.isNotEmpty) {
      transformed.add(VoiceOriginSpan(start: start, end: start + replacement.length));
    }
    transformed.sort((a, b) => a.start.compareTo(b.start));

    final compact = <VoiceOriginSpan>[];
    for (final span in transformed) {
      if (compact.isEmpty || span.start > compact.last.end) {
        compact.add(span);
      } else {
        final previous = compact.removeLast();
        compact.add(
          VoiceOriginSpan(
            start: previous.start,
            end: span.end > previous.end ? span.end : previous.end,
          ),
        );
      }
    }

    return ComposerDraft(
      text: draft.text.replaceRange(start, end, replacement),
      voiceSpans: compact,
    );
  }
}
