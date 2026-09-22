# Step 15 — Restyle composer selectors and the sub-agents bar

## Scope

- **Approved 2026-09-22 (D18).** The user approved variant A, the trailing
  pill, from real screenshots on 2026-09-21 and 2026-09-22, with two notes
  that are folded in below. The toolbar variant and its build flag are deleted.
- **Selectors (D16).** `AgentModelButtons` keeps agent, model and effort in one
  strip above the input on every surface. On a pointer surface the pills size
  to their labels; on touch they share the width. The pointer composer always
  shows the attach and command buttons and grows with the draft instead of
  opening the editor sheet. `ComposerPresentation` on
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
  28 running. It never claims a final state. Tapping opens the list above the
  pill in an `OverlayPortal`, running first, without changing the composer's
  height. The old bar, header, toggle and their strings are deleted.
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

- Size: 1,046 changed lines, 672 added and 374 deleted, across 31 files. 271
  are tests, 56 generated l10n, 11 docs.
- `dart analyze --fatal-infos` in `module_prego`, `module_app_ui`, `app` and
  `desktop`: clean.
- `flutter test --no-pub`: `module_prego` 325, `module_app_ui` 398 plus the
  three new pill tests, `app` 775, `desktop` 273, all passing.
- Screenshots reviewed by the user: `/tmp/sesori-ux/step15_review.html`,
  rendered from the real widgets. Not committed.
