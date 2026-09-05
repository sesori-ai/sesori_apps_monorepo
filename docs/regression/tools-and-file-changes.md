# Tools And File Changes

## Capability

How a turn's tool activity is normalized and presented: tool parts with title,
status, bounded output, errors, attachments, and sub-agent parts, plus the
signal that a tool changed files.

## Required Behavior

- Every plugin normalizes backend tool activity into the shared tool part
  contract: stable identity, tool name, lifecycle status (pending, running,
  completed, error, plus a forward-compatible unknown), title, output, error.
- Plugin and shared message parts are sealed variants, so text, tool, subtask,
  file, agent, and retry data cannot be combined with unrelated part types. The
  shared variants retain the released `type` values and normalize known payloads
  whose variant-specific fields were omitted by an older bridge into temporary,
  non-null compatibility defaults: empty text/name details, retry attempt zero,
  an unknown file attachment, and pending tool state. Current peers serialize
  those non-null values.
- Tool output is bounded to the shared limit and truncated by runes, so a
  character is never split; the rule is identical live and on replay.
- Backend vocabulary stays in the owning plugin. Attachments use client-safe
  sources: local paths never cross, unsafe URLs degrade to metadata.
- A tool that mutates the workspace emits a per-session file-change signal once
  per mutating completion; non-mutating tools, in-progress updates, and repeated
  updates for one completed call emit none.
- Sub-agent, subtask, and agent parts identify their agent and stay attributed
  to the correct session, including work done by a child. Tool state survives a
  reload with the same identity, status, and output; unknown status renders as
  the fallback. A backend abort without a turn identifier still finalizes tools
  in the active turn.
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
- DeepSeek projects tool calls and updates through standard ACP with exact call
  identity, bounded presenter output, terminal result/error state, and diff
  content. Presenter failure degrades to a generic bounded tool card instead of
  dropping the call or result. With adapter 0.1.3 and protocol v2, correlated
  sub-agent starts
  replace exact `subagent`/`subagent_fork` cards with one child-linked tile;
  identifiable updates arriving before their call are deferred too. Start/end
  events retain the direct parent's transcript and keep root activity busy.
  Launch prompts remain authoritative without child prompt echoes; malformed
  ends finalize known children as error. Startup failures retain one generic
  terminal card. Initialization requires protocol v2; replay projection is pending.
- Cursor's fire-and-forget tool extensions preserve their top-level tool-call
  correlation before falling back to the active turn, including while another
  session is in flight.
- GitHub Copilot uses the same standard ACP tool lifecycle. Permission linkage
  must be exact while the request is live. Call identity, bounded output,
  terminal state, and diff content then converge after `session/load`; permission
  decisions are process-local and are not part of replay. Backend tool names
  remain presentation data rather than shared behavior.
- Grok uses that standard ACP lifecycle with exact live permission linkage.
  Tool-call identity, pending-to-terminal status, bounded output or error, and
  diff content converge between live events and `session/load`; Grok tool names
  remain presentation data and never become shared domain vocabulary.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because proving tool behavior requires a live turn. |
| L2 Routine | Live plugin, representative: a file-editing tool produces a tool part with name, terminal status, and bounded output. |
| L3 Release | Client end to end (phone), every supporting production plugin: title, status, output bound, and errors normalize consistently; a mutating tool emits the file-change signal once and a read-only tool emits none; tool cards, errors, and subtask/agent parts render. Claude covers a foreground and a background sub-agent tile going running → completed with the result text, tapping the tile opening the child transcript, and a cancelled tile after the process is killed; OpenCode proves a null-lifecycle subtask part still renders and opens as before. Copilot covers one read-only tool, one file mutation with permission linkage and diff invalidation, and one failing tool. Grok covers a complete tool lifecycle with bounded output, a file diff and invalidation, live permission linkage, and cold-replay identity/status parity. |
| L4 Extended | Live plugin, every supporting production plugin: tool parts survive history reload with identity, status, and output intact; a failing tool surfaces an error rather than a stuck running state; child-session tool activity is attributed correctly; repeated completion updates do not duplicate the file-change signal. Claude: a reloaded session with a finished background sub-agent shows one completed subtask tile with the same identity and `childSessionID`, a still-running one stays running while its process lives, a resumed terminal agent returns to running in both its tile and child status, and a failed sub-agent renders `error` with the notification summary. |
| L5 Full | Client end to end, every supporting production plugin: rune-boundary truncation is exact for multi-byte output; attachments render where emitted and unsafe or malformed sources degrade to metadata; unknown status from a newer peer degrades gracefully. |

## Exploration Guidance

Vary the tool mix per run: read-only inspection, single- and multi-file edits,
shell-style execution, a failing tool, a sub-agent task. Alternate long,
multi-byte, and empty output; compare live with a later reload. For Copilot,
verify permission linkage against the live call, then cold-replay the resulting
call identity, terminal tool state, bounded output, and diff without expecting
its process-local permission decision to replay. For Grok, compare read-only,
mutating, failing, and long-output tools live and after `session/load`, including
one permission-gated mutation and one repeated terminal update.

## Failure Signals

- Output exceeds the bound, truncates mid-character, or differs between live
  streaming and replay.
- A tool stays running after the backend finished, or an error renders as a
  completion.
- Backend naming or payload shape reaches the client unnormalized, or a local
  path or unsafe URL crosses the attachment contract.
- A part carries fields owned by another variant, or a released known-type
  payload fails to decode because an older bridge omitted variant data, or a
  current peer serializes null variant data.
- A Cursor tool extension with an originating call ID is attributed to a
  different concurrently active session.
- A Copilot tool loses permission correlation while live, or its call identity,
  terminal status, bounded output, or diff changes when reopened through ACP
  history.
- A Grok tool loses live permission correlation, changes call identity or status
  after replay, exposes unbounded output, loses diff content, or emits the wrong
  number of file-change invalidations.
- The file-change signal is missing after a real mutation, emitted for a
  read-only tool, emitted repeatedly for one call, or wrongly attributed.
- A Claude sub-agent renders as a generic `Agent` tool card, its tile stays
  running after the sub-agent finished or its process died, a background
  launch's "Async agent launched" tool result finalizes the tile, a late tool
  result overwrites a notification-set status, tapping the tile opens the wrong
  or no child transcript, or the tile shows placeholder text before its input
  is complete.

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
- ACP permission decisions and pending requests are process-local interaction
  state. Cold replay restores the resulting tool lifecycle and diff, not the
  earlier decision or its linkage event.
- Attachment presentation is being reworked toward referenced images; only the
  shipped build counts.
- An older client does not tolerate an unknown message-part `type` from a newer
  bridge: history decoding fails and the corresponding SSE event is dropped as
  malformed. Unknown tool status remains forward-compatible.

## Sources

- Contract: `bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart`;
  `shared/sesori_shared/lib/src/models/sesori/message_part.dart`
- Bridge: `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`,
  the shared ACP mapper used by `bridge/sesori_plugin_copilot/` and
  `bridge/sesori_plugin_grok/`, `bridge/app/lib/src/sse/bridge_event_mapper.dart`;
  mappers and tests under
  `bridge/sesori_plugin_*/`; `client/app/lib/features/session_detail/widgets/`
- Tests: `shared/sesori_shared/test/models/message_attachment_test.dart`,
  `bridge/app/test/bridge/sse/bridge_event_mapper_test.dart`
- Claude sub-agents: `bridge/sesori_plugin_claude/lib/src/repositories/trackers/claude_tool_tracker.dart`,
  `claude_event_dispatcher.dart`, `claude_history_mapper.dart`, and
  `test/claude_subtask_lifecycle_test.dart`
- Plans (discovery only): `.plan/completed/output-image-support`,
  `.plan/completed/attachment-references`, `.plan/active/claude-inline-subtasks`
