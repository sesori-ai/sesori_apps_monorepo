# Step 10 — The Prompt List Model

Branch `turn-navigation/prompt-list-model`. Architecture 10, "The prompt list
model".

## Plan Claims Checked

- `TranscriptTurn` carries only message ids beyond `opener`, and
  `TranscriptTurnBuilder` skips non-renderable user messages, so the builder
  takes `messages` and uses `turns` only to classify.
- After #1817 the overlay resolves the text as `UserMessageCard.markdownOf`
  (text parts joined with a newline), else `_attachmentLabelOf` (the first file
  part's trimmed name, else localized "Attachment"). `promptText` is that
  resolution without the localized fallback; step 11 points the overlay at it.

## Scope Delivered

- `transcript_prompt_list.dart`: the sealed entry with its opener and follow-up
  variants, the list and its builder, as planned.
- `promptText` and `firstNonBlankLine` in `session_detail_resolvers.dart`; the
  turn model's private `_firstLine` moved there, so both builders share it.

## Deviations

- `hasTimes` and `promptCount` are getters over `entries`, not stored fields.

## Evidence

Dart 3.13.4 from Flutter 3.47.5: `dart analyze --fatal-infos` clean in
`module_core`; `transcript_prompt_list_test.dart` (7) and
`transcript_turns_test.dart` pass. `architecture-implementation-review` over
`origin/main...HEAD` approved with no findings.
