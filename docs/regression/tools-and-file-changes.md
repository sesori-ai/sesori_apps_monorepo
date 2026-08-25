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
- DeepSeek projects tool calls and updates through standard ACP with exact call
  identity, bounded presenter output, terminal result/error state, and diff
  content. Presenter failure degrades to a generic bounded tool card instead of
  dropping the call or result.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because proving tool behavior requires a live turn. |
| L2 Routine | Live plugin, representative: a file-editing tool produces a tool part with name, terminal status, and bounded output. |
| L3 Release | Client end to end (phone), every supporting production plugin: title, status, output bound, and errors normalize consistently; a mutating tool emits the file-change signal once and a read-only tool emits none; tool cards, errors, and subtask/agent parts render. |
| L4 Extended | Live plugin, every supporting production plugin: tool parts survive history reload with identity, status, and output intact; a failing tool surfaces an error rather than a stuck running state; child-session tool activity is attributed correctly; repeated completion updates do not duplicate the file-change signal. |
| L5 Full | Client end to end, every supporting production plugin: rune-boundary truncation is exact for multi-byte output; attachments render where emitted and unsafe or malformed sources degrade to metadata; unknown status from a newer peer degrades gracefully. |

## Exploration Guidance

Vary the tool mix per run: read-only inspection, single- and multi-file edits,
shell-style execution, a failing tool, a sub-agent task. Alternate long,
multi-byte, and empty output; compare live with a later reload.

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
- The file-change signal is missing after a real mutation, emitted for a
  read-only tool, emitted repeatedly for one call, or wrongly attributed.

## Known Limitations

- Available tools, attachments, and sub-agents are backend-specific; a plugin
  that cannot produce a case is not a failure but is also not coverage.
- Rendering needs the client; the phone is the only transcript surface.
- Attachment presentation is being reworked toward referenced images; only the
  shipped build counts.
- An older client does not tolerate an unknown message-part `type` from a newer
  bridge: history decoding fails and the corresponding SSE event is dropped as
  malformed. Unknown tool status remains forward-compatible.
- DeepSeek tool projection is automated at the protocol/mapper boundary. A live
  workspace mutation, file-change signal, client tool card, failure, and replay
  parity remain required Step 16 evidence.

## Sources

- Contract: `bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart`;
  `shared/sesori_shared/lib/src/models/sesori/message_part.dart`
- Bridge: `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`,
  `bridge/app/lib/src/sse/bridge_event_mapper.dart`; mappers and tests under
  `bridge/sesori_plugin_*/`; `client/app/lib/features/session_detail/widgets/`
- Tests: `shared/sesori_shared/test/models/message_attachment_test.dart`,
  `bridge/app/test/bridge/sse/bridge_event_mapper_test.dart`
- Plans (discovery only): `.plan/completed/output-image-support`,
  `.plan/completed/attachment-references`
