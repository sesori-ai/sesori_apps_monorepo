# Step 7 — Move Pi, Codex And DeepSeek Onto The Live Compaction Row

Branch `compaction-progress/pi-codex-deepseek`. This covers three bridge
plugins. There is no client, wire or database change, because step 4's row
already renders each state.

## Scope Delivered

- **Pi:**
  - `PiHistoryMapper` is the one builder of compaction rows. It has running,
    completed and the new failed variant, and all three share one private
    builder.
  - `mapCompaction` maps `PiCompactionReason` to a trigger: manual→manual,
    threshold/overflow→auto, unknown→none. History reads carry no reason or
    stamp.
  - `PiEventDispatcher` keeps the live compaction as a record of the reserved
    message id and its start stamp. A late viewer and the settle both reuse
    that stamp. A `willRetry` failure keeps the running row.
  - A terminal failure or abort moves the row off the reserved id through
    `PiMessageIdentityBuilder.abandonCompaction` (which replaces
    `releaseCompaction`). The row becomes a "Compaction failed" note with the
    error, and no session error is raised.
  - `clearCompaction` (turn exit) moves the running row the same way, and the
    bridge's idle sweep fails it.
- **Codex:** `item/started` for `contextCompaction` emits a running compaction
  part instead of a running `compact` tool card. With no `startedAtMs`, the
  mapper stamps the start into `_itemTimes`, so the settle keeps the same
  creation time.
- **DeepSeek:**
  - The new `DeepSeekCompactionTracker` (repositories/trackers, injected
    `ServerClock`) keeps one running entry per session.
  - `compaction_started` shows the running row, and a repeated start keeps
    its id and timer. `compaction_completed` settles it in place before
    `SessionCompacted`.
  - The mapper clears the tracker in `resetLiveState`, `beginTurn` and
    `forgetSession`.
- **Docs:** `HARNESS_CAPABILITIES.md` (the Pi, Codex and DeepSeek compaction
  rows), `tools-and-file-changes.md` and `session-turns.md`.

## Deviations And Accepted Limits

- **No freed count anywhere in this step.**
  - Pi reports `tokensBefore` but no after-count.
  - Codex's compaction item carries no token fields.
  - DeepSeek's status carries none.
- **No summary on Codex or DeepSeek.** Neither harness reports one.
- **DeepSeek history.** The row is live only. It survives one re-import and
  then disappears, because the runtime does not store compactions.
- **Pi manual `/compact` with a failing RPC.** The command turn still ends
  through `_finish(failed)`, so the generic session error appears beside the
  note. This is unverified live and left as is.
- **Pi failure note.** It settles without a cross-fade because the row moves
  to a new id. This is the plan's accepted exception to P9.
- **Outage.** A row whose end is missed while the stream is down stays running
  until a later ordinary read once the session is idle (a general reconnect
  gap); stored-only reads and busy or retrying sessions skip that sweep.
- **Older apps (Q5).** They show only "Working…" while compaction runs. There
  is no old-client code.

## Evidence

Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`.

- **`bridge/`:** `dart analyze --fatal-infos` found no issues.
- **`sesori_plugin_pi`:** analyze is clean, and 348 tests pass. They cover
  the lifecycle stamp, the triggers, `willRetry`, terminal failure and abort,
  `clearCompaction`, the late viewer and the pre-prompt compaction.
- **`sesori_plugin_codex`:** analyze is clean, and 479 tests pass. They cover
  a start with and without `startedAtMs`, each settling in place.
- **`sesori_plugin_deepseek`:** analyze is clean, and all tests pass. They
  cover the scaffold compaction group and the new tracker test.
- **Formatting:** `dart format --line-length 120` was applied only to the
  touched hunks.
- **PR media:** none new. The row is unchanged from 6a, so the PR points to
  `pr-media` under `compaction-progress/opencode/`.

## Reviews

- **`architecture-implementation-review` of `bcf2dc88bf`:** approved, with no
  findings.
- **PR #1908, five review waves.** It merged `origin/main` once
  (`1836e166d7`), after wave 2, and merged as `5dd2d6be85` on 2026-10-08.
  - **Wave 1 (`deb8e0ee73`):** Codex was clean. cubic had six findings, and
    five were fixed in `341baeefad`:
    - a Codex completion with no known start keeps `completedAtMs`;
    - a Pi failure with no recorded start reports the session error again;
    - three doc fixes (a line wrap, Pi's "· auto" only after completion with
      an optional error, and Pi id continuity only on success).

    Declined: two abandoned Pi compactions sharing one millisecond stamp.
    Each attempt needs a model round-trip, and a `willRetry` retry keeps its
    row, so no flow produces it.
  - **Wave 2 (`341baeefad`, Codex):** both findings fixed in `dee052f4ae`.
    Codex and DeepSeek stamp compactions through `PluginHost.clock`.
  - **Wave 3 (`1836e166d7`, Codex):** fixed in `01211e533b`. DeepSeek status
    frames are held while the prompt is written, so a compaction that starts
    with the prompt lands after the user message.
  - **Wave 4 (`01211e533b`, Codex):** fixed in `a196db2b8d`. The Pi
    compaction mapper callback takes required named parameters.
  - **Wave 5 (`a196db2b8d`, Codex):** declined. A Pi process exit
    mid-compaction while a selection-changing prompt waits keeps the moved
    row running through that queued turn, until its idle sweep writes the
    failure note. The damage is cosmetic and heals itself, and settling it in
    `clearCompaction` would replace the sweep's explanatory note in the
    common Stop case.

## Size

888 changed lines against the merge base (709 added, 179 deleted): 89 of
this file, about 340 of production code, about 385 of tests and 73 of docs.
Nothing is generated.

## Step 7b — One Codex Row After A Reload

Branch `compaction-progress/codex-reimport-dedup`. Step 9's live run on Codex
found two "Context compacted" rows after a manual compact and a reload: the
live row under the item id, and the history row `codex-compaction-N`, about
11 s apart and with no summary.

### Root Cause

The live row is keyed by the `contextCompaction` item id and created at
`startedAtMs`. The history mapper built its row from the rollout's
`compacted` line alone, under a replay-counter id and that line's timestamp,
which Codex writes when compaction ends. So neither the id nor the time
agreed, and 5b's replay rule (content plus an equal known time) could not
pair the rows.

The rollout also stores the live item. After the `compacted` line, Codex
writes an `item_completed` event with `item: {type: ContextCompaction, id}`
and `started_at_ms`/`completed_at_ms`, the same values the live notification
carried. Every local rollout with a compaction has one, except a forked
session's inherited compaction, which has no live row.

### Fix

Codex plugin only. The rollout DTO reads the `ContextCompaction` completed
item and the event's two times. The history mapper re-keys the last
`compacted` row with that item's id and part id `<id>-tool`. It takes the
item's start, else its end (as the live mapper does for a completion with no
known start), as the creation time, and keeps the line's time when the item
has neither. So a reload replaces the live row by exact identity, and the
bridge's replay rule is unchanged. A `compacted` line with no item keeps
`codex-compaction-N` and its own timestamp.

### Evidence

Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`.

- `sesori_plugin_codex`: `dart analyze --fatal-infos` no issues; all 481
  tests pass.
- New test: a rollout in Codex's record order (`compacted`, another event,
  then the `ContextCompaction` item), three times: with both times, with only
  the end, and with none. Every row takes the item id and part id; the first
  takes the start and end, the second the end for both, and the third keeps
  the `compacted` time. Without the fix it fails with `codex-compaction-1`
  instead of the item id.
- Live rerun, source-run bridge on slot 1 through the debug port: a new
  one-prompt Codex session, manual compact, then a forced stale re-read (the
  sync state's backend activity bumped past its watermark). The re-import
  rewrote every row and left one compaction row under the live item id, with
  the live creation and completion times.

No wire or database change.

### PR Review

- **Wave 1 (`0286fc1d82`):** Codex was clean. cubic had four findings, and
  three were fixed: an item with only its end now takes that end as both
  times, and PLAN and this section say so. Declined: making 7b a prerequisite
  of step 9's row. Step 9's own live run found this fix, so the retirement
  waits for it already, and the parallel Pi fix keeps edits off that row.

## 7c — Settle Pi Compaction Without A Failed Flash

Branch `compaction-progress/pi-compaction-settle`, a fix found by step 9's
live run on Pi 1.1.0. Only `sesori_plugin_pi` changes. There is no client,
wire or database change.

### Root Cause

- Pi writes `compaction_end` to stdout just before its reply to the `compact`
  RPC (`agent-session.js` `compact()`, then `rpc-mode.js`), so a single pipe
  read usually carries both lines.
- In the bridge, an event frame reaches `PiSessionService._handleFrame`
  through two asynchronous broadcast streams (`PiRpcClient.frames`, then
  `PiSessionProcessRepository.frames`). The reply completes its request
  future, which resumes `_runTurn` within one microtask.
- So the reply overtook the event: `_runTurn` finished the compaction turn and
  reported the session idle while the row was still running. The bridge's
  idle sweep failed the row ("The turn ended before compaction finished."),
  and the late `compaction_end` then flipped the same part to completed.
- The same race caused the rejected-compaction symptoms. Pi writes
  `compaction_start`, `compaction_end` (with the error) and the failure reply
  together. The reply was handled before `compaction_start` accepted the
  command, so the send failed with HTTP 502, and `_finish(failed: true)`
  raised an empty session error beside the failure note. The app ignores a
  session error in the transcript; it only resets the feedback prompt's
  progress.

### Fix

- `_runTurn` yields one event-loop turn after the `compact` RPC returns or
  fails, so the frames read with the reply are handled first. This is the
  same `Future.delayed(Duration.zero)` barrier the other turn kinds already
  use.
- A compaction that Pi rejects after `compaction_start` finishes the turn
  without the session error, because its `compaction_end` already showed the
  failure note. Other command failures are unchanged.

### Evidence

Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`.

- Two `pi_plugin_impl_test.dart` tests write Pi's real frames as one stdout
  chunk. Both failed before the fix: the success test saw idle before the
  completed part, and the rejection test's send failed. Both pass after it.
  The rejection test replaces the old synthetic one, which sent a failure
  reply with no `compaction_end`, an order Pi never writes.
- `sesori_plugin_pi`: `dart analyze --fatal-infos` is clean, and 350 tests
  pass.
- Live, a source bridge on a dev slot with Pi 1.1.0 and a scratch-only
  `keepRecentTokens: 10` setting (removed afterwards):
  - two manual compactions each went running → `session.compacted` →
    completed → idle, with HTTP 200 and no failed state;
  - an immediate third `/compact` ("Already compacted") showed one failure
    note, then idle, with HTTP 200 and no `session.error`;
  - a reload returned the two completed rows and the failure note.

### Size

About 225 changed lines against the merge base: 21 of production code, 123
of tests, 12 of regression docs and the rest plan records. Nothing is
generated.
