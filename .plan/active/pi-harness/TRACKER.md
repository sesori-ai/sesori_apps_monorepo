# Pi Harness Support: Tracker

## Current State

- **Plan slug:** `pi-harness`
- **Implementation base:** `origin/main` at `3803df12`
- **Series state:** Step 1/15 in review
- **Current step:** 1/15, durable plan and protocol research
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/811
- **Next action:** monitor Step 1 and address review feedback

## Locked Decisions

`PLAN.md` is canonical. Execution must not reopen the confirmed target, native
permissions, normal Pi data, local login, always-`--approve` project trust,
documented terminal handoff, per-session residency, full-package install,
OpenCode default, or no-new-analytics decisions without the user.

## External Dependencies

- Pi Step 11 strictly requires `RuntimeAssetLayout.packageDirectory`; the local
  `phone-harness-install-cursor` branch at `6054d7cd` also generalizes
  `RuntimeVersion`, which Pi consumes if merged but does not independently need.
- Pi Step 12 waits for Claude activation; subsequent client work preserves all
  merged Claude identity, registry, package, CI, and brand entries.

## Delivery Steps

| Done | Step | Exact PR title | Target | State |
|---|---|---|---:|---|
| [ ] | 1/15 | `🌱 [pi-harness] docs: plan Pi harness support [step 1/15]` | 1,400-1,500 | In review |
| [ ] | 2/15 | `⚙️ [pi-harness] feat(pi): scaffold the protocol package [step 2/15]` | 900-1,300 | Not started |
| [ ] | 3/15 | `🚧 [pi-harness] feat(pi): add the JSONL RPC transport [step 3/15]` | 1,200-1,500 | Not started |
| [ ] | 4/15 | `⚙️ [pi-harness] feat(pi): enumerate persisted sessions [step 4/15]` | 1,000-1,400 | Not started |
| [ ] | 5/15 | `⚙️ [pi-harness] feat(pi): replay Pi session history [step 5/15]` | 1,100-1,500 | Not started |
| [ ] | 6/15 | `🚧 [pi-harness] feat(pi): map live messages and tools [step 6/15]` | 1,200-1,500 | Not started |
| [ ] | 7/15 | `⚙️ [pi-harness] feat(pi): bridge extension dialogs [step 7/15]` | 900-1,300 | Not started |
| [ ] | 8/15 | `🚧 [pi-harness] feat(pi): manage session residency and turns [step 8/15]` | 1,200-1,500 | Not started |
| [ ] | 9/15 | `⚙️ [pi-harness] feat(pi): expose models and commands [step 9/15]` | 900-1,300 | Not started |
| [ ] | 10/15 | `🚧 [pi-harness] feat(pi): implement the plugin API [step 10/15]` | 1,100-1,500 | Not started |
| [ ] | 11/15 | `🚧 [pi-harness] feat(pi): add managed runtime and lifecycle [step 11/15]` | 1,100-1,500 | Blocked on package-directory runtime support |
| [ ] | 12/15 | `⚙️ [pi-harness] feat(pi): register the Pi harness [step 12/15]` | 250-500 | Not started |
| [ ] | 13/15 | `⚙️ [pi-harness] feat(client): add Pi branding and guidance [step 13/15]` | 650-1,000 | Not started |
| [ ] | 14/15 | `🌿 [pi-harness] test(pi): verify the end-to-end integration [step 14/15]` | 200-500 | Not started |
| [ ] | 15/15 | `🌱 [pi-harness] docs: retire the Pi harness plan [step 15/15]` | 50-200 | Not started |

## Working Rules

- One Pi-series implementation PR is open at a time; every PR targets `main`.
- Merge in numeric order and rebase/merge current `origin/main` before opening
  each step so concurrent Claude/runtime work is preserved.
- Do not prepare implementation branches or worktrees from this plan PR.
- Count additions plus deletions from the merge base, including generated code
  and tests; split coherently or record an unavoidable overage.
- Generated outputs are regenerated, never hand-edited.
- Steps 2-13 run focused/full owning-package tests, fatal analysis, diff checks,
  and architecture implementation review.
- Step 13 validates touched client/package assets and tests. Step 14 validates
  the live product path. Steps 1 and 15 are documentation-only.
- Every PR body uses real multiline Markdown via `--body-file` and includes all
  required review sections.
- Start PR monitoring after every PR is opened.

## Plan Review

- 2026-08-10: initial architecture draft rejected; six ownership, layering,
  editor, attachment, and ID corrections applied without re-review.
- 2026-08-11: toast delta rejected one effect-identity gap; monotonic show
  sequence applied without re-review.

## Verification Log

### Step 1/15

- Architecture reviews: initial draft and toast delta rejected; all seven
  findings applied without re-review.
- Upstream repository/tag, RPC/session docs, and all six release digests match.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.
- Diff: +1,500/-0 = 1,500 changed lines; generated lines: 0; tests run: 0.
- Dart/Flutter suites: not run for this documentation-only step.
- Plan/content commit `813ca4ca`; PR
  https://github.com/sesori-ai/sesori_apps_monorepo/pull/811.

## Findings And Plan Deltas

- Reviews corrected architecture/lifecycle and added rendered toasts, visible
  compaction, bounded catalog scans, command acceptance, and current sequencing.
