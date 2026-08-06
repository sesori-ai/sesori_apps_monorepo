# Internal Chat History Store: Tracker

## Current State

- **Plan slug:** `internal-chat-history`
- **Implementation base:** `origin/main` at `232974e1`
- **Series state:** Step 1/8 plan PR open
- **Current step:** 1/8
- **Plan PR:** [#763](https://github.com/sesori-ai/sesori_apps_monorepo/pull/763)
- **Prerequisite:** the `read-only-archiving` series must merge fully before
  step 2/8 starts.
- **Next action:** merge PR #763; implement the `read-only-archiving` series;
  then start step 2/8.

## Delivery Steps

| Done | Step | Exact PR title | Estimate | State |
|---|---|---|---:|---|
| [ ] | 1/8 | `🌱 [internal-chat-history] Raise plan [step 1/8]` | 400–700 | [PR #763](https://github.com/sesori-ai/sesori_apps_monorepo/pull/763) open |
| [ ] | 2/8 | `🚧 [internal-chat-history] Introduce the chat history database [step 2/8]` | 1,500–2,600 | pending |
| [ ] | 3/8 | `🚧 [internal-chat-history] Capture live message events and backfill lazily [step 3/8]` | 900–1,400 | pending |
| [ ] | 4/8 | `⚙️ [internal-chat-history] Serve session messages from the store [step 4/8]` | 700–1,100 | pending |
| [ ] | 5/8 | `⚙️ [internal-chat-history] Paginate session messages [step 5/8]` | 600–1,000 | pending |
| [ ] | 6/8 | `🚧 [internal-chat-history] Export archives and purge history on archive [step 6/8]` | 1,000–1,500 | pending |
| [ ] | 7/8 | `🌿 [internal-chat-history] Load history pages on demand in the client [step 7/8]` | 500–900 | pending |
| [ ] | 8/8 | `🌱 [internal-chat-history] Retire plan [step 8/8]` | 50–150 | pending |

## Execution Rules

- Merge in numeric order; each PR must remain independently valid at its own
  base. A successor may target its open predecessor.
- Do not start step 2/8 until the `read-only-archiving` series has fully
  merged.
- Count additions plus deletions (including generated code and tests) against
  the 1,500-line soft cap; the step 2 overage from new-database codegen is
  pre-recorded in `PLAN.md`.
- Generated Drift/Freezed files change only through code generation; preserve
  every schema version already merged to `main`.
- Run focused tests, the owning package's tests, and the analyzer for each
  implementation step; run `architecture-implementation-review` (sub-agent)
  for steps 2, 3, 4, 5, and 6.
- Wire changes stay additive-optional; older-peer behavior is asserted by
  tests in step 5.

## Verification Log

- (empty)

## Findings And Plan Deltas

- **2026-08-06 — Plan revised after comparison with PR #764** (parallel
  draft, superseded): adopted watermark staleness, additive pagination
  fields, in-JSON stored-file attachment references with content-addressed
  spill files, capture-failure sync-row drop, log-and-proceed archive
  export. Details in `PLAN.md` § Plan Review Record.
- **2026-08-06 — Unarchive removal split out** into the prerequisite
  `read-only-archiving` plan per user direction; this series no longer
  contains unarchive or read-only-gate work.
