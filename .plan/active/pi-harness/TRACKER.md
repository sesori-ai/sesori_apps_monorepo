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

- Pi Step 11 requires `phone-harness-install` Step 5's
  `RuntimeAssetLayout.packageDirectory` and generalized `RuntimeVersion` on
  `main`. The work existed on local branch `phone-harness-install-cursor` at
  `6054d7cd` when this plan was written, but had no PR. Do not duplicate it.
- Pi activation/client steps rebase on the active Claude series and preserve all
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
| [ ] | 13/15 | `🌿 [pi-harness] feat(client): add Pi branding and guidance [step 13/15]` | 400-800 | Not started |
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
- Steps 2-12 run focused/full owning-package tests, fatal analysis, diff checks,
  and architecture implementation review.
- Step 13 validates touched client/package assets and tests. Step 14 validates
  the live product path. Steps 1 and 15 are documentation-only.
- Every PR body uses real multiline Markdown via `--body-file` and includes all
  required review sections.
- Start PR monitoring after every PR is opened.

## Plan Review

- **Reviewer:** `architecture-plan-review` sub-agent, 2026-08-10
- **Scope:** `PLAN.md`, with this tracker and `PROTOCOL.md` as supporting context
- **Verdict:** initial draft rejected; corrected plan not re-reviewed
- **Corrections:** catalog layering; tracker/discovery semantics; session
  path/lease ownership; editor prefill; attachment variants; session ID ownership

## Verification Log

### Step 1/15

- Architecture review: initial draft rejected; all six findings applied.
- Upstream repository/tag, RPC/session docs, and all six release digests match.
- `git diff --check origin/main...HEAD`: pass.
- Diff: +1,474/-0 = 1,474 changed lines; generated lines: 0; tests run: 0.
- Dart/Flutter suites: not run for this documentation-only step.
- Commit `1bf4aea2`; PR https://github.com/sesori-ai/sesori_apps_monorepo/pull/811.

## Findings And Plan Deltas

- `PROTOCOL.md` is canonical for upstream findings and runtime traps.
- Architecture review clarified the catalog probe/repository/tracker/service
  chain, session-path ownership, transient process leases, editor-prefill
  degradation, attachment variants, and session-ID ownership.
- Duplicate research and delivery text was removed so Step 1 remains under the
  1,500-line soft cap without splitting the required initial plan artifacts.
- PR review removed unreachable Sesori-created parent forks and moved auth
  classification from cwd-less setup to project-scoped operations.
- Follow-up review pinned safe prompt projection, descendant dialogs,
  pending-new recovery, command barriers, and empty-parts creation.
- Later review aligned extension UI layers, RPC DTOs, lane admission, command
  projection, model defaults, health, and runtime-only setup.
