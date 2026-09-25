# Step 43 — The auto-continuation card only when it is due

Branch `visual-hierarchy/continuation-notice`.

## What changed

- `sessionAutoContinuationNoticeVisible` decides when the card above the
  composer shows:
  - known or unknown reset: always. Disabled, it offers opt-in. Enabled, it
    counts down or says nothing can be scheduled.
  - paused, unconfirmed, failed and unknown statuses: while enabled. The
    failure text is unchanged.
  - idle and submitted: never. Nothing is due, and a sent continuation already
    shows in the transcript.
- While the preference is enabled and the card is hidden, a quiet
  "Auto-continue" chip joins the composer's model row after the YOLO chip. Its
  flat anchored menu, like the agent and variant pickers, has an
  "Auto continuation on" label and one Disable row. The row's subtitle gives the
  send time after a submission, "unavailable for this harness" for an
  unavailable harness, and "After quota resets" otherwise. Saving disables it.
- The YOLO and auto-continuation chips share a new `PregoComposerChip` pill
  in `module_prego`.
- Both shells get the change through the shared `SessionDetailComposerControls`
  and `SessionAutoContinuationNotice`.
- No wire change. The client already receives the continuation status.

## Deviations from the plan

- On touch, the chip shows only the clock. "Auto-continue" is kept as its
  tooltip and accessible name. With YOLO, a model and a variant, the labelled
  chip squeezed the phone's Expanded pickers down to "..". Pointer rows show
  the label. When both chips show on touch, YOLO also collapses to its glyph,
  because a 320-point row otherwise overflowed (review of #1706).
- Without a working harness (`canInteract` false), the composer is replaced by
  the harness notice, so an enabled idle preference shows neither the card nor
  the chip there. The top-right menu can still disable it.

## Verification

- `module_app_ui` `test/features/session_detail`: 271 passed, including the
  per-status visibility table, the notice widget tests and 4 new chip tests.
- `app` `session_detail_body_test`: 132 passed, including the new chip-to-card
  handoff test.
- `desktop` session detail, home pane, cockpit shell and router tests: 99
  passed.
- `dart analyze --fatal-infos` is clean in module_app_ui, app and desktop.
- Fixture-only before and after renders for phone and desktop, dark and light,
  are in the PR.
