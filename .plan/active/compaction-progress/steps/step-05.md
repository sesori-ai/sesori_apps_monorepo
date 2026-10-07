# Step 5 — Show Claude Compaction Live, With Its Outcome

Branch `compaction-progress/claude`. Claude plugin only, plus one `bridge/app`
capture test. No wire or database change: the plugin fills states and fields
that steps 1–4 already carry.

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

The client check failed: `SessionDetailMessageList` treats the new id as an
arriving agent row, so while the list follows the bottom the row collapses
and grows back over 200 ms on the refresh after a re-import. Per P10 this
needs the user's decision before shipping.

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
- Docs: `docs/HARNESS_CAPABILITIES.md` (column split, Claude cells, re-key
  note) and `docs/regression/session-turns.md` (behavior, failure signal,
  known limitation).
