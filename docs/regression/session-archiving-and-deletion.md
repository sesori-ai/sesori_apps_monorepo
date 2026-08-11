# Session Archiving And Deletion

## Capability

A session can be retired permanently as a read-only audit record, or removed
entirely along with its transcript and, optionally, its worktree and branch.

## Required Behavior

- Archiving is final. An archived session can never be unarchived, prompted, or
  mutated; every attempt is refused with the same archived read-only rejection,
  evaluated on the session the caller named.
- Archiving exports a versioned transcript audit record before the session flips
  to archived, then purges live history for it. When backend history is
  unavailable the export may proceed from stored content only and must record
  that honestly, never claiming completeness it lacks. The archived session
  stays readable through the same history path, served from that record.
- Deletion removes the session, its history, its spilled content, and its archive
  record; it is destructive and not recoverable. Worktree and branch cleanup
  happens only when requested; unsafe cleanup (unstaged changes, branch mismatch,
  shared worktree) is refused with its issues and proceeds only on a forced retry.
- A failed cleanup never half-deletes: the rejection is reported or the operation
  fails visibly, orphaned storage is reclaimed by a later reconciliation, and
  both flows serialize against concurrent mutations of the same session family.
- Clients present archiving as permanent, hide mutation affordances there, and
  list archived sessions.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, one representative plugin: a session archives, stays readable, and refuses a later mutation. |
| L2 Routine | Headless bridge, representative: deletion removes the session, its history, and its archive record; export and purge observed as a pair with honest completeness; cleanup rejection issues reported without deleting anything. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: archive from list and detail, read-only detail and archived listing, delete with and without worktree/branch cleanup, refusals presented to the user. |
| L4 Extended | Relay integration, every supporting production plugin: archive or delete with a live turn, pending requests, or a stopped plugin; competing archive/delete/mutation on one family; a second client observing retirement; shared worktree and forced retry; bridge restart between export and flip. |
| L5 Full | Headless bridge for unreadable or version-mismatched audit records, failed export, startup reconciliation, missing worktrees, and dirty or diverged repositories; packaged or external for released-client unarchive intent. Every supporting production plugin where backend export participates. |

## Exploration Guidance

Vary session shape: plain, with a dedicated worktree and branch, sharing a
worktree with another active session, and a family with children. Vary state at
retirement: idle, mid-turn, awaiting a request, or with its plugin stopped. Vary
the entry surface and cleanup choices, and alternate archive-then-delete with
direct deletion. Delete disposable sessions and remove any test worktrees and
branches that remain after the asserted cleanup behavior.

## Failure Signals

- An archived session accepts a mutation, or becomes unarchived by any path.
- An audit record is missing or unreadable, history is purged without a durable
  record, or a partial export is recorded as complete.
- Deletion leaves history, spilled content, or an archive record behind, or
  removes a worktree or branch that was not requested.
- Unsafe cleanup proceeds without a forced retry, a refusal omits the blocking
  issues, a concurrent mutation interleaves, or a client presents archiving as
  reversible.

## Known Limitations

- Archiving is intentionally irreversible; deletion additionally destroys the
  audit record. The read-only rule covers the named session only, not ancestors,
  descendants, or related sessions.
- A history purge failing after a successful archive is left to the next startup
  reconciliation rather than failing the archive.
- Attachment behavior here will change with unfinished lazy stored-image work.

## Sources

Bridge session lifecycle, deletion, archived-validator, and mutation dispatch
services; chat-history export and purge; archived-record completeness model;
worktree service; shared cleanup rejection model; client list/detail surfaces.
