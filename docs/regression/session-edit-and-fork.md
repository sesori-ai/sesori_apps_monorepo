# Session Edit And Fork

## Capability

The bridge can edit a prompt that opens a turn: `POST /session/rewind` removes
that prompt and every later message from the session's conversation and sends
the edited prompt in its place. Conversation only: files are never restored.
Each harness declares the branching operations it implements in
`PluginMetadata.sessionBranching`; today only Codex declares `rewind`.
Clients offer no Edit yet. A first-message edit needs no plugin rewind, so the
route accepts it on every harness.

## Required Behavior

### Bridge edit route

- The edit runs on the session's lane, so it never interleaves with a send,
  stop or archive of the same session.
- An archived session answers the archived read-only rejection without
  reaching the plugin.
- The request carries a client-generated prompt id. A repeat of an accepted id
  succeeds without reaching the plugin, even after the rewind removed the
  edited message.
- A running session is refused with `sessionBusy`. This and the turn checks
  below run before anything changes, a pending quota auto-continuation
  included.
- The bridge reads the whole stored transcript, backfilling it first when the
  store is behind the backend, and finds the message's turn by the shared
  `splitPromptTurns` rule. A message that does not open a turn (a reply or a
  follow-up) is refused with `branchPointUnavailable`.
- An edit of the first turn never reaches a plugin rewind, so it works on
  every harness. The bridge creates a new harness session in the session's
  directory with the edited prompt as its first prompt (with the worktree
  context, for a dedicated worktree) and moves the same Sesori session onto
  it in one transaction. The new harness session's events reach clients under
  the unchanged session id, with no `session.created`.
- The old harness session is deleted the way a session delete does it: it and
  its sub-agent sessions are tombstoned in that same transaction, so catalog
  import and startup cleanup never bring them back, and their sub-agent rows
  and history are removed. Its late events and `session.deleted` change
  nothing. A failed backend delete is only logged; the edit still succeeds.
  A row catalog import already bound to the new harness session is replaced.
- A harness that cannot rewind, or whose plugin cannot map the message to a
  native boundary, is refused with `branchPointUnavailable`. The plugin's own
  user-facing sentence travels as the message; transcript text never does.
- Stale prompt options answer `staleSessionOptions` after the options cache is
  invalidated; a plugin refusal answers `refused`.
- Every branch refusal is a 409 `SessionBranchErrorResponse` and leaves the
  transcript untouched; the archived rejection keeps its own shared shape.
- After the plugin accepts (or the new harness session is bound), the bridge removes exactly the messages it read
  before the call, by id, from the store and from clients
  (`message.removed`). The edited prompt's echo, captured during the call, is
  never among them.
- When the plugin fails after it may have rewound (anything other than a
  branch-point, stale-options or refusal rejection), the bridge reads the
  harness transcript once and removes, by exact id, the messages it read
  before the call that the harness no longer has, then returns the failure.
  A failure that changed nothing, or a harness read that comes back empty,
  removes nothing.
- An edit with no parts is rejected with 400 before anything changes.

### Codex edit

- The edit maps the message to its native turn from the rollout's
  `UserMessage` items, resumes the thread if needed, calls
  `thread/revert {beforeTurnId}`, then starts the edited turn with the same
  prompt id. History follows the reverted rollout as soon as the edit is
  accepted.
- Refused with a plain reason without changing the conversation: a runtime without
  `thread/revert` (for example 0.139.0), a legacy non-paginated thread, an
  ephemeral thread, an id the rollout does not have, a follow-up steered into
  a running turn, and an attachment or option the turn cannot take.
- If `turn/start` fails after the revert, the bridge reconcile above removes
  the reverted messages; the edit still fails and the client keeps its text.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated bridge tests with a fake rewind plugin: a later-turn edit removes exactly the read messages and keeps the echo captured during the call; a repeated prompt id succeeds without a second rewind; busy, non-opener, no-rewind harness, plugin branch-point, stale-options and archived refusals reach the right code before any change; a partial store backfills before validation; the route answers a refusal with a 409 `SessionBranchErrorResponse`; a failed resend after the harness rewound removes exactly the dropped messages, and a failure that changed nothing removes none. A first-turn edit binds the new harness session (with the worktree context in a dedicated worktree), tombstones and deletes the old one and its sub-agent rows and history, survives a failed old delete, replaces a stray imported row, and leaves the binding, rows and transcript untouched when the new session cannot be created; the event service releases the new session's held events under the old id and ignores the old session's late events. Codex plugin tests against a fake app-server: resume, revert and `turn/start` order with the prompt id; history follows the reverted rollout; steered, unknown-id, attachment and revert-error refusals happen before any revert. |
| L3 Release | Not included until clients offer Edit. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Failure Signals

- An edit removes the edited prompt's echo, or leaves a removed message on
  screen until reload.
- A retried edit rewinds twice.
- A refusal changes the transcript, or its message carries transcript text.
- After a first-message edit the session shows twice, the old conversation
  comes back after a catalog refresh or restart, or the new prompt's replies
  never arrive.
- A Codex edit whose resend failed leaves the reverted messages on screen.
- An edit reaches the plugin while the session runs or after it was archived.

## Known Limitations

- Only Codex implements rewind; every other harness refuses an edit after
  the first turn.
- An edit the plugin refuses keeps the attachment files the bridge saved for
  it, as a refused send does.

## Sources

- `bridge/sesori_plugin_interface/lib/src/session_rewind_plugin_api.dart`
- `bridge/app/lib/src/routing/rewind_session_handler.dart`
- `bridge/app/lib/src/services/session_prompt_service.dart`
- `bridge/app/lib/src/repositories/session_repository.dart`
- `bridge/app/lib/src/services/session_event_service.dart`
- `bridge/app/lib/src/services/chat_history_service.dart`
- `bridge/sesori_plugin_codex/lib/src/services/codex_session_service.dart`
- `bridge/sesori_plugin_codex/lib/src/repositories/codex_message_repository.dart`
- `shared/sesori_shared/lib/src/models/sesori/session_branch_error_response.dart`
