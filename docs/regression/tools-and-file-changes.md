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
  Non-shell titles, output snippets, and errors stop at the bridge remapping
  boundary and never enter chat history or live client events.
- Plugin and shared message parts are sealed variants, so text, tool, subtask,
  file, agent, and retry data cannot be combined with unrelated part types. The
  shared variants retain the released `type` values and normalize known payloads
  whose variant-specific fields were omitted by an older bridge into temporary,
  non-null compatibility defaults: empty text/name details, retry attempt zero,
  an unknown file attachment, and pending tool state. Current peers serialize
  those non-null values.
- Shell-command output is bounded to the shared limit and truncated by runes,
  so a character is never split; the rule is identical live and on replay.
- Backend vocabulary stays in the owning plugin. Attachments use client-safe
  sources: local paths never cross, unsafe URLs degrade to metadata.
- A tool that mutates the workspace emits a per-session file-change signal once
  per mutating completion; non-mutating tools, in-progress updates, and repeated
  updates for one completed call emit none.
- Sub-agent, subtask, and agent parts identify their agent and stay attributed
  to the correct session, including work done by a child. Tool state survives a
  reload with the same identity and status; shell commands also retain their
  command and result. Unknown status renders as the fallback. A backend abort without a turn identifier still finalizes tools
  in the active turn.
- DeepSeek projects tool calls and updates through standard ACP with exact call
  identity, terminal state, attachments, and diff content. Presenter failure
  degrades to a generic lightweight tool card instead of dropping the call.
- Cursor's fire-and-forget tool extensions preserve their top-level tool-call
  correlation before falling back to the active turn, including while another
  session is in flight.
- GitHub Copilot uses the same standard ACP tool lifecycle. Permission linkage
  must be exact while the request is live. Call identity, terminal state, and
  diff content then converge after `session/load`; permission
  decisions are process-local and are not part of replay. Backend tool names
  remain presentation data rather than shared behavior.
- Grok uses that standard ACP lifecycle with exact live permission linkage.
  Tool-call identity, pending-to-terminal status, and diff content converge
  between live events and `session/load`; Grok tool names
  remain presentation data and never become shared domain vocabulary.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because proving tool behavior requires a live turn. |
| L2 Routine | Live plugin, representative: a file-editing tool produces a lightweight tool part with name and terminal status, while a shell tool preserves its command and bounded result. |
| L3 Release | Client end to end (phone), every supporting production plugin: status normalizes consistently, non-shell snippets are absent, and shell commands/results/errors render; a mutating tool emits the file-change signal once and a read-only tool emits none; tool cards and subtask/agent parts render. Copilot covers one read-only tool, one file mutation with permission linkage and diff invalidation, and one failing tool. Grok covers a complete lightweight tool lifecycle, a file diff and invalidation, live permission linkage, and cold-replay identity/status parity. |
| L4 Extended | Live plugin, every supporting production plugin: tool parts survive history reload with identity and status intact, shell commands retain their results, and non-shell snippets remain absent; a failing shell command surfaces an error rather than a stuck running state; child-session tool activity is attributed correctly; repeated completion updates do not duplicate the file-change signal. |
| L5 Full | Client end to end, every supporting production plugin: rune-boundary truncation is exact for multi-byte shell output; attachments render where emitted and unsafe or malformed sources degrade to metadata; unknown status from a newer peer degrades gracefully. |

## Exploration Guidance

Vary the tool mix per run: read-only inspection, single- and multi-file edits,
shell-style execution, a failing tool, a sub-agent task. Alternate long,
multi-byte, and empty shell output; compare live with a later reload. For
Copilot, verify permission linkage against the live call, then cold-replay the
resulting call identity, terminal tool state, and diff without expecting its
process-local permission decision to replay. For Grok, compare read-only,
mutating, and failing tools live and after `session/load`, including one
permission-gated mutation and one repeated terminal update.

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
  different concurrently active session.
- A Copilot tool loses permission correlation while live, or its call identity,
  terminal status, or diff changes when reopened through ACP history.
- A Grok tool loses live permission correlation, changes call identity or status
  after replay, exposes non-shell output, loses diff content, or emits the wrong
  number of file-change invalidations.
- The file-change signal is missing after a real mutation, emitted for a
  read-only tool, emitted repeatedly for one call, or wrongly attributed.

## Known Limitations

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
- Plans (discovery only): `.plan/completed/output-image-support`,
  `.plan/completed/attachment-references`
