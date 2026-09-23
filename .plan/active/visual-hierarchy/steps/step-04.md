# Step 4 — Anchored pickers

Step 4 measured about 2,080 changed lines against a ≤ 600 target, about 980
of them deletions of the replaced sheets. It lands as three PRs that each
stand alone, following the plan's `31.a` convention:

- **4.a** Prego popover capabilities, and the plan update that added steps
  35–37.
- **4.b** The shared picker search list and the model picker.
- **4.c** The command picker and the regression docs.

## 4.a — Prego popover capabilities

### What changed

- `PregoPopover` gains `popoverMaxHeight` and `contentScrolls`. A picker can
  cap its height and bring its own scroll view, keeping a search field pinned
  above its rows. Every existing caller passes `null` and `false`, and keeps
  its behaviour.
- `AnchoredFlatPanel` measures room and screen clamps from where its trigger
  is now, not where it was when the popup opened. It reads the shift the
  `CompositedTransformFollower` painted with after each frame, and hands it
  back to the follower. Before this, a composer lifted by the keyboard dragged
  an open popover up past the top edge.
- Plan: steps 35–37 were added at the user's request: the modal lint rule,
  the compaction row, and turn navigation prototypes. Sign-in, the header
  backdrop, docs and retirement moved to 38–41.

### Verification

- `client/module_prego`: `prego_popover_test.dart` adds three cases: content
  that scrolls itself gets the capped height; the popover stays above a
  trigger the keyboard lifts after it opens; and it keeps inside the window
  edges beside a corner trigger. The package suite passed (341), and
  `dart analyze --fatal-infos` is clean.
- `client/desktop`: `desktop_bridge_popover_test.dart` passed (7).
