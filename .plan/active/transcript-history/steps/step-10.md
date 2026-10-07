# Step 10 — Pin The Prompt Above An Unloaded Range

Branch `transcript-history/unloaded-pin`. `client/module_core`,
`client/module_app_ui` and docs. No bridge, wire or database change.

## Scope Delivered

- **Business rule (`client/module_core`):**
  `TranscriptPromptListBuilder.pinAbove(turns, index)` returns the last index
  entry before the first prompt the rendered messages hold, when they start
  inside a turn (`TranscriptPartialTurn`), else null.
- **List (`client/module_app_ui`):** `SessionDetailMessageList` takes
  `promptIndex` and `onLoadThrough`. It prepends the entry as one more
  `TranscriptStickyAbove` opener; `_stickyOpeners` stays layout-only. It
  keeps the last non-null index, so the pin survives the cubit nulling the
  index for a refresh (P8). A tap on the pin calls
  `SessionDetailCubit.loadMessagesThrough`, shows a spinner beside the pin
  after 150 ms, shows a popup on failure, and on success glides to the prompt
  once the list has built it.
- **Detached snapshot:** older history now joins the frozen transcript
  whenever the oldest message changes, not only when an older page request
  ends, so a load-through while reading history renders too.
- **Overlay:** `TranscriptStickyPromptOverlay` is stateful. It pins the
  preview in the normal bubble (O2). The pin fades in when the entry first
  appears. When the prompt loads, its pin crossfades from the preview to the
  loaded copy, and the bubble rect eases between the two sizes, so a long
  prompt that pins its end changes visibly but never snaps. Reduced motion
  skips both.

## Deviation From The Plan

The plan picks the entry below `olderMessagesCursor`. The pin reads where the
rendered messages start instead. While the reader scrolls back, the list
renders a frozen snapshot that can start later than the cursor, and the pin
must sit above what is shown.

## Accepted Edges

- A range that starts with a follow-up pins that follow-up, as the index
  orders it.
- When the entry changes from one unloaded prompt to another, the new one
  fades in and the old one leaves at once; it was above the new one, so it
  was not pinned.

## Evidence

- `dart analyze --fatal-infos` in `client/module_core` and
  `client/module_app_ui`.
- `module_core`: `transcript_prompt_list_test.dart`, including the `pinAbove`
  group (entry before the first loaded prompt, none at a turn start or at the
  history's start, none without an index).
- `module_app_ui`: `test/features/session_detail` and
  `test/features/session_prompts`, including the "of an unloaded turn" group:
  the preview pin, the fade-in and the kept pin through a refetch, the tap
  with the delayed spinner, the crossfade and the glide, and a failed load's
  popup with the pin kept.
