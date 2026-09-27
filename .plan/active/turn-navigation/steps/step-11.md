# Step 11 — The Prompts Screen

Branch `turn-navigation/prompts-screen`. Architecture 10, "The Prompts screen",
and Architecture 11, "Returning to the transcript".

## Plan Claims Checked

- A rendered follow-up row's id is `_entryIdForMessage` of its message (the
  message id, or `session-detail-prompt-<promptId>` for a user message carrying
  a `promptId`), and `_holdRow` reaches it built or not, folded or not. So D27
  needs no turn fallback. The seam tests land a `promptId` follow-up by its own
  row, unfolded twice and from a folded transcript.
- #1817 removed the post-frame pass the plan meant to publish the anchor from.
  The sticky layout now runs at layout time in `_layOutSticky`, so the anchor is
  written there, from the same opener list and pin line the pin uses. The pin's
  "current opener" rule was extracted as `currentTranscriptStickyIndex` so the
  pin and the anchor share one rule.
- The overlay's `_attachmentLabelOf` was the localized half of `promptText`'s
  resolution. The overlay now uses `opener.promptText`, falling back to
  "Attachment".

## Scope Delivered

- `transcript_prompts_opened` with the closed `AnalyticsPromptsEntry`
  (`session_bar`, `pinch`), `SessionDetailCubit.reportPromptsOpened`, and the
  deferred-candidates entry.
- `TranscriptJumpNotifier` and the current-prompt `ValueNotifier`, owned by
  `_SessionDetailBodyState` and passed through `SessionDetailLoadedView` to the
  list. The list writes the anchor at layout time and holds a jump's row with
  `_jumpToMessage`, unfolding first when folded.
- `features/session_prompts/`: `SessionPromptsView`, `PromptSpineRow` and
  `PromptDayHeaderDelegate`. Day labels come from
  `BuildContext.formatDayLabel` and row times from `formatTimeOfDay`, beside
  `formatMessageTimestamp`.
- The body's layer is a `Stack` over the page with `ExcludeFocus` and
  `ExcludeSemantics` toggling, and a `PopScope` so back closes it. There is one
  open method taking the origin, and the phone bar and desktop toolbar buttons
  both use it.
- The strings "Prompts", "Close prompts", "{n} prompts loaded", "No date",
  "Follow-up: {prompt}" and "No prompts in this session yet".
- Regression document and `docs/HARNESS_CAPABILITIES.md` prompt-times note.

## Deviations

- The anchor is written at layout time, not in a post-frame pass (see above).
- The overlay keeps `_glideToPrompt` for its tap (D42); `_jumpToTurn` no
  longer exists after #1817. So `_jumpToMessage` is new and has one caller, the
  Prompts screen.
- The title row is a fixed header above the scroll view, not a pinned sliver.
  Its height never changes, so the offset arithmetic covers only the list.
- `SessionPromptsView` takes a `TranscriptPromptList`. The body builds it from
  `state.messages` with `userMessagesBefore: null`, so no numbers show until
  step 15.
- `_jumpToMessage` resolves the message in the live `widget.messages`. It
  re-freezes a detached list's snapshot when the message arrived after the
  freeze, so every listed prompt is reachable. That prompt's turn is not built
  yet, so it lands just below the pin, where a follow-up would.
- A timed row shows the time of day alone (`formatTimeOfDay`, the `jm` pattern
  `formatMessageTimestamp` uses) rather than `formatMessageTimestamp`: every
  timed row sits under its day's header, so the date is not repeated. This is
  a follow-through of D38's day headers, not a new decision; the plan's line
  says so.
- The layer stays up until the jump lands: `TranscriptJumpNotifier.jumpTo`
  returns a future that the list completes when the hold ends, however it
  ends, so no step of a far jump shows. There is no transition; `origin` is
  plumbed and unused until step 12.
- The screen lists the prompts as they were when it opened, so an older page
  landing meanwhile (one already on its way, or one a far jump pages in) cannot
  shift the rows under the reader. Step 16's "Load earlier prompts" replaces
  that list when its own page lands.
- Until step 14 the phone bar shows back, Prompts, fold and more.
- Not done by hand on iOS or macOS: the device automation servers were
  unavailable. The PR screenshots come from widget renders with fixture data.

## Evidence

Flutter 3.47.5:
- `dart analyze --fatal-infos` is clean in `module_core`, `module_app_ui`,
  `client/app` and `client/desktop`.
- These tests pass:
  - `product_analytics_event_test.dart` and `session_detail_cubit_test.dart` (the new event and report);
  - `session_detail_message_list_test.dart` (the seams group, 7) and the rest of `test/features/session_detail/`;
  - `session_prompts_view_test.dart` (8);
  - `client/app` `session_detail_body_test.dart`;
  - `client/desktop` `desktop_session_detail_screen_test.dart`.
- `architecture-implementation-review` over `origin/main...HEAD`:
  - First review: rejected the jump resolving only in the frozen snapshot. Fixed in the list.
  - Second review: approved.
