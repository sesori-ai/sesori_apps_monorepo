# Step 17 — Reconcile The Documents

Branch `turn-navigation/docs-reconcile`, published as PR 19/20. Documentation
only.

## Plan Claims Checked

- The regression document against what main ships after steps 10–16.b and the
  standalone steer-pin PR (#1842):
  - the Prompts screen's copy matches the English ARB strings ("Prompts",
    "Search prompts", "Close prompts", "Load earlier prompts", "No date",
    "{n} prompts loaded", "No prompts in this session yet", the match count,
    "Follow-up: {prompt}" and "Jump to this prompt");
  - the pinch thresholds (0.8 in; 1.25 or an outward fling to close, full at
    1.5×) match `transcript_pinch_detector.dart`;
  - a pinch out's focal point is held in `_pinchFocus`, apart from the opening
    origin, and drives the scale only while the pinch drives the controller
    (`session_detail_body.dart`). The transition paragraph claimed every way out,
    the pinch out included, shrinks back to where the screen opened; it now says
    a pinch out shrinks toward the fingers, and the plan's Architecture 13 no
    longer says the focal point becomes the origin;
  - steers pin like prompts and a message taller than the space below the pin
    line pins its end (#1842). Its accepted limitations (a message over the
    copy budget always pins its end, a height change can switch the pin mode,
    the long message's own bubble stays in semantics) were missing from Known
    Limitations and are added.
- `docs/HARNESS_CAPABILITIES.md` already records step 15's state: the six ACP
  harnesses time prompts Sesori sent and leave prompts read back from
  `session/load` undated, in both "Live timers" tables, and every harness
  numbers its prompts. Nothing changed there.
- Cross-references: the Feature Index entry in `docs/regression/README.md`,
  `session-turns.md`'s busy-send pointer (the L3 follow-up check it names is
  kept) and the capability doc's turn-boundary pointer are current.

## Scope Delivered

- The regression document's L2 and L3 cells, 4,527 and 2,252 characters on one
  line, become links to "Automated checks (L2)" and "Release checks (L3)"
  sections with wrapped bullets, following `voice-input.md` and
  `desktop-cockpit-shell.md`. This is the reflow #1844 deferred here. No
  coverage was dropped.
- The plan's L3 matrix, whose iOS row was 1,541 characters, becomes wrapped
  lists per platform, the other half of that deferral. Its stale content is
  updated: the pinned-message check covers steers and a message taller than the
  screen, the iOS edge swipe is listed, and the macOS "no fold shortcut" check,
  a tombstone for removed behavior, is gone.
- The plan's step 8 failure signal no longer says a follow-up must never pin.
- No code, generated file, localization, analytics or wire change.

## Evidence

- Every relative link and anchor in the regression document, `README.md`,
  `HARNESS_CAPABILITIES.md`, `PLAN.md` and `TRACKER.md` resolves (a local
  script over the Markdown links and headings).
- No line of the regression document exceeds 120 characters, and every table
  row is closed.
- No Dart or Flutter suite was run: the change is documentation only.
