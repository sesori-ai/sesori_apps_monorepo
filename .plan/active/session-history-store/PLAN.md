# Session History Store

## Status

- **Plan slug:** `session-history-store`
- **Status:** Step 1/9 plan PR in preparation
- **Plan date:** 2026-08-06
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `232974e1`
- **Delivery:** one planning PR, seven sequential implementation PRs, and one
  plan-retirement PR — nine in total

## Goal

Make the bridge the fast, durable source of session chat history instead of
re-fetching it from the backend plugin on every read, and make archiving a
permanent, read-only, audit-only state whose transcript content leaves the
database entirely.

Concretely:

1. Chat history is persisted in a bridge-owned store, captured live from the
   existing event pipeline and lazily backfilled from the plugin only when the
   store is missing or stale.
2. Opening a session no longer cold-starts an idle backend in the common case.
3. `POST /session/messages` gains cursor pagination; older published apps keep
   receiving the full transcript unchanged.
4. Archiving becomes permanent: transcript rows are exported to a versioned
   on-disk archive file and purged from the database; the session row remains
   as the audit reference; unarchive is removed.
5. No base64 attachment payload is ever stored in a database. Inline image
   bytes are spilled to files and referenced.
6. The main `sesori.db` stays small: history lives in a separate database file
   with purge and incremental-vacuum behavior of its own.

## Success Criteria

1. Opening a previously synced session serves messages from the store without
   starting the plugin backend, for all current backends (OpenCode, Codex,
   Cursor/ACP) and the in-flight Claude Code plugin once it lands.
2. A live session's streamed messages and parts are queryable from the store
   immediately after the turn completes, matching what a plugin history fetch
   would return (same visibility filtering and 500-char tool-output bound).
3. A session advanced outside Sesori (for example via the backend CLI) still
   shows complete history: the bridge detects staleness and falls back to the
   plugin fetch, then re-caches.
4. New clients request the latest N messages and page older ones on demand;
   old published apps receive the full transcript exactly as today.
5. Archiving exports a complete transcript to a versioned archive file, purges
   the session's history rows and spills, and the archived session remains
   readable (from the file) through the same messages route.
6. `archived: false` requests are rejected with an explicit error; archived
   sessions reject prompt sends; the worktree-restore-on-unarchive path is
   deleted.
7. No table stores base64 payloads; inline attachments round-trip through the
   spill files and still render on the client, live, from store, and from
   archive.
8. Deleting a session also purges its history rows, spill files, and archive
   file.
9. The 25 GB-class backend databases are never imported wholesale: backfill is
   lazy, per-session, on first read.

## Current Behavior And Evidence

Observed failures motivating this plan (user-reported, reproducible):

- Session detail loads are very slow and degrade as backend databases grow;
  the user's OpenCode database is ~25 GB.
- Opening an idle session cold-starts the whole backend just to read history.

Code-level confirmation:

- `POST /session/messages` → `GetSessionMessagesHandler`
  (`bridge/app/lib/src/bridge/routing/get_session_messages_handler.dart`) →
  `SessionRepository.getSessionMessages`
  (`bridge/app/lib/src/bridge/repositories/session_repository.dart:379`) →
  `PluginRuntime.use(...)`, which starts the plugin generation if idle
  (`plugin_runtime.dart:1247`). Plugins stop after a 10-minute idle timeout
  (`bridge_settings.dart`), so history reads routinely pay a full backend
  start.
- The plugin interface method is all-or-nothing:
  `BridgePluginApi.getSessionMessages` returns the entire
  `List<PluginMessageWithParts>` with no cursor
  (`bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart:107`).
- The ACP/Cursor implementation spawns a fresh agent process per history read,
  with a 2-minute `session/load` timeout plus a 6-second quiet drain, and
  memoizes nothing (`bridge/sesori_plugin_acp/lib/src/acp_plugin.dart:1286`).
- There is no message persistence anywhere: the bridge database
  (Drift over sqlite3, `sesori.db`, schema v13,
  `bridge/app/lib/src/api/database/database.dart`) has no message table, and
  the client persists nothing durable at all.
- The client re-fetches the full snapshot frequently —
  `SessionDetailLoadService.load`/`reload` are the same full fetch, triggered
  on reconnect, app resume, and `command.executed`, debounced to one per 5
  seconds (`session_detail_cubit.dart:138`) — so the full-transcript cost is
  paid repeatedly, not once.
- Live events already flow through a single normalized, per-plugin serialized
  seam before wire delivery: `SessionEventDispatcher`
  (`bridge/app/lib/src/bridge/services/session_event_dispatcher.dart`) →
  `SessionEventService.normalize` → `SessionEventMapper.map` (backend→bridge
  session id translation, unbound events parked and re-driven). Generation
  fencing happens upstream in `PluginRuntime`. Tool output is bounded to 500
  chars at the plugin boundary (`plugin_message.dart:9`), so captured events
  match history-fetch fidelity.
- Archive state is bridge-owned already: `sessions_table.archived_at`, set via
  `PATCH /session/update/archive`
  (`update_session_archive_status_handler.dart`,
  `session_lifecycle_service.dart:152`). Unarchive exists today and re-creates
  worktrees (`worktree_service.dart:235` `restoreWorktree`). Archived chat
  detail still calls the live plugin; the composer is not gated.
- Inline images cross the wire as base64
  (`MessageAttachment.inlineImage`, ≤5 MiB decoded,
  `shared/sesori_shared/lib/src/models/sesori/message_part.dart`), so naive
  persistence of wire JSON would put base64 in the database.
- Precedents: `session_options_cache_table` stores serialized JSON payloads
  with a hand-constructed DAO; `deleted_sessions_table` holds permanent
  tombstones; migration 12→13 dropped and recreated a cache table instead of
  backfilling; `DeletedSessionStorageCleanupService` reconciles on-disk
  cleanup at startup with per-failure retry.

## Locked Scope And Product Decisions

### Included

- A second Drift database file, `sesori_history.db`, beside `sesori.db` in the
  Sesori data directory, owning message/part rows and per-session sync state.
- Live capture of normalized message events into the store; lazy per-session
  backfill from the plugin; staleness fallback to the plugin fetch.
- Attachment spill files under the data directory; an internal stored-file
  attachment representation that never crosses the wire.
- Cursor pagination on `POST /session/messages` via additive optional fields.
- Permanent read-only archiving: JSONL export, database purge, archive-file
  read path, unarchive rejection, prompt-send gate, deletion of the
  restore-on-unarchive machinery.
- History/spill/archive purge on session delete.

### Excluded

- Client-side persistence or offline cache.
- Persisting streaming deltas (`message.part.delta` remains transient; the
  full part snapshot from `message.part.updated` is what is stored).
- Proactive backfill of all existing sessions or any import of backend
  databases.
- New SSE event types, history-refresh push, or changes to the client's
  reload triggers (owned by the separate `session-refresh-reconnects`
  assessment).
- Trimming what non-message data the full session snapshot sends (explicitly
  deferred by the user).
- Compression of archive files, per-session database files, retention windows
  for active-session history.
- Changes to the `BridgePluginApi.getSessionMessages` contract — it remains
  the backfill source.
- Product analytics: no new authoritative user action is introduced
  (pagination and storage are transparent; archive is an existing action).

### Decisions

1. **Separate history database.** Message content grows without bound and has
   a different lifecycle (purge on archive/delete) than the small hot session
   catalog. A separate file keeps `sesori.db` queries fast, lets the history
   file use `auto_vacuum = INCREMENTAL` from day one, and keeps a runaway
   transcript from bloating the catalog. No cross-database foreign keys: the
   history store is keyed by bridge `session_id` strings and reconciled by
   explicit purge calls.
2. **Rows store shared wire-model JSON, not normalized columns.** Messages and
   parts are display payloads; the only queries are "by session, ordered,
   paged". Persisting serialized `Message`/`MessagePart` JSON (the exact serve
   format, which already has forward-compatible parsing: fallback unions,
   unknown-enum values, tolerated extra keys) avoids a large normalization
   surface and makes serving a cheap deserialize. Only ordering/identity
   columns are extracted. Precedent: `session_options_cache_table`.
3. **No base64 in any database.** Before persisting, inline attachment
   payloads are written to spill files
   (`<dataDir>/history/attachments/<sessionId>/<sha256>.<ext>`) and the stored
   JSON carries an internal `stored_file` reference. On serve, the bridge
   rehydrates to the existing wire `inline_image` variant; a missing spill
   file degrades to the existing `metadata` variant. The wire contract is
   unchanged.
4. **Archive is permanent and read-only.** Once archived, a session can never
   be restored or prompted. This makes purging its rows safe. The session row
   itself (identity, title, timestamps, `archived_at`) remains in `sesori.db`
   as the audit reference. `archived: false` returns an explicit error so
   older published apps that still render an Unarchive action get a clear
   failure instead of silent corruption.
5. **Archive files are versioned JSONL.** One file per session,
   `<dataDir>/archive/<sessionId>.jsonl`: a manifest line first
   (`{"v": 1, "type": "manifest", ...}`), then one line per message
   (`{"v": 1, "type": "message", "info": <Message JSON>, "parts": [<MessagePart
   JSON>, ...]}`). Payloads are the same shared wire shapes with the same
   compatibility discipline the wire already has (additive evolution, tolerant
   readers); a reader must skip unknown line types, ignore unknown fields, and
   refuse only a manifest major version above what it supports. Spill files
   move to `<dataDir>/archive/attachments/<sessionId>/`. Plain JSONL is chosen
   over a database or compressed format because archives are write-once,
   read-rarely, audit-oriented, and must stay readable years later without the
   then-current schema.
6. **Backfill is lazy and per-session.** The store is populated on first read
   of a session (or by live capture). Nothing ever iterates the backend's own
   storage wholesale.
7. **Staleness is decided by comparing catalog activity to the store
   watermark.** Serving prefers the store only when its watermark is at or
   ahead of the catalog row's `updated_at`; otherwise the existing plugin
   fetch runs and refreshes the store. Sessions advanced outside Sesori are
   caught whenever catalog import observes the newer backend activity. A
   bounded race (an event bumping the catalog before the capture write lands)
   at worst causes one unnecessary plugin fallback and is accepted as
   self-healing.

## Storage Design

### `sesori_history.db` (new Drift database, `bridge/app` API layer)

Created alongside `sesori.db` by the same data-directory bootstrap, WAL mode,
`auto_vacuum = INCREMENTAL` set at creation, its own `schemaVersion` starting
at 1 with the same `stepByStep` migration + schema-snapshot machinery as
`AppDatabase`.

- `history_messages` — PK `{session_id, message_id}`; columns `session_id`,
  `message_id`, `seq` (per-session monotonic int), `role`, `created_at?`,
  `completed_at?`, `info_json` (shared `Message` JSON), `updated_at`. Unique
  index `(session_id, seq)`.
- `history_parts` — PK `{session_id, message_id, part_id}`; columns
  `order_index`, `part_json` (shared `MessagePart` JSON, attachment spilled),
  `updated_at`. Index `(session_id, message_id, order_index)`.
- `history_sync_state` — PK `{session_id}`; `watermark` (ms), `synced_at`.

`seq` assignment: a backfill replaces the session's rows atomically and
numbers messages in canonical order; live capture appends `max(seq) + 1` for a
new message id and updates in place for a known one. The pagination cursor is
`seq`.

### Attachment spill store

`AttachmentSpillStorage` (Layer 1). Content-addressed file names (sha256 of
the decoded bytes) under a per-session directory; writes are idempotent;
purge removes the session directory. Files are created 0600 inside the
existing 0700 data directory, matching the database files' posture.

### Archive store

`SessionArchiveStorage` (Layer 1). Write-once JSONL per session as specified
in Decision 5, written atomically (temp file + rename) before the database
purge commits, so a crash between export and purge leaves a re-exportable
store, never a purged-but-unexported session.

## Architecture And Ownership

New classes, their layer, location, and constructor dependencies (all
required named parameters, wired exclusively by the `Orchestrator`
composition root):

- **Layer 1 (API)** — `bridge/app/lib/src/api/database/history/`:
  `HistoryDatabase` (Drift database, tables above, owns
  `auto_vacuum`/`incremental_vacuum` execution) and `SessionHistoryDao`
  (row access, seq assignment queries, purge, vacuum trigger).
  `bridge/app/lib/src/api/`: `AttachmentSpillStorage` (deps: data-directory
  path) and `SessionArchiveStorage` (deps: data-directory path). No class
  outside Layer 1 touches files or PRAGMAs.
- **Layer 2 (Repository)** — `bridge/app/lib/src/bridge/repositories/`:
  `SessionHistoryRepository` (deps: `SessionHistoryDao`,
  `AttachmentSpillStorage`, `SessionArchiveStorage`). Owns DTO/JSON mapping,
  attachment spill/rehydration, archive export/read mapping, and purge (rows,
  spills, archive file) as one operation set. It has no dependency on any
  other repository, and no existing repository gains a dependency on it.
- **Layer 3 (Service)** — `bridge/app/lib/src/bridge/services/`:
  - `SessionHistoryService` (deps: `SessionHistoryRepository`,
    `SessionRepository` — for the catalog watermark read and the existing
    plugin-fetch fallback path). Owns capture writes, staleness policy,
    pagination, backfill, archive export coordination, and purge
    coordination.
  - `ArchivedSessionGate` (deps: `SessionRepository`). The single read-only
    gate: prompt, question-reply, and permission-reply services call it and
    propagate its typed rejection; handlers only translate that rejection to
    the wire error.
- **Listener** — `bridge/app/lib/src/listeners/`: `SessionHistoryListener`
  (deps: `SessionHistoryService` plus the existing normalized event stream
  subscription), mirroring `PluginEventListener`'s shape.
- **Coordination changes to existing classes:** `SessionDeletionService`
  additionally calls `SessionHistoryService` purge beside
  `SessionRepository.deleteSession`; `SessionLifecycleService._doArchive`
  calls `SessionHistoryService` for the pre-export sync, export, and purge;
  `GetSessionMessagesHandler` calls `SessionHistoryService` instead of
  `SessionRepository`. `SessionRepository` itself gains no history
  dependency.
- **Shared wire model** — `SessionMessagesRequest` in
  `shared/sesori_shared/lib/src/models/sesori/` (fields: `sessionId`,
  optional `limit`, optional `before`); `MessageWithPartsResponse` gains
  optional `nextCursor`.

## Data Flow

### Live capture

`SessionHistoryListener` subscribes at the same point the SSE wire mapping
consumes normalized events (after `SessionEventMapper` id translation,
therefore after runtime generation fencing and unbound-event parking) and
forwards `message.updated`, `message.part.updated`, `message.removed`, and
`message.part.removed` to `SessionHistoryService`, which serializes writes
per session. Deltas are ignored. Capture also advances the session's
`watermark`.

Events for a session whose store has never been populated (no sync row) are
still applied; the first read reconciles via backfill if the catalog
watermark says the store is incomplete. Capture never starts a plugin and
never blocks the event pipeline; write failures are logged with context and
drop the sync row so the next read falls back to the plugin.

### Serving and backfill

`GetSessionMessagesHandler` routes through `SessionHistoryService`:

1. Archived session → read the archive file, rehydrate attachments, serve.
2. Store fresh (sync row present and `watermark >= catalog.updated_at`) →
   serve from store, rehydrate attachments, apply pagination.
3. Otherwise → existing plugin fetch (unchanged slow path), then atomically
   replace the session's store rows, spill attachments, set the watermark to
   the catalog `updated_at` observed before the fetch, and serve.

### Pagination

`POST /session/messages` decodes the new `SessionMessagesRequest` with
optional `limit` and `before` (a `seq` cursor); the response gains optional
`nextCursor`. Omitted `limit` returns
the full transcript (today's behavior). A page is the latest `limit` messages
at or below the cursor, with all their parts, oldest-first within the page.
Old bridge + new app: unknown request fields are ignored by generated
`fromJson`, the full list comes back without `nextCursor`, and the client
treats it as complete. The plugin-fallback path serves the full list (no
cursor) for simplicity; it is already the expensive path.

### Archive

`SessionLifecycleService._doArchive` calls `SessionHistoryService`, before
marking `archived_at`, to:

1. Best-effort store sync (step 3 of serving) so the export is complete. If
   the plugin cannot provide history, the export proceeds with whatever the
   store holds; the limitation is logged. The backend's own storage is never
   modified by archiving, so the source data still exists.
2. Atomically export the JSONL and move the spill files (both through
   `SessionHistoryRepository` → `SessionArchiveStorage`).
3. Purge the session's history rows and trigger incremental vacuum (through
   `SessionHistoryRepository` → `SessionHistoryDao`).

The lifecycle service never touches files or PRAGMAs itself.

`_doUnarchive`, `WorktreeService.restoreWorktree`, and the unarchive branch of
the handler are deleted; `archived: false` returns an explicit typed error.
The read-only rule lives in one place: the prompt, question-reply, and
permission-reply services consult `ArchivedSessionGate` and propagate its
typed rejection, which the handlers translate to the wire error.

### Delete

`SessionDeletionService` coordinates the two stores side by side: it calls
`SessionRepository.deleteSession` as today and additionally calls
`SessionHistoryService` to purge history rows, spill files, and the archive
file for every session in the deleted subtree. `SessionRepository` gains no
history dependency.

## Wire Compatibility

- `POST /session/messages`: additive optional request/response fields only;
  both directions degrade to today's full-transcript behavior. The new
  `SessionMessagesRequest` supersedes the shared `SessionIdRequest` for this
  route; the JSON stays a superset, so older peers are unaffected.
- `PATCH /session/update/archive` with `archived: false`: published apps can
  send this (they render Unarchive from `time.archived` alone), so the new
  bridge answers with an explicit error payload the existing client error
  path renders, not a silent no-op. The updated client removes the Unarchive
  affordances and warns that archiving is permanent before committing.
- Older bridge + newer app: the app must not offer "load older" pagination
  affordances it cannot honor — absence of `nextCursor` means complete.
- Internal Dart contracts (plugin interface, bridge internals, client
  modules) update all in-repository consumers in lockstep with no shims.

## Cleanup Assessment

Directly caused and included in the feature PRs:

- Delete `_doUnarchive`, `WorktreeService.restoreWorktree`,
  `_resolveRestoreBaseBranch`, unarchive handler branch, and their tests
  (step 7).
- Delete client unarchive UI: menu entry, swipe-pill unarchive state, undo
  snapshot for archive, `undoLastArchiveAction` reverse direction
  (step 8); update the archive confirm sheet copy from "reversible" to
  permanent.
- `SessionRepository.getSessionMessages` plugin-proxy body moves behind the
  history service; no dead code remains (step 4).

No further causal cleanup found: `idx_sessions_archive` becomes useful for
archived-reference listing; tombstone and storage-cleanup machinery is
unaffected.

## Evidence And Proportionality

- The core problem is an observed, user-reported failure (slow loads,
  cold-starting backends, a 25 GB backend database), not a theoretical edge.
- The staleness watermark is the coarsest mechanism that preserves
  correctness for externally advanced sessions; no per-message reconciliation
  or content hashing is added. The capture/catalog watermark race is accepted
  as bounded and self-healing (one redundant plugin fetch).
- Archive export failure handling is deliberately simple (log + proceed with
  stored content) because the backend's own storage still holds the source;
  no retry queue or export ledger is added.
- No locks beyond the existing per-plugin dispatcher serialization plus
  per-session write ordering in the history service.

## Delivery Sequence

Soft cap 1,500 changed lines per PR (additions + deletions, including
generated code and tests). Step 2 introduces a new Drift database, whose
generated `.g.dart` plus schema snapshot cannot be split from the schema that
defines them; an overage is expected and recorded here as unavoidable.

| Step | Exact PR title | Estimate | Boundary |
|---|---|---:|---|
| 1/9 | `🌱 [session-history-store] docs: plan the session history store [step 1/9]` | 500-700 | This plan and tracker. |
| 2/9 | `🚧 [session-history-store] feat(bridge): introduce the history database [step 2/9]` | 1,500-2,600 | `HistoryDatabase`, tables, DAO, repository, attachment spill store; wired into session-delete purge as its production consumer. |
| 3/9 | `🚧 [session-history-store] feat(bridge): capture live message events [step 3/9]` | 800-1,300 | Capture listener + history service write path, watermark upkeep, per-session ordering, failure handling. |
| 4/9 | `⚙️ [session-history-store] feat(bridge): serve messages from the store [step 4/9]` | 700-1,100 | Store-first serving with staleness fallback and backfill-on-read; attachment rehydration. |
| 5/9 | `⚙️ [session-history-store] feat: paginate session messages [step 5/9]` | 600-1,000 | Shared request/response fields, bridge paging, compatibility tests. |
| 6/9 | `🌿 [session-history-store] feat(client): load history pages on demand [step 6/9]` | 500-900 | Latest-page initial load, load-older affordance, complete-when-no-cursor behavior. |
| 7/9 | `🚧 [session-history-store] feat(bridge): make archiving read-only [step 7/9]` | 1,000-1,500 | JSONL export + purge + archive read path; unarchive rejection; prompt gate; restore-machinery deletion. |
| 8/9 | `🌿 [session-history-store] feat(client): permanent archive experience [step 8/9]` | 400-700 | Remove unarchive UI/undo, permanent-archive confirm copy, read-only composer state for archived sessions. |
| 9/9 | `🌱 [session-history-store] docs: retire the session history store plan [step 9/9]` | 50-150 | Move the plan to `.plan/completed/`. |

Steps merge in numeric order; each PR is independently valid at its base.
Bridge serving (4) precedes the wire change (5); the client adopts pagination
(6) before archiving changes behavior (7, 8) so the archived read path lands
on a client already capable of paged rendering.

## Step Details And Verification

### Step 1/9 — Plan

Raise this plan and tracker. Markdown-only validation; no Dart suites.

### Step 2/9 — History database

- Add `HistoryDatabase` and `SessionHistoryDao` under
  `bridge/app/lib/src/api/database/history/` with the three tables, schema
  snapshot v1, and migration test scaffolding; add `AttachmentSpillStorage`
  and `SessionArchiveStorage` under `bridge/app/lib/src/api/` (archive
  storage may land in step 7 with its first consumer if that keeps this PR
  smaller).
- Add `SessionHistoryRepository` and the purge surface of
  `SessionHistoryService` per Architecture And Ownership.
- Wire construction through `BridgeRuntimeRunner`/`Orchestrator`; ordered
  close in `BridgeRuntime`.
- Production consumer: `SessionDeletionService` purges history and spills for
  the deleted subtree beside the existing catalog delete.
- Verify: DAO/repository tests (ordering, seq assignment, spill idempotence,
  purge), migration verifier on v1, `dart analyze --fatal-infos`, full
  `bridge/app` tests. Record the generated-line count in the PR body.

### Step 3/9 — Live capture

- Add `SessionHistoryListener` on the normalized event stream and the
  `SessionHistoryService` write path: upsert message/part, remove handling,
  seq and order assignment, watermark advance, per-session write
  serialization.
- Failure policy: log with full context, drop the sync row, never block or
  crash the event pipeline.
- Verify: capture tests covering out-of-order part-before-message arrival,
  removal, watermark movement, fencing assumptions (only normalized events),
  and failure fallback; full `bridge/app` tests; architecture review.

### Step 4/9 — Serve from store

- Route `GetSessionMessagesHandler` through `SessionHistoryService`:
  fresh-store serve, staleness fallback to the existing plugin fetch, atomic
  replace-and-watermark on backfill, attachment rehydration (missing spill →
  `metadata`).
- Verify: serve/fallback/backfill tests including the externally-advanced
  session scenario and the empty-thread contract (empty list stays a valid
  synced state, distinct from fetch failure); full `bridge/app` tests;
  architecture review.

### Step 5/9 — Pagination wire

- Add `SessionMessagesRequest` with optional `limit`/`before` and the
  response `nextCursor`; regenerate shared models; bridge paging over `seq`;
  fallback path returns the full list.
- Verify: shared-model compatibility tests (old-shape request decodes, extra
  fields ignored), paging boundary tests (exact page, last page, empty
  session), full `sesori_shared` + `bridge/app` tests; architecture review.

### Step 6/9 — Client pagination

- `client/module_core`: `SessionApi.getSessionMessages` sends
  `SessionMessagesRequest` with optional `limit`/`before`; the client
  `SessionRepository` passes both through and returns the page plus
  `nextCursor`; `SessionDetailLoadService` requests the latest page for the
  initial snapshot. Page-merge state (loaded range, `nextCursor`,
  load-older in flight) lives in `SessionDetailCubit`, which exposes a
  load-older action calling the service — no cubit talks to the API layer
  directly.
- `client/app`: the session-detail message list gains a load-older affordance
  at the top of the transcript; absence of `nextCursor` renders as complete
  history. Older-bridge behavior (full list) remains correct with no
  affordance shown.
- Verify: cubit/service tests for page merge with live events and reload
  semantics (a reload re-requests the latest page and preserves paged-back
  history or honestly truncates to the latest page — behavior pinned by
  test); affected widget tests; full `module_core` tests.

### Step 7/9 — Read-only archive (bridge)

- Archive flow per Architecture And Ownership: `SessionLifecycleService` →
  `SessionHistoryService` → repository → `SessionArchiveStorage`/DAO for
  pre-export sync, atomic JSONL export + spill move, row purge, and
  incremental vacuum; archived read path from file with pagination;
  `archived: false` → typed error; `ArchivedSessionGate` consulted by the
  prompt/question/permission services; delete `restoreWorktree` and unarchive
  code; extend delete-purge to archive files.
- Verify: export/read round-trip including attachments and unknown-line
  tolerance, crash-window test (export exists, purge not committed →
  re-export safe), gate tests, wire-error test for `archived: false`; full
  `bridge/app` tests; architecture review.

### Step 8/9 — Permanent archive (client)

- Remove unarchive affordances and archive undo; permanent-archive confirm
  copy; archived sessions render read-only (composer disabled, clear state).
- Verify: session-list action and detail widget tests; full `client/app`
  affected suites.

### Step 9/9 — Retire the plan

Move `.plan/active/session-history-store/` to `.plan/completed/`; no
production changes.

## Material Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Store silently diverges from backend truth (missed events, bugs) and users see wrong history with no recourse. | Staleness watermark prefers the plugin fetch whenever catalog activity is ahead; any capture write failure drops the sync row, forcing re-backfill; backfill fully replaces rows rather than merging. |
| Archive purge loses the only copy of a transcript. | Export is atomic and committed before purge; archiving never touches backend storage, so the original source survives; crash between export and purge re-exports idempotently. |
| Archive files become unreadable after model evolution. | Payloads are wire-model JSON governed by the existing wire-compatibility discipline; manifest major version gates incompatible format changes; readers skip unknown line types and fields; a round-trip test pins v1 fixtures. |
| New Drift database codegen blows up review budget. | Isolated in step 2 with the overage recorded; no behavior beyond delete-purge in that PR. |
| Published apps issue unarchive and get undefined behavior. | Explicit typed error on `archived: false`; client-side removal ships in the same series; archive confirm warns permanence before the first purge can occur. |
| Capture floods the history DB during fast token streaming. | Deltas are never persisted; only full part snapshots (already bounded to 500-char tool output) are written, serialized per session. |
| Spill directory and DB rows drift apart. | Spill writes are content-addressed and idempotent; purge removes the whole per-session directory; a missing file degrades to `metadata` instead of failing the read. |

## Plan Review Record

`architecture-plan-review` (2026-08-06) rejected the first draft with seven
findings: a Layer 2 cross-dependency (`SessionRepository` purging history),
unnamed new classes without constructor dependency lists, unplaced file/PRAGMA
ownership for the spill and archive stores, a read-only gate duplicated across
Layer 4 handlers, a speculative `origin` column with no consumer, and a
too-vague client pagination step. All findings were applied directly in this
document: purge coordination moved to `SessionDeletionService`, the
Architecture And Ownership section names every new class with layer and
dependencies, `AttachmentSpillStorage`/`SessionArchiveStorage` are Layer 1,
vacuum runs through the DAO, `ArchivedSessionGate` is the single Layer 3
gate, the `origin` column was deleted, and step 6 names the touched client
classes. Per the repository review process, the corrected plan was not
re-reviewed merely to obtain an approval verdict.
