# Internal Chat History Store

## Status

- **Plan slug:** `internal-chat-history`
- **Status:** Active — plan raised, implementation not started
- **Plan date:** 2026-08-06 (revised 2026-08-06 after comparison with the
  parallel `session-history-store` draft, PR #764; its superior mechanisms
  were merged into this plan and that draft is superseded)
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Base:** `main` at `232974e1`
- **Prerequisite:** the `read-only-archiving` plan lands and merges fully
  first. It removes unarchive end to end and makes archived sessions
  read-only; this plan builds its archive export/purge on that permanence
  guarantee and contains no unarchive-removal work itself.

## Goal

Make the bridge the fast, durable source of session chat history instead of
re-fetching it from the backend plugin on every read; paginate delivery to
the client; and, on archive, export the transcript to a versioned on-disk
audit file and purge it from the database.

## Success Criteria

1. Opening a previously synced session serves messages from the store without
   starting the plugin backend, for all current backends.
2. A live session's streamed messages and parts are queryable from the store
   immediately after they finalize, matching what a plugin history fetch
   would return (same visibility filtering and 500-rune tool-output bound).
3. A session advanced outside Sesori (for example via the backend CLI) still
   shows complete history: the bridge detects staleness and falls back to the
   plugin fetch, then re-caches.
4. New clients request the latest N messages and page older ones on demand;
   old published apps receive the full transcript exactly as today.
5. Archiving exports a complete transcript to a versioned audit file, purges
   the session's history rows and spill files from the live store, and the
   archived session remains readable through the same messages route.
6. No database table ever stores base64 payloads; inline attachments
   round-trip through spill files and still render on the client — live, from
   store, and from archive.
7. Deleting a session also purges its history rows, spill files, and archive
   file.
8. The 25 GB-class backend databases are never imported wholesale: backfill
   is lazy, per-session, on first read.

## Why Now (observed problems)

- Opening a session **cold-starts an idle backend** purely to read history:
  `SessionRepository.getSessionMessages`
  (bridge/app/lib/src/bridge/repositories/session_repository.dart:379) uses
  `PluginRuntime.use` with `startIfNeeded: true`. Plugins idle-suspend after
  10 minutes, so this is the common path.
- Plugin history reads are slow by construction:
  - Codex: blocking `readAsLinesSync()` of the whole rollout `.jsonl` plus a
    full lifecycle replay, on every open
    (bridge/sesori_plugin_codex/lib/src/api/codex_rollout_api.dart:144).
  - ACP/Cursor: spawns a dedicated replay process, `session/load` with a
    2-minute timeout and a fixed 250 ms–6 s drain, per open
    (bridge/sesori_plugin_acp/lib/src/acp_plugin.dart:1285).
  - OpenCode: HTTP to the local server; the user's OpenCode DB has grown to
    25 GB and reads degrade with it.
- The **entire transcript ships in one relay frame** (`POST
  /session/messages`, `MessageWithPartsResponse`), inline base64 images up to
  5 MiB each, no pagination, relay frame ceiling 64 MiB. The client re-fetches
  that full snapshot on reconnect, resume, and staleness signals, so the cost
  is paid repeatedly.
- Nothing bounds bridge DB growth today; inline base64 in SQLite would bloat
  `sesori.db` badly.

## Decisions (user-confirmed)

1. **Archive transcripts leave the database permanently.** Archiving (already
   permanent and read-only after the `read-only-archiving` series) exports a
   versioned audit file and purges the live rows. Session metadata rows stay
   in `sesori.db` so archived sessions remain listed.
2. **Attachment bytes live on disk, never in a database.** Inline base64 from
   plugins is decoded once and written to spill files; stored JSON carries an
   internal reference; the wire contract is unchanged.
3. **Tool output stays plugin-truncated (500 runes).** The store persists
   what plugins already return; no fidelity change.
4. **Backfill is lazy and per-session.** Nothing ever iterates a backend's
   own storage wholesale.
5. **Live history lives in a separate `chat_history.db`**, not in
   `sesori.db`. Keeps the main DB small, isolates WAL churn, and makes
   reclamation after purge cheap. No cross-database foreign keys.

## Excluded Scope

- Client-side persistence or offline cache.
- Persisting streaming deltas (`message.part.delta` stays transient; the full
  part snapshot from `message.part.updated` is what is stored).
- Proactive backfill of all existing sessions or any import of backend
  databases.
- New SSE event types or changes to the client's reload triggers (owned by
  the separate `session-refresh-reconnects` assessment).
- Trimming what non-message data the session snapshot sends (explicitly
  deferred by the user).
- Compression of archive files, retention windows for active-session
  history, content-hash dedup across sessions.
- Changes to the `BridgePluginApi.getSessionMessages` contract — it remains
  the backfill source, including its empty-vs-throw distinction.
- Unarchive removal and read-only enforcement — owned by the prerequisite
  `read-only-archiving` plan.
- Product analytics: no new authoritative user action is introduced
  (pagination and storage are transparent; archive is an existing action).

## Architecture

Touched workspaces: `bridge/app`, `client/module_core` + `client/app`,
`shared/sesori_shared`.

### Storage layout (all under the account data directory, chmod 700)

```
<dataDir>/sesori.db                                  — existing main DB
<dataDir>/chat_history.db                            — NEW: live transcripts
<dataDir>/history/attachments/<sessionId>/<sha256>   — NEW: attachment spill files
<dataDir>/archive/<sessionId>.json                   — NEW: archive audit files
<dataDir>/archive/attachments/<sessionId>/<sha256>   — NEW: archived spill files
```

### `chat_history.db` schema (new Drift database, `ChatHistoryDatabase`)

Separate `@DriftDatabase` class beside `AppDatabase`
(bridge/app/lib/src/api/database/history/), own `schemaVersion` starting at
1, own step-by-step migrations and schema snapshots, same file hardening as
`sesori.db` (0600, WAL, foreign_keys ON) plus `auto_vacuum = INCREMENTAL`
set at creation. `sessionId` is a plain TEXT key referencing the main DB
logically; cross-store consistency is owned by a dedicated startup service
(see Reconciliation).

Tables:

- `history_messages` — PK `{session_id, message_id}`; columns `seq`
  (per-session monotonic int, the pagination cursor), `info_json` TEXT
  (shared `Message` JSON), `updated_at`. Unique index `(session_id, seq)`.
  No other wire-model fields are extracted into columns; nothing queries by
  role.
- `history_parts` — PK `{session_id, message_id, part_id}`; columns
  `order_index`, `part_json` TEXT (shared `MessagePart` JSON with inline
  attachments spilled), `updated_at`. Index
  `(session_id, message_id, order_index)`.
- `history_sync_state` — PK `{session_id}`; columns `watermark` (ms),
  `backend_activity_at` (ms — the staleness comparison target, advanced only
  by observed backend activity, never by bridge-local metadata writes; see
  Staleness), `synced_at` (nullable — set only by a completed backfill; a row
  with null `synced_at` was created by live capture and is not a complete
  transcript).

Rationale for JSON-in-TEXT over columnar parts: messages and parts are
display payloads; the only queries are "by session, ordered, paged".
Persisting the shared wire model (which already has tolerant freezed
`fromJson`: nullable fields, `include_if_null: false`, attachment
`fallbackUnion`) avoids a second schema chasing the wire model. Only
ordering/identity columns are extracted. Precedent:
`session_options_cache_table`, encode/decode owned by the repository layer.

`seq` assignment: a backfill transaction **replaces** the session's rows,
numbering messages in transcript order (the backend's authoritative
ordering), and **re-appends any already-stored rows absent from the
transcript** — live events newer than the fetch — above the imported maximum,
preserving their relative order. Live capture appends `max(seq) + 1` for a
new message id and updates in place for a known one. Both run through the
same per-session write queue, so backfill and capture never interleave
mid-transaction; the re-append rule means no captured message is lost and
keyset order stays consistent regardless of interleaving.

### Attachment spill files

Owned by a Layer-1 `AttachmentSpillStorage` (dep: data-directory path).
Content-addressed file names — sha256 of the decoded bytes — under a
per-session directory; writes are atomic (temp + rename, chmod 600, following
`AppOnboardingStateStorage.writeMarker`) and idempotent; purge removes the
session directory.

Base64↔file mapping is owned entirely by `ChatHistoryRepository` (Layer 2).
On persist, it decodes each `MessageAttachmentInlineImage`, writes the bytes
via `AttachmentSpillStorage`, and stores the part JSON with the inline
variant replaced by an internal `stored_file` reference (mime, filename,
sha256, byte length) that **never crosses the wire**. On serve, it rehydrates
to the existing wire `inline_image` variant; a missing spill file degrades to
the existing `metadata` variant instead of failing the read. No attachments
table: the reference lives inside the part JSON, so the part reconstructs
exactly, including tool-state attachment lists.
`ponytail:` re-inlining base64 caps page payload size; upgrade path is an
on-demand attachment fetch route (storage already supports it).

### Bridge layering (mirrors `SessionOptionsCache*`; wired in
`Orchestrator.create()`)

```
ChatHistoryDatabase + ChatHistoryDao   (API — dumb queries, seq queries,
                                        purge, incremental_vacuum execution)
AttachmentSpillStorage                 (API — spill file IO)
ArchivedSessionStorage                 (API — audit-file IO, quarantine)
ChatHistoryRepository                  (Repository — aggregates the three
                                        APIs; owns DTO/JSON mapping,
                                        base64↔file mapping, archive
                                        export/read mapping, purge of rows +
                                        spills + archive file as one
                                        operation set, typed errors; no
                                        dependency on other repositories)
ChatHistoryService                     (Service — capture writes, staleness
                                        policy, pagination, backfill, archive
                                        export/purge coordination, per-session
                                        write queue; deps:
                                        ChatHistoryRepository +
                                        SessionRepository)
ChatHistoryReconcileService            (Service — startup consistency; deps:
                                        SessionRepository +
                                        ChatHistoryService; mutates only
                                        through ChatHistoryService)
ChatHistoryListener                    (Consumer — live capture)
Handlers                               (Consumer — wire)
```

No class outside Layer 1 touches files or PRAGMAs. No
`BridgePlugin`/`PluginRuntime` reference appears in `ChatHistoryService`; the
plugin fetch goes through the existing `SessionRepository.getSessionMessages`.

### Write paths into the store

1. **Live capture (primary).** A new
   `ChatHistoryListener(source: sessionEventDispatcher.events, ...)` in
   `bridge/app/lib/src/listeners/`, constructed and started by
   `Orchestrator.create()` alongside `SessionDeletionListener`
   (bridge/app/lib/src/bridge/orchestrator.dart:491), owning its own
   subscription and `dispose()`. It consumes events after
   `SessionEventService` normalization — after backend→bridge id translation,
   generation fencing, and unbound-event parking
   (bridge/app/lib/src/bridge/repositories/mappers/session_event_mapper.dart:155).
   Persists on `message.updated`, `message.part.updated`,
   `message.part.removed`, `message.removed`; ignores deltas. Each applied
   event advances the session's `watermark` via an upsert on
   `history_sync_state`: capture **creates the sync row if absent** (with
   `synced_at` null — rows exist but the session has never been backfilled)
   and advances `watermark`/`backend_activity_at` on it either way. Only a
   completed backfill sets `synced_at`; the store is served without a plugin
   fetch only when `synced_at` is set and the watermark is current, so
   capture-created rows never masquerade as a complete transcript. Writes
   are upserts keyed by id, serialized per session through a simple
   sequential queue inside the service; capture never starts a plugin and
   never blocks the event pipeline. **Failure policy:** a failed capture
   write is logged with full context and **clears `synced_at`**, so the next
   read falls back to the plugin and re-backfills — self-healing, no retry
   queue.
2. **Lazy backfill.** On a read where the store is missing or stale (below),
   `ChatHistoryService` calls the existing
   `SessionRepository.getSessionMessages` (the only place that touches the
   plugin runtime; may start the backend), then atomically replaces the
   session's rows, spills attachments, sets the `watermark` to the
   `backend_activity_at` value observed **before** the fetch, and serves.
   Concurrent reads
   for the same session await the same in-flight backfill future. A backfill
   failure propagates as the same typed error the route returns today (a
   cache miss must not masquerade as an empty thread) and leaves `synced_at`
   unset for retry on next open. An empty transcript **is** a valid synced
   state, distinct from failure.

### Staleness (externally advanced sessions)

Serving prefers the store only when the sync row has `synced_at` set and the
`watermark` is at or ahead of the session's **backend-activity timestamp**. That timestamp
is deliberately **not** the catalog `updated_at`: bridge-local metadata
writes move `updated_at` (`setSessionTitleIfStored` writes `DateTime.now()`
on rename, `archiveStoredSession` writes the archive time), and comparing
against it would mark the store stale — and cold-start the backend — after an
ordinary rename, defeating Success Criterion 1. Instead the comparison input
is advanced only by observed backend activity: live message events (capture
already advances the watermark alongside it) and catalog import observing
newer backend activity for the session. Concretely, `history_sync_state`
gains the comparison target as data owned by this feature (`ChatHistoryService`
advances it from the two sources above); no `SessionDao` metadata writer
participates. Sessions advanced outside Sesori (backend CLI/TUI) are caught
whenever catalog import observes the newer backend activity. A bounded race
(activity observed before the capture write lands) at worst causes one
unnecessary plugin fallback and is accepted as self-healing. Pinned by a
step-4 test: rename a synced session, reopen, assert no plugin fetch.

### Serving

`GetSessionMessagesHandler` routes through one `ChatHistoryService` read
method (handlers do no file IO, no `fromJson`, no source decision):

1. Archived session → repository reads the audit file, rehydrates
   attachments, serves (pagination sliced in memory — archived reads are rare
   audit views). The audit file persists each message's `seq`, so the cursor
   domain is identical to the store path.
2. Store fresh → serve from store, rehydrate attachments, apply pagination.
3. Otherwise → lazy backfill (above), then serve **the requested page from
   the freshly populated store with a `nextCursor`, exactly like the store
   path** — one cursor domain and one response shape across all three paths.

### Pagination (additive fields on the existing route)

`POST /session/messages` decodes a new `SessionMessagesRequest`
(`sessionId`, optional `limit`, optional `before` — a `seq` cursor) that
supersedes `SessionIdRequest` for this route; the JSON stays a superset, so
older peers are unaffected. `MessageWithPartsResponse` gains an optional
`nextCursor`. Omitted `limit` returns the full transcript (today's
behavior). The cursor is **exclusive**: a page is the latest `limit`
messages with `seq` strictly below `before` (omitted `before` = start from
the newest), with all their parts, oldest-first within the page.
`nextCursor` is the oldest returned `seq`, passed back verbatim as the next
`before` — no boundary duplication, unambiguous page merging.

- Old app + new bridge: no `limit` sent → full transcript, unchanged.
- New app + old bridge: unknown request fields ignored by generated
  `fromJson`; full list returned without `nextCursor`; absence of
  `nextCursor` means complete — the client shows no load-older affordance.
  No 404 probing, no capability detection.

Client layers, explicitly: `SessionApi.getSessionMessages` sends the new
request fields (Layer 1, transport only) → `SessionRepository` passes
`limit`/`before` through and returns the page plus `nextCursor` (Layer 2) →
`SessionDetailLoadService` requests the latest page for the initial snapshot
(Layer 3, paging policy) → `SessionDetailCubit` owns page-merge state
(loaded range, `nextCursor`, load-older in flight) and exposes a load-older
action calling the service (Layer 4; no cubit talks to the API layer).
Existing by-id SSE patching is kept (a part update for a not-loaded older
message no-ops, which is already today's behavior). A reload re-requests the
latest page; behavior for previously paged-back history is pinned by test.

### Archiving (export + purge)

The `read-only-archiving` series has already made archive permanent and
read-only. This plan adds, in `SessionLifecycleService._doArchive`, sequenced
**export → worktree cleanup → flip → purge** (no `dart:io` or JSON decoding
in `SessionLifecycleService`):

1. **`ChatHistoryService.exportSessionHistory(...)`** — called **before**
   both `_cleanupIfNeeded` and the repository archive flip. The export's
   "bring the store current" fetch may need the session's worktree:
   directory-scoped backends replay from the stored session directory
   (`_primeDerivedSessionDirectory`,
   bridge/app/lib/src/bridge/repositories/session_repository.dart:375), so
   exporting after worktree removal would silently archive a truncated
   transcript under the log-and-proceed policy. Export therefore runs first;
   a cleanup rejection after a successful export leaves only a harmless
   orphan audit file (overwritten on the next attempt). The export first
   brings the store current (the serving staleness rule; may start the
   backend one last time). If the plugin
   cannot provide history — a failure or an unsupported backend — the export
   **proceeds with whatever the store holds** and the limitation is logged
   with context: archiving never modifies backend storage, so the backend's
   own copy survives, and refusing to archive would trap the session. The
   envelope records this honestly in a non-null `completeness` enum field
   (`complete` / `storeOnly` — the backend could not be consulted), so the
   audit record never silently claims completeness it does not have; the
   archived read path logs `storeOnly` on access. Surfacing the marker in
   the client UI is deliberately deferred until evidence it matters. On
   success the repository (via `ArchivedSessionStorage`) writes
   `archive/<sessionId>.json` atomically and **copies** the session's spill
   files to `archive/attachments/<sessionId>/` (idempotent, content-addressed
   names; the live copies are deleted later by the post-flip purge, so a
   crash before the flip leaves the active session's spill files intact and
   attachments keep rendering). Persisted envelope: a freezed
   `ArchivedSessionFileDto` in `bridge/app/lib/src/api/models/` with
   `schemaVersion` (int, 1), `archivedAt` (ms), `session` (a freezed
   `ArchivedSessionSnapshotDto` capturing the main-DB session metadata: ids,
   project, directory, branches, agent/model, timestamps, title), and
   `messages` as a list of per-message entries each carrying `seq` plus the
   `MessageWithParts` JSON, with attachments as `stored_file` references into
   the archived spill directory. Persisting `seq` keeps the archived
   pagination cursor in the same domain as the live store; the v1 fixture
   pins it. Only a storage-level write failure fails the archive (typed
   error; session stays active with its live store intact).
2. The existing worktree/branch cleanup (`_cleanupIfNeeded`), then the
   repository archive flip (`archiveStoredSession`).
3. **`ChatHistoryService.purgeSessionHistory(...)`** — after the flip; one
   `chat_history.db` transaction deletes the session's messages, parts, and
   sync row; the live spill directory is then removed (bytes already copied
   to the archive) and the DAO runs `incremental_vacuum`. A purge failure is
   logged and left to the startup reconcile; the archive itself has already
   succeeded.

Reader discipline: the repository checks `schemaVersion` and refuses only a
major version above what it supports; unknown fields are ignored (freezed
`fromJson`); corrupt files are quarantined (renamed with a `.corrupt-` suffix)
following the `CodexToolOutcomeStorage` pattern
(bridge/sesori_plugin_codex/lib/src/api/codex_tool_outcome_storage.dart), and
a v1 fixture round-trip test pins the format.

Ordering guarantees: audit-file write + spill copy → worktree cleanup →
main-DB archive flip → DB purge (incl. live spill deletion). A crash (or
cleanup rejection) after the export but before the flip leaves an orphan
audit file and duplicated spill bytes for an active session (harmless — the
live store and its spill files are untouched, attachments keep rendering;
the next archive attempt overwrites idempotently). A crash after the flip
but before the purge leaves duplicate data (file + rows + both spill
copies), resolved at startup by the reconcile service. Bounded transient
duplication is accepted.

### Deletion

`SessionDeletionService` coordinates the two stores side by side: it calls
`SessionRepository.deleteSession` as today and additionally calls
`ChatHistoryService` to purge history rows, spill files, and the archive
file for every session in the deleted subtree. `SessionRepository` gains no
history dependency.

### Reconciliation (one owner)

`ChatHistoryReconcileService` — a startup peer of
`DeletedSessionStorageCleanupService`, invoked from `bridge_runtime_runner`
before relay traffic. Deps: `{required SessionRepository sessionRepository,
required ChatHistoryService chatHistoryService}` — it reads session identity
from the main DB but performs **every mutating step through
`ChatHistoryService`**, which remains the single write owner of
`chat_history.db` and its files (all three purge triggers — archive,
deletion, reconcile — funnel through the same per-session write queue). It
decides all cross-store consistency:

1. Purge chat rows, spill directories, and archive files whose bridge
   `sessionId` has no session row in the main DB (session deleted while the
   bridge was down or inline cleanup failed). Archived sessions keep their
   metadata row, so row existence is the mapping; deletion tombstones (keyed
   by backend session id) are not needed here.
2. Re-purge chat rows for sessions marked archived in the main DB that
   already have a valid audit file (crash between flip and purge).

Introduced in PR step 3 (rows/spills behavior) and extended in step 6
(audit-file behaviors).

## Size And Maintenance

- Purge-on-archive is the primary size control for `chat_history.db`;
  `auto_vacuum = INCREMENTAL` from day one plus a DAO-run
  `incremental_vacuum` after purge returns space without a full VACUUM. No
  scheduler.
- No TTL/pruning for active sessions: text-only rows (attachments spilled,
  tool output truncated) are small. Revisit only with evidence of growth.
- Audit files and archived spill directories are bounded by the user's own
  archive volume; they are plain files the user can inspect or delete.

## Evidence And Proportionality

- Slow opens, backend cold-starts, and 25 GB backend DBs are **observed**
  failures — the store, pagination, and purge-on-archive address them.
- The staleness watermark is the coarsest mechanism that keeps externally
  advanced sessions correct; no per-message reconciliation or content
  hashing. The capture/catalog watermark race is accepted as bounded and
  self-healing (one redundant plugin fetch).
- Capture-failure handling (clear `synced_at` → re-backfill) replaces any
  retry queue or export ledger.
- Archive export failure handling is deliberately log-and-proceed because
  backend storage still holds the source; only storage write failures block.
- Per-session write serialization addresses the ordinary flow of live events
  racing a backfill; resolved with atomic replace + per-session queue, not
  global locks.
- Crash-between-flip-and-purge is a theoretical narrow window; handled by an
  idempotent startup reconcile. No journaling machinery.

## Cleanup Assessment

- **Removed by this work:** the plugin round-trip in the ordinary
  `getSessionMessages` path (its body moves behind the history service; no
  dead code remains).
- **Kept:** `plugin.getSessionMessages` interface (backfill source),
  plugin-side truncation and attachment normalization,
  `notifySessionArchived` best-effort backend call.
- Unarchive cleanup already happened in the `read-only-archiving` series.
- No other obsolete artifacts found.

## PR Series

Soft cap 1,500 changed lines per PR (additions + deletions, including
generated code and tests). Step 2 introduces a new Drift database whose
generated code cannot be split from the schema defining it; an overage is
expected and recorded here as unavoidable.

| Step | Exact PR title | Estimate | Boundary |
|---|---|---:|---|
| 1/8 | `🌱 [internal-chat-history] Raise plan [step 1/8]` | 400–700 | This plan and tracker. |
| 2/8 | `🚧 [internal-chat-history] Introduce the chat history database [step 2/8]` | 1,500–2,600 | `ChatHistoryDatabase`, tables, DAO, `AttachmentSpillStorage`, `ChatHistoryRepository`, the purge surface of `ChatHistoryService` (the single write owner exists from day one), orchestrator wiring and ordered close; production consumer: `SessionDeletionService` purges history/spills for deleted subtrees through `ChatHistoryService`. |
| 3/8 | `🚧 [internal-chat-history] Capture live message events and backfill lazily [step 3/8]` | 900–1,400 | `ChatHistoryService` capture/backfill/watermark surfaces, `ChatHistoryListener`, `ChatHistoryReconcileService` (rows/spills), failure policies, tests. |
| 4/8 | `⚙️ [internal-chat-history] Serve session messages from the store [step 4/8]` | 700–1,100 | Store-first serving with staleness fallback; attachment rehydration; wire shape unchanged; empty-vs-error semantics pinned. |
| 5/8 | `⚙️ [internal-chat-history] Paginate session messages [step 5/8]` | 600–1,000 | `SessionMessagesRequest`/`nextCursor` shared fields, bridge paging over `seq`, compatibility tests both directions. |
| 6/8 | `🚧 [internal-chat-history] Export archives and purge history on archive [step 6/8]` | 1,000–1,500 | `ArchivedSessionStorage`, export → cleanup → flip → purge sequencing, archived read path (`seq`-cursor from the audit file), incremental vacuum, reconcile audit-file behaviors, delete-path archive cleanup. |
| 7/8 | `🌿 [internal-chat-history] Load history pages on demand in the client [step 7/8]` | 500–900 | Latest-page initial load, load-older affordance, complete-when-no-cursor, page-merge cubit state, tests. |
| 8/8 | `🌱 [internal-chat-history] Retire plan [step 8/8]` | 50–150 | Move plan to `.plan/completed/`. |

Steps merge in numeric order; each PR is independently valid at its base.
Bridge serving (4) precedes the wire change (5); archived reads (6) reuse the
serving path; the client adopts paging last (7) against a bridge that already
serves both shapes.

## Verification

- Per-PR: owning-package tests + analyzer; migration verifier fixtures for
  the new DB (as `bridge/app/test/drift/`); CI runs the matrix.
- Step 3: capture tests — out-of-order part-before-message arrival, removal,
  watermark movement, capture-failure sync-row drop; backfill idempotency —
  transcript via backfill then live events (and reversed) yields identical
  rows and consistent `seq` order; spill idempotence (same bytes → one file).
- Step 4: golden comparison — store-served response equals plugin-served
  response for fixture transcripts; externally-advanced staleness fallback;
  rename a synced session, reopen, assert no plugin fetch; empty-thread stays
  a valid synced state distinct from fetch failure.
- Step 5: old-shape request decodes; unknown fields ignored; paging
  boundaries (exact page, last page, empty session).
- Step 6: export/read round-trip including attachments; v1 fixture pin;
  crash-window test (file exists, rows present → re-purge clean); quarantine
  on corrupt file.
- Step 7: page merge with live events; reload semantics pinned by test.
- Manual: open a large Codex/ACP session before/after step 4 — no backend
  start, sub-second load.

## Material Risks

| Risk | Mitigation |
|---|---|
| Store silently diverges from backend truth. | Staleness watermark prefers the plugin fetch whenever observed backend activity is ahead; capture write failures clear `synced_at` forcing re-backfill; backfill renumbers from the authoritative transcript, re-appending only live rows newer than the fetch. |
| Archive purge loses the only copy of a transcript. | Export is atomic and committed before purge; archiving never touches backend storage; crash between flip and purge re-purges idempotently with the file already durable. |
| Archive files unreadable after model evolution. | Payloads are wire-model JSON with the wire's tolerant-reader discipline; `schemaVersion` gates incompatible changes; corrupt files quarantined, not deleted; v1 fixtures pinned by test. |
| New Drift DB codegen blows up review budget. | Isolated in step 2 with the overage recorded; only delete-purge behavior beyond schema in that PR. |
| Capture floods the DB during fast token streaming. | Deltas never persisted; only bounded full part snapshots, serialized per session. |
| Spill directory and rows drift apart. | Content-addressed idempotent writes; purge removes the per-session directory; missing file degrades to `metadata` instead of failing the read. |
| Legacy full-transcript requests stay unbounded until apps adopt paging. | Unchanged from today's exposure, now served from the store without a backend start. |

## Plan Review Record

- 2026-08-06 — `architecture-plan-review` (sub-agent) rejected the first
  draft with nine findings (layer skips in service/handlers, unowned
  file-IO and reconcile responsibilities, ambiguous listener seam, missing
  client layers, attachment slot fidelity, untyped archive envelope). All
  were applied directly.
- 2026-08-06 — PR #763 bot review findings applied: export-before-flip
  ordering, split export/purge service methods, row-existence mapping for
  audit-file reconcile, transcript-order `seq` reassignment on backfill.
- 2026-08-06 — Comparison with the parallel `session-history-store` draft
  (PR #764): adopted its watermark staleness rule, additive pagination
  fields on the existing route (dropping the new-route + 404 fallback),
  in-JSON `stored_file` attachment references with content-addressed spill
  files (dropping the `chat_attachments` table and slot discriminator),
  capture-failure sync-row drop, log-and-proceed archive export, success
  criteria, and per-step estimates. Retained from this plan: the dedicated
  reconcile service, the typed freezed archive envelope with quarantine, and
  the dated compatibility comment. Unarchive removal and the read-only gate
  moved to the prerequisite `read-only-archiving` plan per user direction.
- 2026-08-06 — PR #763 bot review of the revision, six findings applied:
  backfill re-append semantics restored (live rows absent from the
  transcript survive above the imported maximum), sync-row lifecycle defined
  (capture creates rows with null `synced_at`; only backfill sets it;
  failures clear it), archive envelope gains an honest `completeness`
  marker for store-only exports, spill files copied at export and deleted
  at purge (no attachment loss in the pre-flip crash window), exclusive
  pagination cursor (no boundary duplication), `ChatHistoryService` purge
  surface moved into step 2 so the single write owner exists before its
  first consumer.
- 2026-08-06 — `architecture-plan-review` (sub-agent) of the revised plan
  rejected with five findings: reconcile bypassing the single write owner
  (now mutates through `ChatHistoryService`), staleness compared against a
  timestamp moved by bridge-local metadata writes (now a dedicated
  `backend_activity_at` advanced only by observed backend activity), export
  unsequenced against worktree cleanup (now export → cleanup → flip →
  purge), inconsistent cursor domains across serving paths (now one `seq`
  domain everywhere, audit file persists `seq`, fallback serves a real
  page), and a consumer-less `role` column (dropped). All findings were
  applied directly; the corrected plan was not re-reviewed merely for
  approval.
