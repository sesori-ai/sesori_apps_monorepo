# Internal Chat History Store: Tracker

## Current State

- **Plan slug:** `internal-chat-history`
- **Implementation base:** `origin/main` at `e884a580`
- **Series state:** Complete — all steps merged
- **Current step:** retired (plan moved to `.plan/completed/`)
- **Plan PR:** [#763](https://github.com/sesori-ai/sesori_apps_monorepo/pull/763) merged
- **Prerequisite:** satisfied — the `read-only-archiving` series merged fully on
  2026-08-07 (through [PR #771](https://github.com/sesori-ai/sesori_apps_monorepo/pull/771)).
- **Next action:** none — the series is complete. Three groups of remaining
  harness-free work are assessed in `PLAN.md` § Step 9/9 for a follow-up plan
  pending product decisions: agents/providers/commands on a stopped backend,
  history on a cold or stale session (which backfills through `_runtime.use`
  and fails a first-time or stale open when a no-auto-start backend is
  unavailable), and the attach-mode pending-state gap (an independently owned
  OpenCode server can outlive a bridge restart holding pending interactions
  while `useIfActive` returns null because the runtime slot is inactive, so
  bridge inactivity must be distinguished from backend unavailability).

## Delivery Steps

| Done | Step | Exact PR title | Estimate | State |
|---|---|---|---:|---|
| [x] | 1/8 | `🌱 [internal-chat-history] Raise plan [step 1/8]` | 400–700 | [PR #763](https://github.com/sesori-ai/sesori_apps_monorepo/pull/763) merged |
| [x] | 2/8 | `🚧 [internal-chat-history] Introduce the chat history database [step 2/8]` | 1,500–2,600 | [PR #768](https://github.com/sesori-ai/sesori_apps_monorepo/pull/768) merged |
| [x] | 3/8 | `🚧 [internal-chat-history] Capture live message events and backfill lazily [step 3/8]` | 900–1,400 | [PR #776](https://github.com/sesori-ai/sesori_apps_monorepo/pull/776) merged |
| [x] | 4/8 | `⚙️ [internal-chat-history] Serve session messages from the store [step 4/8]` | 700–1,100 | [PR #781](https://github.com/sesori-ai/sesori_apps_monorepo/pull/781) merged |
| [x] | 5/8 | `⚙️ [internal-chat-history] Paginate session messages [step 5/8]` | 600–1,000 | [PR #783](https://github.com/sesori-ai/sesori_apps_monorepo/pull/783) merged |
| [x] | 6/8 | `🚧 [internal-chat-history] Export archives and purge history on archive [step 6/8]` | 1,000–1,500 | [PR #785](https://github.com/sesori-ai/sesori_apps_monorepo/pull/785) merged |
| [x] | 7/9 | `🌿 [internal-chat-history] Load history pages on demand in the client [step 7/9]` | 500–900 | [PR #787](https://github.com/sesori-ai/sesori_apps_monorepo/pull/787) merged |
| [x] | 8/9 | `⚙️ [internal-chat-history] Stop waking a harness for pending questions and permissions [step 8/9]` | 300–600 | [PR #788](https://github.com/sesori-ai/sesori_apps_monorepo/pull/788) merged |
| [x] | 9/9 | `🌱 [internal-chat-history] Retire plan and scope the remaining harness-free work [step 9/9]` | 150–400 | in progress |

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
- **2026-08-08 — step 4/8:** analyzer clean; `bridge/app` green (2,475 tests).
- **2026-08-08 — step 5/8:** analyzer clean in `bridge/app`, `sesori_shared`,
  `client/module_core`, and `client/app`; `bridge/app` 2,493 tests,
  `sesori_shared` 364, `client/module_core` 1,006, `client/app` 915.
- **2026-08-08 — step 6/8:** analyzer clean; `bridge/app` green (2,516 tests).
- **2026-08-08 — step 7/9:** analyzer clean in `client/module_core` and
  `client/app`; `module_core` 1,030 tests, `client/app` 922.
- **2026-08-08 — step 8/9:** analyzer clean; `bridge/app` green (2,520 tests),
  including the new `pending_state_without_start_test.dart`.

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
- **2026-08-07 — Second watermark source deferred to step 4/8.** The plan lists
  two inputs for `backend_activity_at`: live capture and catalog import
  observing newer backend activity. Only capture has a caller until serving
  exists, so the catalog-import input (and the `observeBackendActivity`
  surface it needs) moves to step 4/8, where the staleness comparison it feeds
  is introduced. Success Criterion 3 is therefore verified in step 4, not 3.
- **2026-08-07 — Second watermark source wired in step 4/8** as deferred
  below: `CatalogImportRepository` publishes a `backendActivity` stream as it
  commits an import, and `ChatHistoryActivityListener` feeds it into the
  store's staleness marks. Success Criterion 3 is verified here.
- **2026-08-07 — Backfill atomicity tightened.** The plan says a backfill
  atomically replaces rows and sets the watermark; the first implementation
  split the row replace and the sync-state write into two statements. They now
  share one transaction, so a crash cannot leave a replaced transcript
  described by the previous run's freshness marks.
- **2026-08-08 — Corrected the activity producer.** The first step-4 draft
  published from `SessionRepository`'s active-root hydration path, which only
  runs when an active session has no bridge binding — so for a normally
  imported catalog nothing was ever published and Criterion 3 was unmet
  despite being claimed. The producer now lives in the import commit, uses the
  backend's own reported `updated` time (never the merged `updatedAt`, which a
  rename moves), and is pinned by a test. Found by architecture review.
- **2026-08-08 — Harness startup constraints recorded** in `PLAN.md` per user
  direction: harnesses respond poorly right after starting, so nothing in this
  feature may fetch on a lifecycle event or batch requests at startup, and
  "reading history never starts a harness" is now stated as a primary goal in
  Success Criterion 1 rather than left implicit.
- **2026-08-08 — No fallback for a missing backend update time.** Review asked
  for one when a plugin omits `time.updated`. Both candidates are worse than
  the gap: the merged catalog `updatedAt` is moved by renames, and the import
  clock would mark every such session stale on every import and wake its
  harness. Recorded in `PLAN.md` § Known Limits instead.
- **2026-08-08 — Step 8/8 widened to scope a harness-free session open.**
  Running a bridge on step 4/8 showed the store serving history correctly while
  session open still felt unchanged: the same snapshot calls
  `getPendingQuestions`/`getPendingPermissions` (and the options lookups)
  through `PluginRuntime.use`, which starts an idle backend. Serving history
  locally therefore does not deliver a harness-free open on its own. Step 8/8
  now retires the plan *and* produces an aligned written assessment of the
  remaining plugin-starting calls; implementation stays out of this series.
  Recorded per user direction after observing it on a live bridge.
- **2026-08-08 — Series extended to nine steps.** A new step 8/9 moves
  `getPendingQuestions`/`getPendingPermissions` to `useIfActive`, and plan
  retirement becomes step 9/9. Rationale, confirmed against the plugins: a
  stopped harness holds no pending state — ACP keeps it in an in-memory
  approval registry that starts empty, and OpenCode serves it from its running
  HTTP server — so starting a backend to ask can only ever return none after
  paying the full start cost. Steps 1–6 keep their merged `/8` titles because
  history is not rewritten. Requested by the user after observing that session
  open still felt unchanged on a bridge running step 4.
- **2026-08-08 — Non-auto-starting backends added to the step 9/9 questions.**
  A backend configured never to auto-start makes "start it to find out"
  unavailable rather than merely slow, so it is the sharpest test of what each
  snapshot call should do when the harness is stopped. To be discussed with the
  user after the plan completes.
- **2026-08-08 — Archive storage refactored between steps 6 and 7.** Four
  review rounds on PR #785 landed on the same seam: replacing an audit file in
  place needs a scratch slot, and a fixed-name slot has states that must be
  reconciled everywhere. Filenames now carry a generation
  (`<session>.<generation>.json`) and are never replaced, which removed the
  Windows rename fallback, the displaced slot, and its recovery logic
  ([PR #786](https://github.com/sesori-ai/sesori_apps_monorepo/pull/786)).
  Raised separately from the series because it changed code step 6 had already
  shipped.
- **2026-08-08 — Step 9/9: series complete.** All implementation steps merged
  (1–8, plus the two follow-up fixes for paging render and the detach freeze).
  Two groups of calls can still start a stopped backend in session open: the
  three options lookups (`listAgents`, `listProviders`, `listCommands`), which
  use `_runtime.use`, and **history on a cold or stale session**, which
  backfills through `_runtime.use` when the store is missing, unsynced, or
  behind observed backend activity. Current, previously synced history is
  served entirely from the store. The assessment in `PLAN.md` § Step 9/9
  recommends wiring the existing `SessionOptionsService.loadCacheOnly` (not
  `loadDynamic`, whose cache-miss path starts the backend) into the
  stopped-backend path, requires a `complete` cache entry so a `partial`
  snapshot is not served as authoritative, and flags the `--no-auto-start`
  backend as the decisive case needing a product decision. Follow-up plan
  pending those decisions.
