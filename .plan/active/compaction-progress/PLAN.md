# Compaction Progress: Show Context Compaction While It Runs

## Status

- **Plan slug:** `compaction-progress`
- **Created:** 2026-10-06
- **Origin:** the user's review page `compaction-progress.html` (round 2,
  questions C1–C7, the per-harness "today vs after" table, the Claude event
  timeline and the mockups). The page stays local. Every C decision is final
  and recorded under [Decisions](#decisions).
- **Series:** nine PRs with fixed titles in
  [TRACKER](TRACKER.md#fixed-pr-titles). Phase 1 (steps 2–5: the sweep-rule
  refactor, wire and bridge, app, Claude) is detailed below. Phase 2 (steps
  6–7: OpenCode, then Pi, Codex and DeepSeek) is rough intent. The step-6 PR
  details steps 6–7 in this file before it changes code. Steps 8–9 reconcile
  the docs and retire the plan.
- **Renumbered 2026-10-07:** the user approved the sweep-rule refactor (Q4) as
  its own PR before the wire contract, so it became step 2 and every later
  step moved up by one.
- **Approval scope:** this plan PR approves the phase-1 architecture only.
  Phase 2 is approved as intent. Its file and class ownership, lifecycle and
  data flow are designed in the step-6 PR, which runs
  `architecture-plan-review` on that section before any phase-2 code.
- **Supersedes** the "Compaction running row" bullet under step-timers'
  later phases (`.plan/active/step-timers/PLAN.md`). That plan's retirement
  must not reopen it.

## Goal

While a harness compacts its context, Sesori mostly shows "Working…" until a
still "Context compacted" row appears, so a long compaction looks stuck. After
this plan:

- A live row reads "Compacting context · 1m 42s", with the Thinking sparkle
  and shimmer and a ticking timer, wherever the harness reports a start.
- Where the harness streams the summary (today only OpenCode), its newest
  words stream under the row, the way they do under Thinking.
- On success the row settles in place into "Context compacted", with
  "· freed 142k tokens · auto" when the harness reports those facts. Nothing
  jumps.
- A failure leaves a quiet "Compaction failed" note with the error, kept in
  the transcript.
- Harnesses with no signal keep "Working…", and the gaps are recorded in
  `docs/HARNESS_CAPABILITIES.md`.

## Current Behavior (origin/main at 29ec03077c, 2026-10-06)

### Wire and bridge

- `MessagePart.compaction` (`shared/sesori_shared/lib/src/models/sesori/message_part.dart:216-228`)
  carries `id`, `sessionID`, `messageID` and a nullable `summary`. The
  `summary` field arrived after v1.9.0 (#1700). In v1.9.0 the part has no
  fields at all.
- `MessagePart` has no `fallbackUnion`, so a new part `type` breaks a v1.9.0
  app: history decoding fails, and the SSE event is dropped. Unknown JSON keys
  are ignored, because nothing sets `disallowUnrecognizedKeys`.
- The plugin mirror is `PluginMessagePart.compaction`
  (`bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart:148-157`).
  It is mapped 1:1 in `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart:193`.
- Parts are stored as JSON text (`history_parts.partJson`), so new fields
  need no Drift migration.
- `ChatHistoryRepository.finalizeOpenToolParts` (`chat_history_repository.dart:381-426`)
  runs when a turn goes idle (`orchestrator.dart:1671-1682`) and on reads
  while the session is not busy (`chat_history_service.dart:630-662`). It
  rewrites stranded pending or running `tool` parts to `error` and `subtask`
  parts to `cancelled`. It does not touch compaction parts.
- History re-import (`replaceSessionMessages`, `:473-679`) keeps live-captured
  rows that the backend snapshot lacks for one more import. It matches rows
  across different ids by semantic fingerprint. Compaction parts are left out
  of that fingerprint (`_isTranscriptVisiblePart`, `:1120`). A message that
  holds only a compaction part is therefore matched on its info and its
  neighbours, and only when the creation times are equal or one is missing.

### Client

- `CompactionPartWidget` (`client/module_app_ui/lib/src/features/session_detail/widgets/compaction_part_widget.dart`)
  always shows a fold icon and "Context compacted". Tapping it opens the
  summary modal; without a summary the row is inert.
- `TranscriptBuilder` treats compaction as a parts block, not a step, so it
  never becomes `transcript.liveStep`.
- `TranscriptActivityBuilder.build` (`client/module_core/lib/src/cubits/session_detail/transcript_activity.dart:57-73`)
  hides "Working…" when the session is not busy, on a retry error, while any
  text streams (`hasStreamingText`), or while a step is live.
- `_onPartDelta` buffers deltas for any part id, compaction included. Because
  `_streamedText` has no base text for compaction, that buffer is cleared
  only by the next `part.updated` for the part.
- The Thinking row is `ReasoningPartCard` (`reasoning_part_card.dart`). It
  uses `TranscriptStepRow` with a live shimmer label and a `_LatestWords`
  strip (the last 160 characters, faded at the leading edge) inside a
  `TranscriptPresenceColumn`. That column provides the 200 ms ease-out fold
  (`transcript_motion.dart`).
- `TranscriptElapsedTime` and `TranscriptDurationFormatter` tick
  "Working… · 1m 02s" from a harness or bridge timestamp. The client never
  starts its own clock.
- `assistant_message_card.dart:79-93` has a dead `MessagePartCompaction() => false`
  case.
- A v1.9.0 app renders compaction parts as nothing.

### Per-harness facts (code, plus the live Claude probe)

**Claude (CLI 2.1.291 probe).**

- Signals, in order:
  - `system/status status:"compacting"` at +5 ms, re-sent every 30 s;
  - `status:null` with `compact_result:"success"|"failed"` and an optional
    `compact_error`;
  - `system/init`;
  - `system/compact_boundary` with
    `compact_metadata{trigger, pre_tokens, post_tokens, duration_ms, …}`;
  - a synthetic user summary frame, the replayed `<local-command-stdout>`,
    and `result` with `local_command:"compact"`.

  The summary is not streamed.
- Today:
  - status is parsed (`claude_stream_message.dart:52-57`, with no
    `compact_result` or `compact_error` fields) and dropped
    (`claude_event_dispatcher.dart:203-215`);
  - the boundary only sets `_awaitingCompactionSummary` (`:442-445`);
  - the summary frame becomes its own message, id = frame uuid, part
    `"$uuid-compaction"` (`:452-468`, `claude_content_mapper.dart:268-299`);
  - history builds the same row from the `isCompactSummary` record;
  - the transcript's boundary record carries the camelCase
    `compactMetadata{trigger, preTokens, postTokens, …}`, unparsed;
  - a failure shows nothing.

**OpenCode v1.**

- Signals: the summary assistant message (`summary: true`) streams text
  parts, and `session.compacted` arrives at the end.
- Today: each summary text part maps to a compaction part with the same ids
  (`message_part_mapper.dart:58-66`), so a still "Context compacted" row
  shows at once. Its deltas reach the client invisibly and hide "Working…"
  (the #1700 regression, unreleased: the v1.9.0 bridge still sent the summary
  as visible text). The user marker `CompactionPart.auto` is dropped.

**OpenCode v2.**

- Signals: `session.compaction.started/delta/ended/failed`. The snapshots
  `SessionMessageCompactionRunning/Completed/Failed` carry `reason`
  (auto/manual) and `time.created`.
- Today: running maps to no parts (`v2_message_mapper.dart:181-184`).
  Completed maps to a compaction part with id `partId(messageId, 0)`. Failed
  maps to an error message. Deltas are dropped (`opencode_v2_service.dart:455`).

**Codex.**

- Signals: `item/started` and `item/completed` with `contextCompaction`. No
  status, tokens, trigger or summary.
- Today: a running untitled `compact` tool part `"$itemId-tool"`, replaced
  in place by the compaction part (`codex_event_mapper.dart:557-584`). There
  is no failure handling: a missing completion leaves the tool running until
  the idle sweep marks it errored. History ids are `codex-compaction-N`.

**Pi.**

- Signals: `compaction_start{reason}` and
  `compaction_end{reason, aborted, willRetry, errorMessage, result{summary, tokensBefore}}`.
  Reasons are `manual|threshold|overflow`.
- Today: a running `compact` tool part on a reserved compaction message,
  replaced in place on success (`pi_event_dispatcher.dart:641-700`). On
  failure or abort the message is removed and a session error raised.
  `willRetry` keeps the row.

**DeepSeek.**

- Signals: `deepseek/session/status` with
  `kind: compaction_started|compaction_completed`. No ids, tokens, trigger or
  failure kind.
- Today: the start is dropped, and the completion becomes only
  `BridgeSseSessionCompacted` (`deepseek_event_mapper.dart:145-147`). No row,
  live or in history.

**Antigravity, Copilot, Cursor, Hermes, OMP, Grok.** No compaction signal on
the consumed ACP seam. "Working…" only.

## Decisions

### User decisions (final, 2026-10-06; do not reopen)

- **C1** Build now as a standalone series (originally "3–4 PRs"; split into
  five implementation PRs here under the clean-split rule, plus the sweep-rule
  refactor the user approved on 2026-10-07).
- **C2** An elapsed timer on the live row: "Compacting context · 1m 42s".
- **C3** A streamed-words strip where the harness streams the summary (today
  only OpenCode v1 and v2).
- **C4** Apps at v1.9.0 or older that talk to a newer bridge keep showing
  "Working…". There is no legacy fallback. On Pi and Codex they also lose
  today's running `compact` tool card once step 7 lands, which is the fallback
  C4 option B offered and the user declined (confirmed in Q3). On OpenCode the
  old app shows less than "Working…"; see [Compatibility](#compatibility) and
  Q5.
- **C5** A failure is a quiet "Compaction failed" note that carries the error
  and stays in the transcript.
- **C6** A live row where a start exists and nothing where there is no
  signal. The gaps go in `docs/HARNESS_CAPABILITIES.md`.
- **C7** The finished row shows "Context compacted · freed 142k tokens ·
  auto" when the harness reports it, otherwise "Context compacted".
- **Design point (review page).** Running, completed and failed live on the
  existing compaction part, and the field defaults to completed. There is no
  new session status (`PluginSessionStatus` stays idle/busy/retry) and no new
  part type.

### Planning decisions (from code evidence)

- **P1 — One nested sealed state on the existing part.** `MessagePart.compaction`
  gains `CompactionState state`, a sealed union keyed by `status`:
  `running{summary?}`, `completed{summary?, freedTokens?, trigger?}` and
  `failed{error?}`. Each variant carries only its own data (AGENTS: make
  impossible states unrepresentable), so `error` cannot sit on a success and
  `freedTokens` cannot sit on a running row. The top-level `summary` moves
  into the variants. It reached no public release (v1.9.0 has no fields), so
  it moves without compatibility code. The part `type` stays `"compaction"`,
  and a v1.9.0 app ignores the new keys.
- **P2 — An honest default.** `@Default(CompactionState.completed(summary: null, freedTokens: null, trigger: null))`,
  with a dated COMPATIBILITY comment. Every released bridge sends compaction
  parts only for finished compactions, with no details.
- **P3 — Forward tolerance at the cost of one annotation.** `CompactionState`
  declares `fallbackUnion: "completed"`, so a status added later reads as a
  finished compaction with no details instead of failing the whole history
  decode. That failure is exactly the v1.9.0 hazard noted above.
  `CompactionTrigger` (`manual`, `auto`) decodes unknown values as null.
- **P4 — The timer counts from the compaction message's `time.created`.**
  Every harness already puts its compaction part in its own message: Claude's
  summary message, Codex's item message, Pi's reserved compaction message,
  OpenCode's summary or compaction message, and DeepSeek's new one. So the
  running row needs no time field. Where the harness gives no time, the
  plugin stamps the instant it saw the start, as ACP prompt stamps already do.
  The client never starts its own clock (step-timers rule).
- **P5 — Streamed text reuses the delta pipeline.** A running part's
  `summary` is the text so far. `_streamedText` returns it as the base text, so
  `message.part.delta` events for the part id extend it exactly as they do
  for reasoning, and the existing buffer retirement works. There is no new
  event and no new buffer. Only `running` is streamable. A completed or
  failed part has no streamed text, so on settle `_onPartUpdated`'s
  `removePart` clears the buffer, as today. Step 4 must not make `completed`
  streamable, because that would change the retirement rule.
- **P6 — Stranded running compactions are finalized by the existing idle and
  read sweep.** The sweep also rewrites a stored compaction part whose
  `state.status` is `running` to `failed`, with the bridge-authored error
  "The turn ended before compaction finished." That matches the tool sweep's
  wording and owner. Without it a process death or a Stop mid-compaction
  would leave a row ticking forever. The user chose this outcome (Q2). After
  step 2 the rule is one typed method, `ChatHistoryService._endUnfinishedPart`,
  and the repository's `rewriteStoredParts` only persists what it returns.
  Step 3 adds the compaction case to that method. The service's prefilter
  statuses (`pending`, `running`) already admit the nested
  `"status":"running"` key. The read path's check,
  `_containsUnfinishedPart`, applies the same method, so it admits a running
  compaction with no change of its own. That matters: a bridge that died
  before idle would otherwise never sweep a transcript whose only open part
  is the compaction.
- **P7 — Only the plugin interprets backend facts.** Each plugin computes
  `freedTokens` (`pre − post`, only when both exist and `pre > post`) and
  maps its own trigger vocabulary to `manual`/`auto`. Pi `threshold` and
  `overflow` map to `auto`. Shared code and the client never see backend
  names.
- **P8 — "Working…" yields to the live compaction row.**
  `TranscriptActivityBuilder` already receives `messages`, so it derives
  "a compaction part is running" there with a private helper. `Transcript`
  is unchanged, because nothing else reads that fact. The builder returns
  idle for a running compaction, as it does for `liveStep`, and the
  sub-agents branch counts it as the main agent's own work. When the row
  settles, "Working…" returns while the turn continues.
- **P9 — The row settles in place.** The widget stays keyed by part id. The
  leading icon cross-fades from sparkle to fold (or alert) through an
  `AnimatedSwitcher` (`transcriptMotionDuration`). The label stops
  shimmering, and the strip folds away inside `TranscriptPresenceColumn`.
  Reduced motion makes it instant. The settled and failed rows keep the
  live row's one-line height, so nothing below moves except the strip folding.
- **P10 — Claude's live row reuses one message id from start to finish.**
  The running row's message id is minted from the first `compacting` status
  frame's uuid, because the summary frame's uuid is unknown at the start.
  Success settles that same part. When the summary frame arrives, the plugin
  re-emits that message, built by the same `compactionMessage` builder as the
  history row, with `time.created` set to the summary frame's timestamp, and
  the completed part with the summary and the details.

  The id after a history re-import, decided by the step-5 probe and capture
  test, in this order:

  1. **Same id on both paths.** If the transcript persists something the live
     start also sees (for example the `compacting` status record, or a uuid
     the summary record links back to), the history mapper keys the row by
     it, and a re-import keeps the live id. The capture test asserts the
     same message and part id before and after the re-import.
  2. **One re-key on a later refresh.** Otherwise history keeps today's id
     (the summary record's uuid). `replaceSessionMessages` pairs the minted
     row with it through the semantic fingerprint (same info, same
     neighbours, equal creation time) and drops the minted row, so one row
     remains, now under the history id. An open session sees that only on a
     refresh after a re-import, as a settled row with identical content
     changing key at the same index. Step 5 checks that the message list
     shows this without a visible insert. If so, the swap is accepted and
     recorded; the capture test asserts one row and the id change. The test
     includes a previous neighbour that is a live prompt row whose id differs
     from its imported twin.
  3. **Fallback, only with the user's approval.** If the matcher cannot pair
     the rows, or the list animates the re-key, step 5 stops and asks the
     user before shipping the alternative: `message.removed` for the minted
     row and then today's summary row when the summary frame arrives, a
     Claude-only swap without the cross-fade.

  A re-import that leaves two rows, or a visible re-insert, is one of this
  plan's failure signals.
- **P11 — A failure note keeps one line.** The error is a single ellipsized
  line in the row's detail. The full error is in the row's semantics label.
  There is no modal and no Retry (C5 declined Retry).
- **P12 — Token count formatting.** A small pure formatter beside
  `TranscriptDurationFormatter` writes "940", "142k" and "1.2M", matching
  the approved mockup copy.

## Explicitly Excluded

- A new session status, a new part type, or a legacy row for older apps (C4).
- A Retry action on the failed note (C5).
- Client-side clocks for the timer (P4).
- Codex freed tokens from diffing `thread/tokenUsage/updated`, Codex trigger
  correlation with `thread/compact/start`. Each needs new correlation state
  for a detail line, so these stay recorded gaps. (OpenCode v1's
  `CompactionPart.auto` is reported, so step 6 carries it; see Phase 2.)
- A duration on the settled row. C2 covers only the live row.
- Rows for the six harnesses without a signal (C6).
- Analytics: compaction is harness behavior, not a user action, and answers
  no product question.

## Architecture

### 1. The stranded-step rule moves into the history service (step 2)

A refactor of pre-existing code with no behavior change, approved by the user
as Q4. It moves the rule that decides how unfinished steps end out of
Layer 2 and into `ChatHistoryService`, where the other history decisions
live.

- `ChatHistoryService` owns the rule as one typed method,
  `_endUnfinishedPart`: a `pending` or `running` tool part ends as an error
  with "The turn ended before this tool reported a result.", and a subtask
  with an open `taskState` ends as cancelled. The idle sweep
  (`finalizeOpenToolParts`, whose name stays to spare the orchestrator), the
  read-path sweep and the read-path check `_containsUnfinishedPart` all apply
  it, so the check and the sweep cannot disagree.
- `ChatHistoryRepository.finalizeOpenToolParts` becomes
  `rewriteStoredParts`. It is persistence only: one read-modify-write pass
  that prefilters rows by the caller's statuses, decodes each candidate,
  writes the replacement the caller returns, and keeps the row's spilled
  attachment references, which a decode cannot carry.
- The existing service-level sweep tests stay unchanged in meaning. One test
  is added: a finalized part keeps its stored image attachment.

### 2. Wire contract and bridge core (step 3)

`shared/sesori_shared/lib/src/models/sesori/message_part.dart`:

```dart
@JsonEnum()
enum CompactionTrigger() { manual, auto }

/// How far one context compaction got.
@Freezed(unionKey: "status", fallbackUnion: "completed", fromJson: true, toJson: true)
sealed class CompactionState with _$CompactionState {
  /// Compacting now. [summary] is the text written so far, when the harness streams it.
  @FreezedUnionValue("running")
  const factory running({required String? summary}) = CompactionStateRunning;

  @FreezedUnionValue("completed")
  const factory completed({
    required String? summary,
    required int? freedTokens,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) required CompactionTrigger? trigger,
  }) = CompactionStateCompleted;

  @FreezedUnionValue("failed")
  const factory failed({required String? error}) = CompactionStateFailed;
}

// in MessagePart:
const factory compaction({
  required String id,
  required String sessionID,
  required String messageID,
  // COMPATIBILITY 2026-10-06 (v1.9.1): Released bridges send compaction parts only for finished
  // compactions and without a state. Remove @Default and require state when the minimum supported
  // bridge always sends it.
  @Default(CompactionState.completed(summary: null, freedTokens: null, trigger: null)) CompactionState state,
}) = MessagePartCompaction;
```

- The plugin interface mirrors this as `PluginCompactionState` and
  `PluginCompactionTrigger`. `PluginMessagePart.compaction` takes
  `required PluginCompactionState compactionState`, named apart from the
  tool-only `PluginMessagePart.state` accessor as `taskState` is (a field
  named `state` would be an invalid override). Plugins update in lockstep: every
  existing emitter (Claude live and history, OpenCode v1 live and REST,
  OpenCode v2, Codex live and rollout, Pi live and history) emits
  `completed(summary: <today's summary>, freedTokens: null, trigger: null)`.
  Step 3 changes no plugin behavior.
- `plugin_to_shared_mapping.dart` maps the state 1:1.
- `ChatHistoryService._endUnfinishedPart` gains the compaction case of P6,
  and the service's sweep doc comments name compaction.
  `_containsUnfinishedPart` applies the same method, so the read path sweeps
  a running compaction with no separate change.
- Client in step 3: `CompactionPartWidget` reads the summary from
  `CompactionStateCompleted`. Running and failed render as nothing until
  step 4, and no plugin emits them before step 5. Remove the dead
  `assistant_message_card.dart` case.

### 3. App (step 4)

- `module_core`:
  - `TranscriptActivityBuilder` adds the rule from P8, derived from
    `messages`.
  - `session_detail_resolvers` and `_streamedText` return a running part's
    `summary` as base text (P5).
- `module_app_ui`, inside `CompactionPartWidget`:
  - It takes `state`, `sinceMs` (the message's `time.created`, passed from
    `SessionDetailMessageList` through both card paths, `AssistantMessageCard`
    and `SystemMessageCard`) and `streamingText` (the buffered text for the
    part, or null).
  - Running: `TranscriptStepRow` with `TranscriptLiveSparkle`, a live label
    "Compacting context", and `TranscriptElapsedTime` as detail (none when
    `sinceMs` is null). Under it is the latest-words strip when text exists.
  - Completed: the fold icon, "Context compacted", and the details as
    " · freed 142k tokens · auto". Tapping opens the summary as today.
  - Failed: an alert icon in `textSecondary` (quiet, not red), "Compaction
    failed", and the error as a one-line detail (P11). The row is inert.
  - Transition: P9.
- Extract `_LatestWords` and `ReasoningPartCard.latestWords` into one shared
  `TranscriptLatestWords` widget used by both rows. This is a short
  extraction of logic the change would otherwise duplicate.
- Add `TranscriptTokenCountFormatter` (P12).
- New `app_en.arb` strings are in [Approved Copy](#approved-copy). Generated
  localization files ship with them.
- Phone and desktop share `SessionDetailMessageList`, so both get the row.

### 4. Claude (step 5)

Layers (all under `bridge/sesori_plugin_claude/lib/src/`):

- **API models.**
  - `api/models/claude_stream_message.dart`: `ClaudeStatusMessage` gains
    `compactResult` and `compactError`. `compactResult` is a plugin-private
    enum `success`/`failed`, null when absent or unknown.
  - The same file gains `ClaudeCompactMetadata{trigger?, preTokens?, postTokens?}`.
    `trigger` is a plugin-private `manual`/`auto` enum, null when unknown.
    The model has two parse factories, one for the stream's snake_case
    `compact_metadata` and one for the transcript's camelCase
    `compactMetadata`.
  - `ClaudeCompactBoundaryMessage` carries `ClaudeCompactMetadata?`.
  - `api/models/claude_transcript_record_dto.dart` gains `subtype` and the
    camelCase `compactMetadata` for `type: "system"` records.
- **Repository records.**
  - `repositories/models/claude_transcript_record.dart` gains a
    `ClaudeTranscriptCompactBoundaryRecord{metadata}` variant.
  - `repositories/claude_transcript_catalog_repository.dart` maps
    `subtype: "compact_boundary"` records to that variant. Other system
    records keep today's context-record path.
- **The one part builder.** `repositories/mappers/claude_content_mapper.dart`
  is the only class that builds Claude compaction messages, parts and
  states. It owns the `pre − post` rule and the trigger mapping (P7):
  - `compactionMessage` gains a `ClaudeCompactMetadata?` input and builds
    the completed state;
  - small sibling builders return the running and failed parts.

  The dispatcher and `claude_history_mapper.dart` only sequence calls to it.
- **History.** `claude_history_mapper.dart` holds the last
  `ClaudeTranscriptCompactBoundaryRecord`'s metadata and passes it to
  `compactionMessage` for the next `isCompactSummary` record, so the
  details survive a reload.
- **Dispatcher:**
  - Replace `_awaitingCompactionSummary: Set<String>` with one
    `Map<String, _ClaudeCompaction>`. `_ClaudeCompaction` is a small
    plugin-private sealed type with immutable variants:
    `started{messageId, metadata?}`, `failed` and `unstarted{metadata?}`.
  - The first `compacting` status with no entry emits the running message
    and part (P10) and stores `started`. The message is stamped now, and the
    part id is `"$messageId-compaction"`. Repeats every 30 s do nothing.
  - `compact_result: failed` emits `failed(error: compactError)` on the
    running part and stores `failed`. A boundary or summary frame that
    follows a `failed` entry emits nothing, so no completed row appears
    beside the failure note. The step-5 probe records whether the CLI sends
    either after a failure.
  - `compact_result: success` emits `completed` on the running part at once,
    so the settle happens when compaction actually ends.
  - The boundary adds its metadata to a `started` entry. With no entry it
    stores `unstarted`, so an older CLI keeps today's path.
  - The summary frame consumes a `started` or `unstarted` entry. `started`
    re-emits that message (P10) and the completed part with the summary,
    `freedTokens` and `trigger`. `unstarted` emits today's summary row plus
    the details.
  - Every entry, `failed` included, is dropped in `_resetTurn` (turn begin
    and completion, so also after a process exit without `result`) and in
    `_forgetRendered`, so a stale state never reaches the next
    compaction.
  - Rewrite the comment at `claude_event_dispatcher.dart:451-452` ("live and
    replayed rows share one message id"). It no longer holds when a start
    was seen, and the comment must say which path P10's capture test chose.
- Probe in step 5, recorded in `steps/step-05.md` and the capability doc:
  how to force `compact_result: "failed"` (for example `/compact` on an
  almost empty session), whether a failure leaves a transcript record or is
  followed by a boundary or summary frame, whether the live summary frame
  timestamp equals the transcript record's, and which start-time uuid, if
  any, the transcript persists (P10 option 1).

### 5. Phase 2 (steps 6–7, rough; detailed by the step-6 PR)

- **OpenCode v1.** The summary message's compaction part becomes running
  until the message completes, then completed. This fixes the #1700 early
  row, and "Working…" returns after the settle. Deltas already reach the
  client (P5), and the summary tracker already knows the summary message
  ids. A summary message with an error becomes `failed`. The user marker's
  `CompactionPart.auto` maps to the trigger (C7); step 6 picks the smallest
  plugin-owned link from marker to summary message.
- **OpenCode v2.** Running snapshots map to a running part with
  `partId(messageId, 0)` and the partial summary.
  `session.compaction.delta` becomes a part delta on that part, which needs
  one per-session map of the running part id. The map goes in a dedicated
  `Tracker`, following the `ActiveSessionTracker` and Claude `trackers/`
  pattern, not in the service. Failed snapshots become a
  `failed` part instead of today's error message. `reason` maps to the
  trigger.
- **Pi.** `compaction_start` emits a running compaction part instead of the
  `compact` tool part, on the same reserved message. `compaction_end`
  success emits `completed` with the trigger from `reason`. Failure emits
  `failed(errorMessage)` and no longer removes the row or raises a session
  error (C5). `willRetry` keeps the row running. Per Q2, an abort or a
  process exit no longer removes the row: it ends as the quiet failed note.
  Parse `tokensBefore` only if a freed count becomes
  derivable. Today it is not, because Pi reports no after-count.
- **Codex.** `item/started` emits a running compaction part instead of the
  `compact` tool part, with the same ids. `item/completed` emits
  `completed`. A missing completion is finalized by the P6 sweep.
- **DeepSeek.** Map `compaction_started` to a running part on a synthetic
  message. One per-session map holds the running id, in a dedicated
  `Tracker` beside `DeepSeekDelegationTracker`, not in the mapper. Map `compaction_completed`
  to `completed`. A warning or turn end mid-compaction is left to the P6
  sweep. The rows are live-only (C6), and a history re-import drops them
  after one more import.
- **Cleanup** in these steps: Pi's `mapRunningCompaction` tool mapping and
  its failure-path session error, and Codex's running `compact` tool part.

## Approved Copy

| Key | English |
|---|---|
| `sessionDetailCompactingContext` | Compacting context |
| `sessionDetailCompactionFailed` | Compaction failed |
| `sessionDetailCompactionFreedTokens` | freed {tokens} tokens |
| `sessionDetailCompactionAuto` | auto |
| (existing) `sessionDetailContextCompacted` | Context compacted |
| (bridge sweep error) | The turn ended before compaction finished. |

Separators are " · ", as on the Working row. Only "auto" is labelled (Q1): a
manual compaction shows no trigger word, so there is no "manual" string.

## Compatibility

- **v1.9.0 app with a new bridge.** It ignores `state` and renders compaction
  parts as nothing, so it keeps "Working…" during compaction (C4). The part
  type is unchanged, so nothing fails to decode.
- **Exception: OpenCode on a v1.9.0 app.** The v1.9.0 app buffers deltas for
  every part id, and any buffered text hides "Working…". The streamed
  summary deltas (v1 today on `main`, v2 from step 6) therefore leave such an
  app with neither "Working…" nor a row while the summary streams. The rows
  appear normally afterwards. With the released v1.9.0 bridge the summary was
  plain visible text, so this is the unreleased #1700 regression carried
  forward for old apps only. The user accepted it with no old-app code (Q5),
  and step 6 records it in `tools-and-file-changes.md`.
- **New app with a v1.9.0 bridge.** The missing `state` decodes as completed
  with no details (P2), which is the honest meaning of every released part.
- **New app with a later bridge that adds a status:** P3.
- No database migration and no wire field removal of released data.

## Security And Privacy

The summary and the failure error can contain user content. They travel the
same encrypted path as today's summary. Local bridge logs keep the Claude
`compact_error` and Pi `errorMessage` text, since that is diagnostic and
user-chosen to share (AGENTS logging rule). Nothing goes to analytics.

## Complexity Budget

New mutable parts, each justified:

| Part | Where | Why |
|---|---|---|
| `Map<String, _ClaudeCompaction>` (a) | Claude dispatcher | Running id and outcome until `result` |
| Per-session running-part-id map | OpenCode v2 tracker (step 6) | Deltas carry only `sessionID` |
| Per-session running-message-id map | DeepSeek tracker (step 7) | No ids on status notifications |
| One `Timer` per visible live row | `TranscriptElapsedTime` | Reused, not new |

(a) It replaces the existing `Set<String>`, so the map count is unchanged.

Not added: a session status, a part type, a client clock, a bridge-side
correlation of compaction across messages, Codex token diffing, an old-app
fallback, or new persistence columns. The sweep extends an existing pass.
The coordination is smaller than the feature: one map per plugin that lacks
ids.

## Cleanup Assessment

- Step 2: `ChatHistoryRepository.finalizeOpenToolParts` and the separate
  open-part predicate `_containsOpenToolPart` are replaced by the service's
  one rule and the repository's `rewriteStoredParts`.
- Step 3: the top-level `summary` field and its compatibility comment move
  into `completed`. The dead `MessagePartCompaction() => false` case in
  `assistant_message_card.dart` is removed.
- Step 4: `_LatestWords` and `ReasoningPartCard.latestWords` become one shared
  widget.
- Steps 6–7: the running `compact` tool parts in Pi and Codex, Pi's
  failure-path `BridgeSseMessageRemoved` and `BridgeSseSessionError`, and
  OpenCode v2's failed-compaction error message are all replaced, and their
  tests are updated.
- Docs: the "older client … loses its finished `compact` tool card" lines in
  `tools-and-file-changes.md` are rewritten when step 7 lands.
- Kept: `BridgeSseSessionCompacted` and its SSE event. It still has bridge
  consumers (push routing), and removing it is unrelated to this feature.

## Proportionality And Accepted Risk

- **Observed failures addressed:** Claude's dropped start and silent failure
  (live probe). The OpenCode v1 #1700 regression (code). DeepSeek's missing
  row (code).
- **Ordinary flows guarded:** process death or Stop mid-compaction (P6), which
  reuses the tool sweep.
- **Accepted, no machinery:**
  - Claude, Pi, Codex and DeepSeek failure notes and DeepSeek rows that the
    harness's own history lacks survive one bridge history re-import and
    then disappear (accepted by the user, Q6).
  - A failed Claude compaction may leave no transcript trace (the step-5
    probe records it).
  - A v1.9.0 app on Pi or Codex loses the running `compact` card (C4,
    accepted by the user, Q3).
  - A v1.9.0 app on OpenCode shows no activity while the summary streams
    (accepted by the user, Q5).
  - If two Claude compactions somehow share neighbours, the P10 re-import
    match may keep both rows for one import.
  - Under P10 option 2, a Claude row changes id once on a refresh after a
    re-import.
- **Evidence level:** the Claude event order comes from one live probe on CLI
  2.1.291. Step 5 repeats it on the current CLI before relying on it.

## Regression Coverage

Each implementation step updates the documents for the behavior it ships.

- **Step 2:** none. It changes no behavior, and no regression document names
  the sweep's owner.
- **Step 3:**
  - `tools-and-file-changes.md`: the compatibility lines (older clients
    ignore the state; a missing state reads as finished);
  - `session-history-and-recovery.md`: the idle and read sweep finalizes a
    running compaction as failed.
- **Step 4:** `tools-and-file-changes.md`: the live row, the timer, the
  strip, the settle in place, the failed note, the details and the
  "Working…" rule, with failure signals.
- **Step 5:**
  - `docs/HARNESS_CAPABILITIES.md` "Context compaction row": split into Live
    row, Failure note, Details (freed tokens, trigger) and Summary columns,
    and fill in Claude with the probe version;
  - `session-turns.md`: Claude's compaction lines.
- **Step 6:** the capability rows for OpenCode v1 and v2 (strip, trigger),
  the OpenCode lines in `session-turns.md`, and the OpenCode old-app line
  in `tools-and-file-changes.md` (Q5).
- **Step 7:**
  - the capability rows for Pi, Codex and DeepSeek;
  - the Pi and Codex running-`compact`-card lines in `session-turns.md` and
    `tools-and-file-changes.md`;
  - the DeepSeek compaction line in `session-turns.md`.
- **Step 8:** reconcile every document with what shipped.

Failure signals, added by the step that ships the behavior:

- a live row without a timer where the harness has a start;
- a timer that restarts on reopen;
- "Working…" shown together with the live row;
- the row jumping, flashing or re-inserting when it settles;
- two compaction rows after reload;
- a running row that outlives its turn;
- a failure with no note, or a red alert;
- the strip on a harness that streams nothing.

**Highest level: L4 Extended, plus one L5 compatibility cell.** The boundary
is client end to end with live plugins, because the row depends on each
harness's events and the motion must be seen on a device.

Required matrix, recorded now. Any reduction needs the user's acceptance in
this file before retirement.

- **iOS phone, real device (release target):** live row ticking, settle in
  place with no jump (a recording), details, failed note, VoiceOver reading
  the row once rather than every second, and one settled row after reload.
- **macOS desktop:** the same rows and the settle.
- **Android phone:** smoke of the live row and the settle.
- **Claude Code:** a manual `/compact` and one automatic compaction: live
  row, settle with freed tokens and trigger, details after reload, one row
  after a history re-import, a forced failure note, and Stop
  mid-compaction leaving the swept failed note.
- **OpenCode v1:** live row with strip, "Working…" back after the settle,
  summary modal.
- **OpenCode v2:** live row with strip from deltas, settle, failure note
  when reproducible.
- **Codex:** live row and settle, and Stop mid-compaction leaving the swept
  note.
- **Pi:** manual and threshold compaction, the failure note, and a
  `willRetry` row staying live.
- **DeepSeek:** live row and settle, live only. Record the reload gap.
- **One ACP harness without a signal:** plain "Working…".
- **v1.9.0 App Store app with the new bridge (L5):** "Working…" during a
  Claude, Codex or Pi compaction, nothing while an OpenCode summary streams
  (Q5), no decode failure, and the transcript loads after reload.

Automated coverage in the steps:

- shared decode and encode, including the default and the fallback;
- plugin event mapping;
- the sweep;
- the re-import match (P10);
- builder and activity rules;
- widget states and the settle transition with a fake clock.

## Delivery Rules

- **Order.** 2 → 3 → 4 → 5. Steps 6 and 7 need 4 and may run beside 5. Each
  needs only step 3's contract and step 4's rendering. Step 8 needs 2–7, and
  step 9 needs 8.
- **The step-6 PR first details steps 6–7 in this file** (code-informed, like
  phase 1), runs `architecture-plan-review` on that section, then implements
  step 6.
- **Questions:** all answered by the user on 2026-10-07; see
  [Answered Questions](#answered-questions).
- **Coordination:** the `step-timers` plan also edits `transcript_activity.dart`
  and `app_en.arb`. Rebase on whichever lands first; the conflicts are
  textual.
- **Per-step evidence** goes in `steps/step-NN.md`, written by that step's PR.
- **Visuals:** step 4 shows the live row, the settled row and the failed note
  on phone and desktop from fixture sessions, plus a short recording of the
  settle. Steps 5–7 add a recording on one live harness each.
- **Architecture implementation review:** steps 2 (the sweep rule's owner),
  3 (wire contract, plugin interface, sweep), 5 (Claude dispatcher state and
  id scheme), 6 (the OpenCode v2 tracker) and 7 (the DeepSeek tracker).
- **Checks:**
  - `dart analyze --fatal-infos` per touched package, with the pinned
    toolchain first on `PATH`;
  - `dart test` for bridge packages, `sesori_shared`, `module_core` and
    `module_desktop_core`;
  - `flutter test` for `module_app_ui` and the shells;
  - `build_runner` for every Freezed change.

## Steps

**Step 1 — this plan.**

**Step 2 — move the stranded-step rule into the history service.**
[Architecture 1](#1-the-stranded-step-rule-moves-into-the-history-service-step-2).
It also records the user's answers of 2026-10-07 in this plan and the
tracker. Verify:

- the existing sweep tests (idle, backfill read, fresh-store read, busy
  session, unobservable status, subtask cancel, kept command and output,
  delivery shapes, freshness marks) pass unchanged in meaning;
- a new test: a finalized tool part keeps its stored image attachment;
- `dart analyze --fatal-infos` and `dart test` for `bridge/app`.

There is no user-visible or database change. Target ≤ 600 changed lines,
about 350 of them these plan edits (mostly the renumbering).

**Step 3 — wire contract and bridge core.** [Architecture 2](#2-wire-contract-and-bridge-core-step-3).
Verify:

- shared tests:
  - a v1.9.0-shaped `{"type":"compaction","id",…}` decodes as completed with
    no details;
  - each state round-trips;
  - an unknown `status` decodes as completed;
  - an unknown trigger decodes as null;
- the mapping test for each state;
- sweep tests: a stored running compaction becomes failed with the sweep
  error at idle and on a read, and completed or failed parts are untouched;
- a service test of the abrupt-death read path: a transcript whose only open
  part is a running compaction is swept on read;
- plugin tests updated for the moved summary, with all emitters still
  completed;
- the client widget test for a completed part.

There is no user-visible change. Target ≤ 1,100 changed lines, about 550 of
them generated Freezed and JSON output.

**Step 4 — app.** [Architecture 3](#3-app-step-4). Verify:

- builder and activity rule tables: a running compaction hides "Working…"
  and the sub-agents row, and a settled one does not;
- the formatters;
- widget tests for each state:
  - timer with a fake clock, and no timer without `sinceMs`;
  - the strip appearing with streamed text;
  - the settle without a height change apart from the strip fold, and the
    instant settle under reduced motion;
  - the summary tap only when completed with a summary;
  - semantics;
- the reasoning row is unchanged after the extraction;
- screenshots and a recording from fixtures.

Target ≤ 800 changed lines.

**Step 5 — Claude.** [Architecture 4](#4-claude-step-5). Verify:

- dispatcher tests for:
  - start, then a repeat, success, boundary and summary: one message id
    throughout, in-place states and details;
  - start then failure with the error, and a boundary and summary after the
    failure emitting nothing;
  - boundary and summary without a start (today's path plus details);
  - a stale entry, `failed` included, cleared by the next turn's begin when
    the process exited without `result`;
- a DTO decode test for the camelCase `compactMetadata` and the stream's
  snake_case `compact_metadata`;
- a catalog-repository test mapping the boundary record to
  `ClaudeTranscriptCompactBoundaryRecord`;
- content-mapper tests for `freedTokens` (both present, one missing,
  `post ≥ pre`) and the trigger mapping;
- a history mapper test where the metadata reaches the next summary row;
- a `bridge/app` capture test: the live minted row, then a re-import of the
  history row with the equal timestamp and a live prompt neighbour whose id
  differs, leaves one row and asserts the id outcome of the P10 option
  chosen (the same id under option 1, the recorded re-key under option 2);
- the live probe on the current CLI;
- a recording on a device.

Target ≤ 700 changed lines.

**Step 6 — OpenCode v1 and v2** (rough, detailed by its PR). Target ≤ 800.

**Step 7 — Pi, Codex and DeepSeek** (rough, detailed by the step-6 PR).
Target ≤ 900, mostly mapper and test changes.

**Step 8 — reconcile the documents.** Bring `tools-and-file-changes.md`,
`session-turns.md`, `session-history-and-recovery.md` and
`docs/HARNESS_CAPABILITIES.md` in line with what shipped.

**Step 9 — verify and retire.** Run the recorded matrix, record the result in
`steps/step-09.md`, and move the plan to `.plan/completed/compaction-progress/`.

## Answered Questions

The user answered every question on 2026-10-07, on the review page that
numbers them Q1–Q6. These answers are final; do not reopen them.

- **Q1 — Does a manual compaction say "manual"?** No. Only "auto" is
  labelled. A manual compaction follows the user's own visible `/compact`,
  so the word adds nothing.
- **Q2 — What does a compaction that never finished show, after Stop or a
  harness process exit?** The quiet "Compaction failed · The turn ended
  before compaction finished." note, from the bridge's idle and read sweep,
  as tools already do. One rule for every harness (P6).
- **Q3 — May a v1.9.0 app on Pi or Codex lose today's running `compact`
  card?** Yes, accepted (C4). It keeps "Working…" instead.
- **Q4 — Move the sweep's rule out of the repository?** Approved as its own
  PR before the wire contract. That is step 2, which moved every later step
  up by one.
- **Q5 — What does a v1.9.0 app show while OpenCode streams a summary?**
  (Before 2026-10-07 this plan called it Q3.) Nothing, as on `main` today:
  neither "Working…" nor a row, until the summary finishes and the turn goes
  on. No old-app code.
- **Q6 — May failure notes the harness's own history lacks disappear?** Yes,
  accepted. They survive one bridge history re-import, then disappear.

## Plan Review Record

The records below keep the numbering of their date: they predate step 2's
insertion, so their step numbers are one lower than today's and their Q3 is
today's Q5. The sweep relocation they declined is today's step 2, approved by
the user on 2026-10-07 (Q4).

**`architecture-plan-review`, 2026-10-06: rejected** with one blocking and
five non-blocking findings. C1–C7, the design point and Q1–Q2 were not
reviewed. The reviewer verified the plan's code claims (emitter sites, sweep
prefilter, semantic-match rules, activity rule, the dead card case). All
findings were applied directly:

1. Blocking: the Claude transcript path had no named layers and no single
   part builder. Architecture 3 now names:
   - the API models: `ClaudeCompactMetadata`, the DTO's `subtype` and
     `compactMetadata`;
   - the repository record `ClaudeTranscriptCompactBoundaryRecord` and its
     catalog mapping;
   - `ClaudeContentMapper` as the only builder of compaction parts and
     states, owning the token and trigger rules.

   Step 4 gained the matching DTO, catalog and mapper tests.
2. P10 breaks the dispatcher's "one message id" comment. Step 4 rewrites
   it. The capture test, which now includes a live prompt neighbour with a
   different id, picks the path.
3. The sweep's policy sits in a repository by legacy. It is kept as planned,
   and the relocation is proposed as a separate refactor.
4. The phase-2 per-session maps go in trackers, not in a mapper or service.
5. `Transcript.compactionRunning` had a single reader. P8 now derives the
   fact inside `TranscriptActivityBuilder` from `messages`.
6. P5 now says only `running` is streamable, so the delta buffer is cleared
   on settle exactly as today.

Per the reviewer and AGENTS.md, the fixed findings need no re-review. This
revised version was not reviewed again.

**PR review wave 1 (#1858), 2026-10-06.** Applied:

- the OpenCode old-app exception to C4, with Q3;
- the Claude `failed` entry kept until `result`, so no completed row follows
  a failure note;
- the read-sweep predicate admitting a running compaction, with a test;
- P10's id outcome after a re-import made explicit, as three ordered
  options that the step-4 probe and capture test choose between;
- the approval scoped to phase 1, with a plan review of phase 2 in the
  step-5 PR;
- tables shortened to fit 120 characters.

Declined: moving the sweep policy into the service inside this plan. It is
the separate refactor proposed above and waits for the user.

**PR review wave 2.** Applied: the P10 fallback now needs the user's
approval, the Claude entry clears in `_resetTurn`, `sinceMs` goes through
`SystemMessageCard` too, OpenCode v1 carries its reported trigger, and
steps 5–6 get implementation review. Declined: keeping failure notes past
the second re-import (accepted low-damage risk) and moving the pre-existing
`claude_history_mapper.dart` (out of scope).
