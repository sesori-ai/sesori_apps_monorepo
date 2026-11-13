import "dart:typed_data";

import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/composer/queued_session_submission.dart";
import "package:sesori_dart_core/src/services/composer_draft_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
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
  test("joinParagraphs joins drafts in order with blank lines, keeping each one's voice spans", () {
    final result = calculator.joinParagraphs(
      drafts: [
        ComposerDraft.typed(text: "first"),
        ComposerDraft.typed(text: "  "),
        voiceDraft("spoken", 0, 6),
        voiceDraft("typed then voice", 11, 16),
      ],
    );

    expect(result.text, "first\n\nspoken\n\ntyped then voice");
    expect(result.voiceSpans, [VoiceOriginSpan(start: 7, end: 13), VoiceOriginSpan(start: 26, end: 31)]);
  });

  group("restoreParagraphs", () {
    test("puts a later return after the earlier one and ahead of the draft, keeping voice spans", () {
      final result = calculator.restoreParagraphs(
        held: voiceDraft("first\n\nhalf", 7, 11),
        restoredPrefix: "first",
        restored: [voiceDraft("second", 0, 6)],
      );

      expect(result.draft.text, "first\n\nsecond\n\nhalf");
      expect(result.draft.voiceSpans, [VoiceOriginSpan(start: 7, end: 13), VoiceOriginSpan(start: 15, end: 19)]);
      expect(result.restoredPrefix, "first\n\nsecond");
    });

    test("puts a later return after an earlier one that is the whole draft", () {
      final result = calculator.restoreParagraphs(
        held: ComposerDraft.typed(text: "first"),
        restoredPrefix: "first",
        restored: [ComposerDraft.typed(text: "second")],
      );

      expect(result.draft, ComposerDraft.typed(text: "first\n\nsecond"));
      expect(result.restoredPrefix, "first\n\nsecond");
    });

    test("puts the return ahead of all of a draft that no longer starts with the earlier one", () {
      for (final held in ["fist\n\nhalf", "firstly"]) {
        final result = calculator.restoreParagraphs(
          held: ComposerDraft.typed(text: held),
          restoredPrefix: "first",
          restored: [ComposerDraft.typed(text: "second")],
        );

        expect(result.draft, ComposerDraft.typed(text: "second\n\n$held"));
        expect(result.restoredPrefix, "second");
      }
    });
  });

  group("restoreParagraphsUnderCommand", () {
    test("puts a later return after an earlier one the command was staged over, then spells the command out", () {
      final result = calculator.restoreParagraphsUnderCommand(
        command: "review",
        args: voiceDraft("first\n\nhalf", 7, 11),
        restoredPrefix: "first",
        restored: [ComposerDraft.typed(text: "second")],
      );

      expect(
        result.draft,
        ComposerDraft(
          text: "/review first\n\nsecond\n\nhalf",
          voiceSpans: [VoiceOriginSpan(start: 23, end: 27)],
        ),
      );
      expect(result.restoredPrefix, "/review first\n\nsecond");
    });

    test("puts the return ahead of the spelled-out command when its arguments hold no earlier one", () {
      final result = calculator.restoreParagraphsUnderCommand(
        command: "review",
        args: ComposerDraft.typed(text: "half"),
        restoredPrefix: "first",
        restored: [ComposerDraft.typed(text: "second")],
      );

      expect(result.draft, ComposerDraft.typed(text: "second\n\n/review half"));
      expect(result.restoredPrefix, "second");
    });

    test("spells the command out when the return brings no words", () {
      final result = calculator.restoreParagraphsUnderCommand(
        command: "review",
        args: ComposerDraft.typed(text: "half"),
        restoredPrefix: "",
        restored: const [],
      );

      expect(result.draft, ComposerDraft.typed(text: "/review half"));
    });
  });

  test("submissionDraft keeps a dictated send dictated and a command as its typed text", () {
    ComposerDraft? draftOf(QueuedSessionSubmission submission) => calculator.submissionDraft(submission: submission);

    expect(
      draftOf(
        const QueuedSessionSubmission.text(
          promptId: "prm_1",
          text: "spoken",
          inputMode: ComposerInputMode.voiceAssisted,
          attachments: [],
          agent: null,
          agentModel: null,
          fastMode: false,
        ),
      ),
      ComposerDraft(text: "spoken", voiceSpans: [VoiceOriginSpan(start: 0, end: 6)]),
    );
    expect(
      draftOf(
        const QueuedSessionSubmission.command(
          promptId: "prm_2",
          text: "the diff",
          command: "review",
          agent: null,
          agentModel: null,
          fastMode: false,
        ),
      ),
      ComposerDraft.typed(text: "/review the diff"),
    );
  });

  test("bridgePromptDraft unwraps dictated text and spells out commands", () {
    ComposerDraft? draftOf({required String? text, required String? command}) => calculator.bridgePromptDraft(
      prompt: QueuedSessionPrompt(commandSource: null, id: "prm_1", text: text, command: command, createdAt: 100),
    );

    expect(
      draftOf(text: wrapDictatedText(text: "spoken"), command: null),
      ComposerDraft(text: "spoken", voiceSpans: [VoiceOriginSpan(start: 0, end: 6)]),
    );
    expect(draftOf(text: "typed", command: null), ComposerDraft.typed(text: "typed"));
    expect(draftOf(text: "the diff", command: "review"), ComposerDraft.typed(text: "/review the diff"));
    expect(draftOf(text: null, command: "review"), ComposerDraft.typed(text: "/review"));
    expect(draftOf(text: null, command: null), isNull);
  });

  test("typedCommand types the command ahead of its trimmed arguments, keeping their voice spans", () {
    expect(
      calculator.typedCommand(command: "review", args: voiceDraft(" spoken ", 1, 7)),
      ComposerDraft(text: "/review spoken", voiceSpans: [VoiceOriginSpan(start: 8, end: 14)]),
    );
    expect(
      calculator.typedCommand(
        command: "review",
        args: ComposerDraft.typed(text: "  "),
      ),
      ComposerDraft.typed(text: "/review"),
    );
  });

  group("uniqueReturned", () {
    final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([1]), filename: null);
    final other = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([2]), filename: null);

    test("keeps each prompt once, where it first appears, taking later images only when it has none", () {
      final unique = calculator.uniqueReturned(
        prompts: [
          (promptId: "a", draft: ComposerDraft.typed(text: "listed"), attachments: const []),
          (promptId: "b", draft: ComposerDraft.typed(text: "b"), attachments: [other]),
          (promptId: "a", draft: ComposerDraft.typed(text: "submitted"), attachments: [image]),
          (promptId: "b", draft: null, attachments: [image]),
        ],
      );
      expect(unique.map((prompt) => prompt.promptId), ["a", "b"]);
      expect(unique.map((prompt) => prompt.draft?.text), ["listed", "b"]);
      expect(unique.map((prompt) => prompt.attachments), [
        [image],
        [other],
      ]);
    });
  });
}
