# Step 15 — Restyle composer selectors and the sub-agents bar

## Scope

- **Approved 2026-09-22 (D18).** The user approved variant A, the trailing
  pill, from real screenshots on 2026-09-21 and 2026-09-22, with two notes
  that are folded in below. The toolbar variant and its build flag are deleted.
- **Selectors (D16).** `AgentModelButtons` keeps agent, model and effort in one
  strip above the input on every surface. On a pointer surface the pills size
  to their labels; on touch they share the width. The pointer composer always
  shows the attach and command buttons and grows with the draft, up to a third
  of the window, instead of opening the editor sheet. `ComposerPresentation` on
  `ComposerPresentationScope` carries the touch/pointer choice.
- **Start ellipsis (user note).** New `PregoStartEllipsisText` in the design
  system, used by `PregoPickerButton`. A label that does not fit keeps its end
  behind a leading ellipsis, "…Opus 5" rather than "Claude Op…". It is a
  `Text` subclass over a small render box, so `find.text` and intrinsic-width
  parents keep working and screen readers get the whole name. Flutter has no
  built-in start ellipsis, and the RTL-direction trick reorders trailing
  punctuation in names such as "GPT-4o (2024-08-06)", so the text is measured.
- **Sub-agents pill (D17, user note).** `BackgroundTasksBar` is a pill at the
  strip's trailing edge. While any sub-agent works it leads with a spinner and
  the running count, then the sub-agent glyph and the muted total; idle, it
  shows the glyph and the total only. Each number is read by the symbol next
  to it, so a session that used 28 disposable sub-agents no longer looks like
  28 running. It never claims a final state. Tapping opens the list in an
  `OverlayPortal`, running first, without changing the composer's height. It
  opens above the pill unless there is more room below, and scrolls rather
  than leaving the screen. The old bar, header, toggle and their strings are
  deleted.
- No wire, database or analytics change.

## Deviations From The Plan

- The phone's Changes button needed no change: the round 1 phone screenshots
  were rendered inside the desktop toolbar. The phone's glass bar has always
  shown Changes as an icon only.
- The start ellipsis was not in the plan. It came from the user at approval
  and is small, so it ships in this step rather than as a follow-up.
- Live smoke on the desktop build was done for variant A during the review
  rounds; the final pill and ellipsis were verified through rendered widget
  screenshots and tests, not another live run.

## Automated Evidence

Measured checkpoint: commit `260412856ac89e476c0f865dc5e7abedf2500d07` against
base `c3f638fddfd0ab9f2461c8b68f25a2f7c916c9cd`, Flutter 3.47.5 (Dart 3.13).
No log files were kept; CI on the PR is the durable record.

- `dart analyze --fatal-infos` in `module_prego`, `module_app_ui`, `app` and
  `desktop`: clean.
- `flutter test --no-pub`: `module_prego` 325, `module_app_ui` 398 plus the
  three new pill tests, `app` 775, `desktop` 273, all passing.
- Screenshots reviewed by the user: `/tmp/sesori-ux/step15_review.html`,
  rendered from the real widgets. Not committed.
- Architecture review: `architecture-implementation-review` ran once through a
  sub-agent on this branch against `main` after the measured checkpoint and
  approved it with no violations and no required changes.

## Size

**1,046 changed lines (672 additions and 374 deletions) across 31 files** at
the measured checkpoint. Of those lines, 271 are tests, 56 generated l10n and
11 documents. Reproduce from the root:

```sh
git diff --numstat c3f638fddfd0ab9f2461c8b68f25a2f7c916c9cd 260412856ac89e476c0f865dc5e7abedf2500d07
```

The step target was set at approval as 1,100; the repository soft cap is
1,500. The review follow-up below, this file and the tracker row come on top.

## Regression Documents

`session-creation-and-options.md` gains two bullets: the selector strip with
its start ellipsis, and the sub-agents pill with its list. The review
follow-up adds where the list opens, its screen-reader action and where the
desktop draft stops growing.

## Review Follow-up

Wave 1 (cubic, 9 threads; Codex, 4 threads) is answered in commit
`acebb69711029174e8935ca170de49d555f33679`, 341 changed lines (217 ignoring
whitespace, from re-indenting the overlay), 118 of them tests.

- Fixed: the pill's screen-reader node now carries the tap action (both
  reviewers). The list is placed with `OverlayPortal.overlayChildLayoutBuilder`
  from the pill's real rect: it opens toward the side with more room and caps
  its height, so a tall draft, an open keyboard or a short window no longer
  pushes its heading off screen, and its statuses stay live. The start-ellipsis
  label honours the system bold-text setting, updates semantics when the text
  direction changes, clips when narrower than one ellipsis, and keeps its
  minimum intrinsic width at or below its maximum. The always-open composer
  pill no longer rebuilds on every tap. This file gained its Size and
  Regression Documents sections.
- Declined with evidence: compact selectors already size to their labels,
  because a tight infinite `SizedBox` width reports its child's intrinsic
  width; a new test pins widths that differ per label. The touch strip keeps
  its layout on 320-point screens: each chip's row runs about 4 points into its
  own 12-point end padding there, so nothing is clipped in a release build.
  The tracker already had a step 15 row.
- Tests: `module_prego` start-ellipsis and picker tests (9), `module_app_ui`
  pill and composer pill tests (9), `app` selector, child-session navigation
  and session body tests (145), `desktop` session page tests (6), all passing.
  `dart analyze --fatal-infos` is clean in all four packages.

Wave 2 (cubic, 2 threads; Codex, 1 thread) is answered in commit
`cd918fdd3ca97b62d6f787b8509dee435e70c11d`, 33 changed lines, 24 of them tests.

- Fixed: on the 560 by 480 minimum desktop window a 16-line draft pushed the
  selectors and the sub-agents pill above the session view (Codex). The
  pointer draft now stops at a third of the window and scrolls. A new desktop
  test types 30 lines at that size and keeps the field at or under 160 points
  and the pill inside the view; it failed at 336 points before the fix.
- Declined with evidence: the list needs no trailing edge margin, because the
  composer controls are padded 16 points on both sides and the list lines up
  with the pill on purpose. Its heading cannot overflow: with the keyboard up
  the typing composer leaves about 120 points below the pill, with it down the
  whole screen above is free, and the heading needs about 40.
- Tests: `module_app_ui` session detail widget tests (194) and `desktop`
  session page tests (7), all passing. `dart analyze --fatal-infos` is clean in
  both packages.
