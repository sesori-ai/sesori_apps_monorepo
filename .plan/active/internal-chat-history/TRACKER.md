# Internal Chat History Store: Tracker

## Current State

- **Plan slug:** `internal-chat-history`
- **Implementation base:** `origin/main` at `6723c833`
- **Series state:** Step 2/8 merged; step 3/8 in PR
- **Current step:** 3/8
- **Plan PR:** [#763](https://github.com/sesori-ai/sesori_apps_monorepo/pull/763) merged
- **Prerequisite:** satisfied — the `read-only-archiving` series merged fully on
  2026-08-07 (through [PR #771](https://github.com/sesori-ai/sesori_apps_monorepo/pull/771)).
- **Next action:** merge step 3/8, then start step 4/8.

## Delivery Steps

| Done | Step | Exact PR title | Estimate | State |
|---|---|---|---:|---|
| [x] | 1/8 | `🌱 [internal-chat-history] Raise plan [step 1/8]` | 400–700 | [PR #763](https://github.com/sesori-ai/sesori_apps_monorepo/pull/763) merged |
| [x] | 2/8 | `🚧 [internal-chat-history] Introduce the chat history database [step 2/8]` | 1,500–2,600 | [PR #768](https://github.com/sesori-ai/sesori_apps_monorepo/pull/768) merged |
| [ ] | 3/8 | `🚧 [internal-chat-history] Capture live message events and backfill lazily [step 3/8]` | 900–1,400 | in progress |
| [ ] | 4/8 | `⚙️ [internal-chat-history] Serve session messages from the store [step 4/8]` | 700–1,100 | pending |
| [ ] | 5/8 | `⚙️ [internal-chat-history] Paginate session messages [step 5/8]` | 600–1,000 | pending |
| [ ] | 6/8 | `🚧 [internal-chat-history] Export archives and purge history on archive [step 6/8]` | 1,000–1,500 | pending |
| [ ] | 7/8 | `🌿 [internal-chat-history] Load history pages on demand in the client [step 7/8]` | 500–900 | pending |
| [ ] | 8/8 | `🌱 [internal-chat-history] Retire plan [step 8/8]` | 50–150 | pending |

## Execution Rules

- Merge in numeric order; each PR must remain independently valid at its own
  base. A successor may target its open predecessor.
- The `read-only-archiving` prerequisite has merged fully, so no step in this
  series is blocked on it.
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

- **2026-08-07 — step 2/8:** `dart analyze --fatal-infos` clean in `bridge/app`;
  `dart test` in `bridge/app` green (2,440 tests), including the new
  `chat_history_purge_test.dart`.
- **2026-08-07 — step 3/8:** `dart analyze --fatal-infos` clean in `bridge/app`;
  `dart test` in `bridge/app` green (2,460 tests), including the new
  `chat_history_capture_test.dart`.

## Findings And Plan Deltas

- **2026-08-06 — Plan revised after comparison with PR #764** (parallel
  draft, superseded): adopted watermark staleness, additive pagination
  fields, in-JSON stored-file attachment references with content-addressed
  spill files, capture-failure sync-row drop, log-and-proceed archive
  export. Details in `PLAN.md` § Plan Review Record.
- **2026-08-06 — Unarchive removal split out** into the prerequisite
  `read-only-archiving` plan per user direction; this series no longer
  contains unarchive or read-only-gate work.
- **2026-08-07 — Prerequisite narrowed.** The dependency is real only for
  step 6/8 (archive export and purge), which re-sequences `_doArchive` and
  relies on archive permanence. Steps 2/8–5/8 touch none of the archiving
  code, so the two series run in parallel. Recorded after the user started
  `read-only-archiving` separately.
- **2026-08-07 — Second watermark source wired in step 4/8** as deferred below:
  `SessionRepository` now publishes a `backendActivity` stream from catalog
  import, and `ChatHistoryActivityListener` feeds it into the store's
  staleness marks. Success Criterion 3 is verified here.
- **2026-08-07 — Second watermark source deferred to step 4/8.** The plan lists
  two inputs for `backend_activity_at`: live capture and catalog import
  observing newer backend activity. Only capture has a caller until serving
  exists, so the catalog-import input (and the `observeBackendActivity`
  surface it needs) moves to step 4/8, where the staleness comparison it feeds
  is introduced. Success Criterion 3 is therefore verified in step 4, not 3.
- **2026-08-07 — Backfill atomicity tightened.** The plan says a backfill
  atomically replaces rows and sets the watermark; the first implementation
  split the row replace and the sync-state write into two statements. They now
  share one transaction, so a crash cannot leave a replaced transcript
  described by the previous run's freshness marks.
