# Step 47 — Expanded group as an anchored panel

Branch `visual-hierarchy/group-popover`. Client only, `module_app_ui`, shared
by both shells. No new cubit or widget state.

## What changed

- Tapping a group summary no longer opens its steps inline. Under a pointer
  `PregoInteractionScope` it opens them in the existing `PregoPopover`, below
  the summary, 560 px wide and capped at 480 px tall; past the cap the steps
  scroll, and Esc or an outside click closes it. Under touch it opens a
  `showPregoModal` sheet titled with the summary line.
- The steps keep their transcript rows (`ToolPartWidget`, `ReasoningPartCard`,
  `SubtaskPartWidget`), so a tool still opens its details inside the panel.
  The panel is a route of its own, so it takes the session page's
  `SessionDetailPresentationScope` and `SessionDetailCubit` along; the scope
  gains `around`, which the image viewer now reuses.
- Removed the group's inline disclosure: its `TranscriptDisclosure`, the open
  panel's `TranscriptPresenceColumn` and the summary's expanded chevron. Tool
  rows keep `TranscriptDisclosure`. The step 46 fold and rolling summary are
  unchanged.

## Deviations from the plan

- The panel shows the steps that had finished when it opened; a step that
  finishes while it is open appears on the next open. The panel is a snapshot
  because the route does not rebuild with the transcript, and a live panel
  would need the transcript's grouping inside the route for a rare case.

## Verification

- `module_app_ui`, `app` and `desktop`: full suites passed, and
  `dart analyze --fatal-infos` is clean in all three. New tests: the pointer
  popover opens below the summary without changing the transcript height and
  closes on Esc and an outside click; the touch sheet opens titled with the
  summary and closes on a scrim tap; a 60-step group's popover stays within
  its cap and leaves the transcript height unchanged.
- Fixture-only before and after screenshots, desktop popover and phone sheet,
  dark theme, are in the PR.
