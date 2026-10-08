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
