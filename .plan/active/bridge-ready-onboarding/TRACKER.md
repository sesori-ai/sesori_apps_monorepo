# Bridge-Ready Mobile Onboarding: Tracker

## Plan State

- **Status:** architecture review corrections applied; plan PR in review
- **Plan slug:** `bridge-ready-onboarding`
- **Implementation base:** `origin/main` at
  `f8c71eb78987aa8c64e397e8e8e3bb72eefa0692`
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/580
- **Implementation state:** not started

## Plan Review

- **Verdict:** rejected with four actionable findings; all findings applied
  directly; revised plan not re-reviewed
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-26
- **Reviewed scope:** `.plan/active/bridge-ready-onboarding/`

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line budget | State |
|---|---|---|---|---:|---|
| [ ] | 1/2 | `bridge-ready-onboarding-session-lifecycle` | `[bridge-ready-onboarding] refactor(bridge): separate session startup from serving [step 1/2]` | 500-800; reassess at 1,300; maximum 1,500 | Not started |
| [ ] | 2/2 | `bridge-ready-onboarding-relay-first` | `[bridge-ready-onboarding] fix(bridge): start relay before mobile onboarding [step 2/2]` | 450-750; reassess at 1,300; maximum 1,500 | Blocked on Step 1 merge |

## Execution Rules

- Step 1 is a standalone refactor PR that preserves user-visible startup
  behavior while making partial-start cleanup explicit. It must not contain
  onboarding ordering or copy changes.
- Step 2 starts from updated `origin/main` only after Step 1 merges. Do not open
  it as a stacked PR.
- Count additions plus deletions, including tests, against each PR base.
- Stop and update the plan before either PR exceeds 1,500 changed lines.
- Any newly discovered substantial refactor remains out of Step 2. Pause and
  revise the series rather than mixing it into the feature PR.
- Run the focused tests, strict app analyzer, and architecture implementation
  review declared for each step before merging.

## Current Pointer

- **Next action:** merge the plan PR, then create Step 1 from current
  `origin/main` and pin its actual base SHA in the PR body.

## Findings And Plan Deltas

- **2026-07-26 — Plan delivery:** Opened plan PR
  [#580](https://github.com/sesori-ai/sesori_apps_monorepo/pull/580) from the
  dedicated `bridge-setup-ux-assessment` branch.
- **2026-07-26 — Architecture review corrections:** Applied all four
  `aristotle-plan-review` findings without claiming approval of the revised
  plan: moved prompt rendering from `AppClientOnboardingService` to a private
  runner method; made one internally observed lifecycle future own startup,
  serving, partial-start cleanup, and teardown; fixed readiness at the
  non-awaited first `StreamIterator.moveNext()` invocation; and added removal of
  the now-unused status `wait` parameter/query branch to Step 2.
- **2026-07-26 — Initial split:** Chose a two-PR sequence so the required
  `OrchestratorSession` start/wait lifecycle refactor is independently
  reviewable and the second PR contains only the user-visible relay-first
  onboarding change.
- **2026-07-26 — Line budget:** Fixed a 1,500 changed-line maximum per
  implementation PR, with mandatory reassessment at a 1,300-line projection.
