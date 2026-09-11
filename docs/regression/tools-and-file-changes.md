# Tools And File Changes

## Capability

How a turn's tool activity is normalized and presented: lightweight tool parts
with status and attachments, explicit shell commands with bounded results, and
sub-agent parts, plus the signal that a tool changed files.

## Required Behavior

- Every plugin normalizes backend tool activity into the shared tool part
  contract: stable identity, tool name, lifecycle status (pending, running,
  completed, error, plus a forward-compatible unknown), and attachments. Shell
  tools additionally carry the explicit command and its bounded output or error.
  Ordinary non-shell tool titles, output snippets, and errors stop at the bridge remapping
  boundary and never enter chat history or live client events.
- Plugin and shared message parts are sealed variants, so text, tool, subtask,
  file, agent, and retry data cannot be combined with unrelated part types. The
  shared variants retain the released `type` values and normalize known payloads
  whose variant-specific fields were omitted by an older bridge into temporary,
  non-null compatibility defaults: empty text/name details, retry attempt zero,
  an unknown file attachment, and pending tool state. Current peers serialize
  those non-null values.
- Shell commands, output and errors are bounded to the shared limit and truncated
  by runes at the common bridge projection, so a character is never split; the
  rule is identical live and on replay. The command remains the released title
  alias for older clients; old title-only payloads still decode.
- Subtasks retain bounded title/outcome/error summaries, status, attachments and
  child-session IDs; ordinary non-shell tool stripping never applies to them.
- Codex code-mode JavaScript is not itself a shell command. Only verified
  `exec_command` input, literal single-invocation code-mode command evidence or
  correlated `commandExecution` data retains shell results. Quoted/commented fake
  invocations and generic shell-like tool names do not classify as commands.
- ACP command authority is adapter-owned, not inferred from execute kind, title,
  or arbitrary content. Antigravity's native alias normalizer and Grok's exact
  terminal-tool metadata feed the same live/replay command merge. Output-only
  and failed deltas preserve commands; reordered initial calls cannot overwrite
  newer evidence. Antigravity exit-only updates retain output and nonzero exit
  annotations do not change the adapter's existing ACP status semantics.
  See `docs/HARNESS_CAPABILITIES.md` for unverified command-source gaps.
- Backend vocabulary stays in the owning plugin. Attachments use client-safe
  sources: local paths never cross, unsafe URLs degrade to metadata.
- A tool that mutates the workspace emits a per-session file-change signal once
  per mutating completion; non-mutating tools, in-progress updates, and repeated
  updates for one completed call emit none.
- Sub-agent, subtask, and agent parts identify their agent and stay attributed
  to the correct session, including work done by a child. Tool state survives a
  reload with the same identity and status; shell commands also retain their
  command and result. Unknown status renders as the fallback. A backend abort
  without a turn identifier still finalizes tools in the active turn.
- Claude `Agent`/`Task` calls render as subtask parts keyed by the tool-use
  id, with the sub-agent description, prompt, and agent type, a lifecycle of
  their own (`pending`/`running` → `completed`, `error`, or `cancelled`), and
  a `childSessionID` naming the sub-agent's child session once known. The task
  notification is the authoritative terminal source; the launching call's own
  tool result is a fallback that a later notification replaces, and a
  background launch never finalizes the part. When Claude resumes the same
  agent after it stopped, the repeated start reopens the existing part as
  `running`, clears its prior outcome, and restores the already-announced child
  to busy. A part appears only once its input names the description and prompt,
  never with placeholder text. On replay the same parts render from the
  transcript, current resident state overrides an earlier terminal notification,
  and a still-running task the session's resident process no longer owns renders
  as `cancelled`.
  Process exit — natural or an explicit stop — cancels every running task.
  OpenCode subtask parts keep a null lifecycle and the child-status fallback.
- Codex replaces a generic `spawn_agent` tool by exact call id with one subtask
  tile linked to the direct child thread. A complete child-owned plaintext
  `NEW_TASK` input owns prompt provenance for the initial child turn; normally
  encrypted input instead retains only the exact nonblank message from the
  matching parent `spawn_agent` call. Parent history, labels, order, timing,
  envelope headers, encrypted content, later resumed input, and metadata-only
  `thread/read` never supply prompt text. Child completion, failure,
  interruption, close, and disconnect settle the tile, with the initial turn's
  first terminal state winning. Parent spawn completion and parent turn
  completion do not settle it. Replay performs the same exact-id replacement
  and takes provenance-safe prompt and terminal facts from the catalogued child
  rollout, never live tracker state.
- DeepSeek projects tool calls and updates through standard ACP with exact call
  identity, terminal state, attachments, and diff content. Its native `web_search`
  and `web_fetch` tools use the same tool lifecycle; they make outbound requests
  when invoked, without starting a Web BFF, HTTP listener, or another process.
  Telemetry remains disabled. Presenter failure degrades to a generic lightweight
  tool card instead of dropping the call. With protocol v2, correlated sub-agent
  starts replace exact `subagent`/`subagent_fork` cards with one child-linked tile;
  identifiable updates arriving before their call are deferred too. Start/end
  events retain the direct parent's transcript and keep root activity busy.
  Launch prompts remain authoritative without child prompt echoes; malformed
  ends finalize known children as error. Startup failures retain one generic
  terminal card. Replay projects typed delegation metadata into the same tile
  identity and terminal policy, or an unlinked tile when no child was created;
  unrelated tools retain the generic ACP projection. Initialization requires v2.
- Cursor's fire-and-forget tool extensions preserve their top-level tool-call
  correlation before falling back to the active turn, including while another
  session is in flight. Its standard `_toolName: task` pending/running updates
  remain generic and are tracked only for prompt settlement. Prompt cancellation
  settles every active Task as a generic cancelled card; prompt failure settles
  it as a generic error card with bounded privacy-safe ACP failure text. Process
  exit first fails pending prompt RPCs so active cards reach error before reset;
  reset then clears remaining correlation without synthesizing lifecycle. Every
  standard terminal card remains generic and retires tracking. Native
  `cursor/task` requests receive required empty acknowledgement and are
  deliberately ignored after reinjection until completed foreground tiles land.
  No child session, tile, background lifecycle, or replay is claimed.
- Antigravity normalizes its `formatted_output`, `exit_code`, `command_line`, and `working_dir` aliases before the
  shared ACP live or replay mapper retains tool state. Raw provider payloads and canonical output are independently
  bounded; local image paths remain metadata and are never read. Exact duplicate text is removed, differing standard
  and provider text is retained within the shared display cap, and a nonzero exit note never changes ACP tool status.
- GitHub Copilot uses the same standard ACP tool lifecycle. Permission linkage
  must be exact while the request is live. Call identity, terminal state, and
  diff content then converge after `session/load`; permission
  decisions are process-local and are not part of replay. Backend tool names
  remain presentation data rather than shared behavior.
- Grok uses that standard ACP lifecycle with exact live permission linkage.
  Root history replaces only metadata-identified `spawn_subagent` tools with one
  deterministic child-linked subtask tile, using the exact child's persisted
  first user-message run as prompt only when that run is nonblank, plus typed
  lifecycle for terminal state/output. A blank or missing first run produces no
  tile; later runs never substitute. Ordinary tools remain generic and ordered
  around the tile, without an empty assistant message after spawn suppression.
  Tool-call identity, pending-to-terminal status, and diff content otherwise
  converge between live events and `session/load`; verified shell commands also
  retain bounded output or error. Grok tool names remain presentation data and
  never become shared domain vocabulary.
  Corrected production-composition QA after PR #1429 verified exact root/child
  replay linkage and child-owned prompt provenance. Phone automation stopped
  before visible UI, so phone tile rendering and read-only child navigation
  remain unexecuted.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because proving tool behavior requires a live turn. |
| L2 Routine | Live plugin, representative: a file-editing tool produces a lightweight tool part with name and terminal status, while a shell tool preserves its command and bounded result. |
| L3 Release | Client end to end (phone), every supporting production plugin: status normalizes consistently, non-shell tool snippets are absent, and shell commands/results/errors render; a mutating tool emits the file-change signal once and a read-only tool emits none; tool cards and subtask/agent parts render. Claude covers a foreground and a background sub-agent tile going running → completed with the result text, tapping the tile opening the child transcript, and a cancelled tile after the process is killed; OpenCode proves a null-lifecycle subtask part still renders and opens as before. Copilot covers one read-only tool, one file mutation with permission linkage and diff invalidation, and one failing tool. Grok target coverage: a complete lightweight tool lifecycle, a file diff and invalidation, live permission linkage, and cold-replay identity/status parity. Grok phone cases remain infrastructure-blocked; live permission linkage remains unexecuted. |
| L4 Extended | Live plugin, every supporting production plugin: tool parts survive history reload with identity and status intact, shell commands retain their results, and non-shell snippets remain absent; a failing shell command surfaces an error rather than a stuck running state; child-session tool activity is attributed correctly; repeated completion updates do not duplicate the file-change signal. Claude: a reloaded session with a finished background sub-agent shows one completed subtask tile with the same identity and `childSessionID`, a still-running one stays running while its process lives, a resumed terminal agent returns to running in both its tile and child status, and a failed sub-agent renders `error` with the notification summary. |
| L5 Full | Client end to end, every supporting production plugin: rune-boundary truncation is exact for multi-byte shell output; attachments render where emitted and unsafe or malformed sources degrade to metadata; unknown status from a newer peer degrades gracefully. |

## Exploration Guidance

Vary the tool mix per run: read-only inspection, single- and multi-file edits,
shell-style execution, a failing tool, a sub-agent task. Alternate long,
multi-byte, and empty shell output; compare live with a later reload. For Antigravity,
compare command/output aliases, long stdout/stderr, nonzero exits, malformed
native fields, standard images and path-only image metadata live and after
replay. For Copilot, verify permission linkage against the live call, then
cold-replay the resulting call identity, terminal tool state, and diff without
expecting its process-local permission decision to replay. For Grok, compare
read-only, mutating, and failing tools live and after `session/load`, including
one permission-gated mutation, one repeated terminal update, and a verified
shell command with long output. Reload a root with completed/cancelled children
and each child transcript; verify prompt provenance, tile order, and both
lifecycle extension methods. Denial remains unverified and carries no replay
guarantee.

## Failure Signals

- Shell output exceeds the bound, truncates mid-character, or differs between
  live streaming and replay; or non-shell snippets reach the client.
- A tool stays running after the backend finished, or an error renders as a
  completion.
- Backend naming or payload shape reaches the client unnormalized, or a local
  path or unsafe URL crosses the attachment contract.
- A part carries fields owned by another variant, or a released known-type
  payload fails to decode because an older bridge omitted variant data, or a
  current peer serializes null variant data.
- A Cursor tool extension with an originating call ID is attributed to a
  different concurrently active session; a pending/running standard Task is
  mistaken for a child, root/activity/count state changes, a terminal standard
  card stays tracked, `cursor/task` is not acknowledged, or a cancelled/failed
  prompt leaves its generic Task running.
- Antigravity changes ACP status from an exit code, loses an exit note to truncation, leaks an image path as a fetched
  attachment, retains unbounded/redundant raw fields, drops differing text, or
  produces different live/replay tool state.
- A Copilot tool loses permission correlation while live, or its call identity,
  terminal status, or diff changes when reopened through ACP history.
- A Grok tool loses live permission correlation, changes call identity or status
  after replay, exposes ordinary non-shell output or unbounded shell output,
  loses diff content, emits the wrong number of file-change invalidations,
  leaves a generic spawn beside its tile, binds by description/order instead of
  child id, crosses the first prompt-run boundary, or leaves an empty message
  after spawn suppression.
- The file-change signal is missing after a real mutation, emitted for a
  read-only tool, emitted repeatedly for one call, or wrongly attributed.
- A Claude sub-agent renders as a generic `Agent` tool card, its tile stays
  running after the sub-agent finished or its process died, a background
  launch's "Async agent launched" tool result finalizes the tile, a late tool
  result overwrites a notification-set status, tapping the tile opens the wrong
  or no child transcript, or the tile shows placeholder text before its input
  is complete.
- A Codex spawn remains both a generic tool and subtask tile, pairs by label or
  order instead of exact call id, uses copied parent history as its prompt,
  ignores later native child text, or loses child terminal state after reload.

## Known Limitations

- An interrupted Claude foreground sub-agent renders `cancelled` live (the
  notification reports `stopped`) but `error` on replay, because the transcript
  persists only its error tool result; tool-result text is never matched.
- The Claude CLI 2.1.221 floor was not probed for `task_started` and
  `task_notification` frames; the typed tool-result and notification-text
  substitutes are unit-tested only.

- Available tools, attachments, and sub-agents are backend-specific; a plugin
  that cannot produce a case is not a failure but is also not coverage.
- Rendering needs the client; the phone is the only transcript surface.
- The final DeepSeek phone gate exercised scoped stop and ordered pending input,
  not cold tile/history reload, tool-card parity, or read-only child navigation.
  Those presentation cases remain automated or unexecuted at the client boundary;
  no desktop transcript case was run.
- ACP permission decisions and pending requests are process-local interaction
  state. Cold replay restores the resulting tool lifecycle and diff, not the
  earlier decision or its linkage event.
- Real Antigravity tool execution and generated-image output remain unverified; synthetic normalization
  establishes the boundary contract only.
- Attachment presentation is being reworked toward referenced images; only the
  shipped build counts.
- An older client does not tolerate an unknown message-part `type` from a newer
  bridge: history decoding fails and the corresponding SSE event is dropped as
  malformed. Unknown tool status remains forward-compatible.

## Sources

- Contract: `bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart`;
  `shared/sesori_shared/lib/src/models/sesori/message_part.dart`
- Bridge: `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`,
  the shared ACP mapper used by `bridge/sesori_plugin_antigravity/`,
  `bridge/sesori_plugin_copilot/` and
  `bridge/sesori_plugin_grok/`, `bridge/app/lib/src/sse/bridge_event_mapper.dart`;
  mappers and tests under
  `bridge/sesori_plugin_*/`; `client/app/lib/features/session_detail/widgets/`
- Tests: `shared/sesori_shared/test/models/message_attachment_test.dart`,
  `bridge/app/test/bridge/sse/bridge_event_mapper_test.dart`
- Claude sub-agents: `bridge/sesori_plugin_claude/lib/src/repositories/trackers/claude_tool_tracker.dart`,
  `claude_event_dispatcher.dart`, `claude_history_mapper.dart`, and
  `bridge/sesori_plugin_claude/test/claude_subtask_lifecycle_test.dart`
- Plans (discovery only): `.plan/completed/output-image-support`,
  `.plan/completed/attachment-references`, `.plan/active/claude-inline-subtasks`

## Focused automated verification

- `bridge/app/test/bridge/{plugin_to_shared_mapping,acp_tool_projection,codex_tool_projection,backend_tool_projection}_test.dart`
  exercises backend-shaped positive/negative classification, successful and failed
  live/history states, subtask outcomes/IDs, multibyte bounds, released title
  decoding and attachments. ACP cases include partial/reordered updates and
  Antigravity alias/exit-only behavior.
- Owning Claude content/history/tracker, Pi history/dispatcher, OpenCode part
  mapper, Codex rollout/tracker/history, ACP replay/content, Grok adapter,
  Antigravity normalizer and DeepSeek replay/time tests guard backend semantics.
- `bridge/app/tool/benchmarks/tool_projection_payload_size.dart` reproducibly
  reports synthetic serialized UTF-8 bytes before/after projection. It states
  source/starting-HEAD baselines, separates typical already-bounded text from
  oversized stress inputs, and deliberately excludes envelopes, attachment bytes,
  compression, encryption and latency. Already-bounded shell results do not gain
  further output savings from the common bound. Subtask payload growth restores
  intended outcome information; it is not a regression in ordinary-tool trimming.
