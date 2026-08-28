# Session Archiving And Deletion

## Capability

A session can be retired permanently as a read-only audit record, or removed
entirely along with its transcript and, optionally, its worktree.

## Required Behavior

- Archiving is final. An archived session can never be unarchived, prompted,
  renamed, replied to, or otherwise mutated in place; those attempts receive the
  same archived read-only rejection evaluated on the session the caller named.
  Permanent deletion remains allowed.
- Archiving exports a versioned transcript audit record before the session flips
  to archived, then purges live history for it. When backend history is
  unavailable the export may proceed from stored content only and must record
  that honestly, never claiming completeness it lacks. The archived session
  stays readable through the same history path, served from that record.
- Deletion removes the session record immediately and is destructive and not
  recoverable. History, spilled content, and the archive record are purged
  best-effort after row deletion; a logged failure leaves residue for startup
  reconciliation. Worktree cleanup happens only when requested; unsafe cleanup
  (unstaged changes or a shared worktree) is refused with its issues and proceeds
  only on a forced retry. Session retirement never deletes a Git branch.
- Per-session prompt defaults are live composer cache, not audit data. Archiving
  clears them from the session row and omits them from the archive snapshot;
  deletion removes them with the row. The separate last-successful New Session
  preference is plugin-scoped and survives retiring any individual session.
- Once deletion cleanup starts, the bridge suppresses session-created and
  session-updated events for the named session and its persisted descendants.
  Suppression remains for the bridge lifetime after success and is removed if
  deletion fails, so late or already-queued backend events cannot re-add a
  deleted session to a client.
- For a backend that advertises session close, deleting an active session first
  cancels its turn and pending input, waits within a bounded deadline for that
  session to settle, then closes it before local plugin state is removed. A
  timeout or close failure remains observable and leaves local state retryable.
- OMP tombstone reconciliation pages its ACP catalog to exhaustion, resumes the
  matching session without replay, invokes `/session delete`, then closes it.
  A bounded but truncated scan uses OMP's global-ID resume fallback; only an
  exhausted scan is treated as idempotent not-found.
- GitHub Copilot exposes standard `session/close` but no delete/archive RPC.
  Deletion cancels and closes a resident session when possible, purges Sesori's
  row and transcript, and retains the plugin-scoped tombstone so a later explicit
  ACP import cannot resurrect the retained upstream row. Sesori never deletes
  files from Copilot's normal configuration home.
- Cleanup safety rejection happens before mutation. Once cleanup starts, a later
  visible failure can leave the worktree already removed; an identical retry
  accepts that missing worktree and completes session retirement. The session is
  deleted only after cleanup succeeds, and both flows serialize against
  concurrent mutations of the same session family.
- Published requests retain the retired `deleteBranch` field for mixed-version
  compatibility. New clients always send `false`, and new bridges explicitly
  reject `true` before mutation so old clients cannot mistake unperformed branch
  cleanup for success.
- Clients present archiving as permanent, hide mutation affordances there, and
  list archived sessions.
- Archive and delete confirmation sheets identify the action, default worktree
  cleanup on only when a dedicated worktree exists, and keep deletion's confirm
  action visually destructive. Cancelling performs neither operation.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, one representative plugin: a session archives, stays readable, and refuses a later non-deletion mutation. |
| L2 Routine | Headless bridge, representative: deletion removes the session immediately and purges its history and archive record, with a simulated purge failure logged and recovered by startup reconciliation; export and purge observed as a pair with honest completeness; cleanup rejection issues reported without deleting anything; a close-capable ACP session orders cancel, settlement, and close, while timeout preserves retryable state. Copilot additionally retains upstream history but its exhausted explicit re-import honors the local tombstone. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: archive from the session list, read-only detail and archived listing, delete with and without worktree cleanup, refusals presented to the user, branch retained. |
| L4 Extended | Relay integration, every supporting production plugin: archive or delete with a live turn, pending requests, or a stopped plugin; competing archive/delete/mutation on one family; a second client observing retirement; shared worktree and forced retry; bridge restart between export and flip. |
| L5 Full | Headless bridge for unreadable or version-mismatched audit records, failed export, startup reconciliation, missing worktrees, and dirty or diverged repositories; packaged or external for released-client unarchive intent. Every supporting production plugin where backend export participates. |

## Exploration Guidance

Vary session shape: plain, with a dedicated worktree and branch, sharing a
worktree with another active session, and a family with children. Vary state at
retirement: idle, mid-turn, awaiting a request, or with its plugin stopped. Vary
the entry surface and worktree-cleanup choice, and alternate archive-then-delete
with direct deletion. Delete disposable sessions and remove any test worktrees
and branches that remain after the asserted cleanup behavior. For Copilot,
compare idle and active deletion, verify standard close when resident, then run
an exhausted explicit import and confirm the retained upstream row stays hidden.

## Failure Signals

- An archived session accepts a prohibited non-deletion mutation, or becomes
  unarchived by any path.
- An audit record is missing or unreadable, history is purged without a durable
  record, a partial export is recorded as complete, or an archived snapshot
  retains live prompt defaults.
- Deletion residue survives startup reconciliation without an observable failure
  and later retry, or cleanup removes a worktree or branch that was not requested.
- Copilot deletion removes private upstream files, omits the local tombstone, or
  lets a later explicit import recreate the deleted local session.
- A close-capable backend is closed while its prompt is still settling, emits
  late events after local removal, reports timeout/close failure as success, or
  a late session upsert makes a deleting or deleted session visible again.
- Unsafe cleanup proceeds without a forced retry, a refusal omits the blocking
  issues, session retirement deletes a branch, partial cleanup is reported as
  success or deletes the session, a concurrent mutation interleaves, or a client
  presents archiving as reversible.

## Known Limitations

- Archiving is intentionally irreversible; deletion additionally destroys the
  audit record. The read-only rule covers the named session only, not ancestors,
  descendants, or related sessions.
- Exporting stale history may start the bound plugin for one final backfill, and
  the completed archive sends a best-effort backend notification. A stopped
  plugin being touched during archive is therefore expected behavior.
- A history purge failing after a successful archive is left to the next startup
  reconciliation rather than failing the archive.
- A history purge failing after session-row deletion is logged and leaves storage
  residue for startup reconciliation rather than failing the deletion.
- Attachment behavior here will change with unfinished lazy stored-image work.
- Hermes exposes no ACP close or delete operation. Sesori purges its own row and
  transcript and retains a plugin-scoped tombstone, but the corresponding ACP
  row can remain in Hermes storage until upstream provides a supported deletion
  surface; later import must not resurrect it.
- DeepSeek standard close cancels and drains a live resident session but retains
  adapter persistence because the pinned upstream owner has no delete API. Sesori
  purges its database, transcript, and requested worktree state and retains a
  plugin-scoped tombstone; it never infers and deletes private JSONL or attachment
  paths. A later explicit import must not resurrect the retained adapter row.
- Copilot's pinned CLI likewise has close but no delete/archive method. Its
  history can remain in the user's normal Copilot home after local deletion;
  Sesori's tombstone prevents re-import without inspecting or deleting that data.

## Sources

Bridge session lifecycle, deletion, archived-validator, and mutation dispatch
services; chat-history export and purge; archived-record completeness model;
worktree service; shared cleanup rejection model; OMP cleanup service; shared
ACP close/tombstone behavior used by Copilot; client list/detail surfaces.
