# Step 5 — Show Claude Compaction Live, With Its Outcome

Branch `compaction-progress/claude`. The Claude plugin, one `bridge/app`
capture test, and the R1 fix in `module_app_ui`'s message list. No wire or
database change: the plugin fills states and fields that steps 1–4 already
carry.

## Probe (Claude Code 2.1.291, the plan's probe version)

Two stream-json runs in a scratch directory, transcripts deleted afterwards.

- **Success** (`/compact` after one prompt), live order: `status compacting`,
  hooks, `status null` with `compact_result: "success"`, `init`,
  `commands_changed`, `compact_boundary` with `compact_metadata{trigger:
  "manual", pre_tokens: 24835, post_tokens: 6505, cumulative_dropped_tokens,
  duration_ms}`, the synthetic summary user frame, the replayed
  `<local-command-stdout>`, `result success`.
- **Failure** (`/compact` on an empty session): `status compacting`, `status
  null` with `compact_result: "failed"` and `compact_error: "Not enough
  messages to compact."`, `init`, a synthetic assistant frame (`model:
  "<synthetic>"`) repeating the error, `result success` (`is_error: false`). No
  boundary or summary follows.
- **Transcript.** The boundary record keeps the live boundary's uuid and
  carries camelCase `compactMetadata`. The `isCompactSummary` record's uuid and
  timestamp equal the live summary frame's. The `compacting` status is **not**
  persisted, so no start-time id survives (P10 option 1 is impossible). A
  failure leaves only the caveat, command and `local_command` stdout records,
  so its note is gone after a re-import (accepted risk Q6).

## Scope Delivered

- `ClaudeCompactMetadata` and `ClaudeCompactTrigger` in
  `models/claude_compact_metadata.dart`, with a snake_case stream parser and a
  camelCase transcript parser. They sit beside `ClaudeToolUseResult` rather than
  in `claude_stream_message.dart` (plan), because the transcript DTO reads them
  too.
- `ClaudeStatusMessage` carries `isCompacting`, `compactResult` and
  `compactError`; `ClaudeCompactBoundaryMessage` carries its metadata. The
  unused raw `status` string is gone.
- The transcript DTO gains `subtype` and `compactMetadata` (regenerated). The
  catalog maps `system`/`compact_boundary` to the new
  `ClaudeTranscriptCompactBoundaryRecord`; other system records keep the
  context path.
- `ClaudeContentMapper` is the only builder: running message, succeeded part,
  failed part and the completed message with details. It owns the
  `pre − post` rule (only when both exist and `pre > post`) and the trigger
  mapping (P7).
- `ClaudeHistoryMapper` passes the last boundary's metadata to the next
  summary record.
- `ClaudeEventDispatcher` replaces the summary flag with one
  `Map<String, _ClaudeCompaction>` of immutable sealed variants, dropped in
  `_resetTurn` and `_forgetRendered`.

## Refinements Against The Plan

- The plan's `started{messageId, metadata?}` is split into
  `_RunningCompaction{messageId}` (before the boundary) and
  `_CompactedCompaction{messageId, metadata?}` (after it). Only the frame right
  after a boundary is taken as the summary, as before this step; a user frame
  during compaction can no longer be mistaken for it.
- After a failure the CLI's synthetic assistant echo of `compact_error`
  renders nothing, so the error is not shown twice.

## P10 Decision

Option 2: the live row keeps the id minted from the first `compacting` frame;
history keys it by the summary record. The capture test
(`chat_history_capture_test.dart`) drives the real dispatcher, with a live
prompt neighbour whose id differs from its imported twin, and proves a replay
leaves one row, now under the history id.

The client check failed: `SessionDetailMessageList` treated the new id as an
arriving agent row, so while the list followed the bottom the row collapsed
and grew back over 200 ms on the refresh after a re-import. The user chose
the small app fix (R1, 2026-10-08): between two rows both builds share, as
many new rows as left there take their places and stay put; only the rest
ease in. A message-list test re-keys a prompt and an agent row in one
refresh (nothing eases, nothing moves), then appends a row (it eases in), and
fails without the fix.

## Evidence

Dart from Flutter 3.47.5-stable first on `PATH`.

- `sesori_plugin_claude`: `dart analyze --fatal-infos` no issues; `dart test`
  all passed. New or changed: one row from start through summary (same id,
  repeat ignored, success settle, details and summary time), failure note with
  the echo, boundary and summary suppressed, a new turn dropping a running
  entry, the no-start path with a trigger, and history details from a camelCase
  boundary record (DTO, catalog and history mapper together).
- `bridge/app`: `dart analyze --fatal-infos` no issues;
  `chat_history_capture_test.dart` all passed, including the P10 test.
- `module_app_ui`: `dart analyze --fatal-infos` no issues;
  `flutter test test/features/session_detail/` 425 passed.
- Docs: the Claude row of `docs/HARNESS_CAPABILITIES.md` (merged onto
  main's two-column table from steps 6–7, so the planned column split was
  not applied), `docs/regression/session-turns.md` (behavior, failure signal,
  known limitation) and `docs/regression/tools-and-file-changes.md` (a
  replacing row stays put).
- Architecture implementation review (one pass, `origin/main...HEAD`):
  approved, no findings.

## PR Reviews And Outcome

PR #1911 merged as `f4700fdc71` on 2026-10-08. It merged `origin/main` once
(`6c9e65ef2d`) before the R1 fix.

- **Wave 1 (`e3db6407f4`), Codex and cubic:** seven findings.
  - Fixed in `0431b8b0e0`:
    - `ClaudeCompactMetadata` is a Freezed model with a generated `fromJson`
      that reads both casings through `readValue`, replacing the two manual
      extractors (Codex P1 and cubic P3);
    - the capability intro names only the displayed trigger;
    - the Claude failure signal covers only successful-compaction details;
    - L2 Routine lists the Claude compaction coverage;
    - the known limitation says "no dedicated compaction record".
  - Declined: cubic P2 on the message list pairing any removal with a new
    row in the same gap. No current flow drops an unrelated row and appends
    a new one in the same gap, and the damage would be one row that does not
    ease in.
- **Wave 2 (`0431b8b0e0`):** clean.

## Size

1,054 changed lines against the merge base (982 added, 72 deleted): 230
generated Freezed and JSON output, about 414 of production code, 267 of
tests, 33 of docs and 110 of plan.

## Step 5b — One Row After A Reload

Branch `compaction-progress/claude-reimport-dedup`. Step 9's live run on
Claude Code found the failure signal P10 names: after a `/compact` and a
reload, two "Context compacted" rows (the history row and the live row), with
the same summary, details and time.

### Root Cause

`replaceSessionMessages` pairs a retained live row with an imported one by
content plus the nearest distinct neighbour on each side. A compaction row's
parts are hidden from that fingerprint, so its neighbours were its only
identity, and they never agree for Claude:

- live, the row follows the bridge's own `/compact` bubble (`sesori-user-N`),
  which the transcript never has;
- the transcript writes the boundary and summary records before the caveat,
  `<command-name>` and stdout records, and history drops all three.

So the live row's previous neighbour was the bubble, and the imported row's
was the reply before it. The step-5 test missed this because its live row
followed a prompt that history also has.

### Fix

`replaceSessionMessages` marks a row with only compaction parts and keys it by
its content alone, not its neighbours. The existing time rules still apply: a
lone pair matches at an equal (or unknown) time, and a group matches only at
equal times. Distinct compactions never share a time, so they never merge, and
a live failure note, stamped at its start, keeps its row. A first attempt made
every live-only row transparent to its neighbours instead; it changed an
unrelated, deliberately conservative tool-window test, so it was dropped for
this narrower rule.

### Evidence

Dart from Flutter 3.47.5-stable first on `PATH`.

- `bridge/app`: `dart analyze --fatal-infos` no issues; `dart test` all
  passed.
- New capture test: a synthetic transcript in Claude's real record order
  (prompt, reply, then for each round the boundary, summary, caveat, command
  and stdout records), read by the real catalog and history mapper; live, the
  same prompt and reply, a failed `/compact` round and two successful
  back-to-back rounds, each behind its own bridge bubble, through the real
  dispatcher. After the replay: both bubbles stay, each live row gives way to
  its own history row, and the failure note stays. Without the fix it fails
  with `start-1` and `start-2` still beside `summary-1` and `summary-2`.
- Live rerun, source-run bridge on slot 1 through the debug port: a new
  one-prompt Claude session, `/compact`, then two reloads. Before the reload
  the store held prompt, reply, the bubble and the minted row; each reload
  returned prompt, reply, bubble and one compaction row under the summary
  record's id.
- Docs: `docs/regression/session-history-and-recovery.md` (the replay rule)
  and `docs/regression/session-turns.md` (the Claude row and its L2 coverage).

No wire or database change.
