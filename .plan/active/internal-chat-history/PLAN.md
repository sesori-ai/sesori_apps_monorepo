# Internal Chat History Store

## Status

- **Plan slug:** `internal-chat-history`
- **Status:** Active — plan raised, implementation not started
- **Plan date:** 2026-08-06
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Base:** `main` at `232974e1`

## Goal

Serve session transcripts from a bridge-owned store instead of asking the
backend plugin on every open, paginate delivery to the client, and make
archiving a permanent read-only operation that moves the transcript out of the
live database into a versioned JSON audit file.

## Why Now (observed problems)

- Opening a session **cold-starts an idle backend** purely to read history:
  `SessionRepository.getSessionMessages` (bridge/app/lib/src/bridge/repositories/session_repository.dart:379)
  uses `PluginRuntime.use` with `startIfNeeded: true`. Plugins idle-suspend
  after 10 minutes, so this is the common path.
- Plugin history reads are slow by construction:
  - Codex: blocking `readAsLinesSync()` of the whole rollout `.jsonl` plus a
    full lifecycle replay, on every open
    (bridge/sesori_plugin_codex/lib/src/api/codex_rollout_api.dart:144).
  - ACP/Cursor: spawns a dedicated replay process, `session/load` with a
    2-minute timeout and a fixed 250 ms–6 s drain, per open
    (bridge/sesori_plugin_acp/lib/src/acp_plugin.dart:1285).
  - OpenCode: HTTP to the local server; user's OpenCode DB has grown to 25 GB
    and reads degrade with it.
- The **entire transcript ships in one relay frame** (`POST /session/messages`,
  `MessageWithPartsResponse`), with inline base64 images up to 5 MiB each and
  no pagination. Relay frame ceiling is 64 MiB.
- Nothing bounds bridge DB growth today; inline base64 in SQLite would bloat
  `sesori.db` badly.

## Decisions (user-confirmed)

1. **Archive is permanently read-only.** Unarchive is removed entirely:
   client UI, wire route, bridge handler/service path, and worktree-restore
   logic. Archived transcripts are purged from the live DB and preserved only
   as JSON audit files. Session metadata rows stay in `sesori.db` so archived
   sessions remain listed.
2. **Attachment bytes live on disk, never in a database.** Inline base64 from
   plugins is decoded once and written under the data directory; DB rows and
   archive JSON store references (id, mime, size, filename, relative path).
3. **Tool output stays plugin-truncated (500 runes).** The store persists what
   plugins already return; no fidelity change.
4. **Backfill is lazy.** First open of a session with no stored history does a
   one-time plugin import (may start the backend), persists it, and never asks
   the plugin again. No mass migration.
5. **Live history lives in a separate `chat_history.db`**, not in `sesori.db`.
   Keeps the main DB small, isolates WAL churn, and makes reclamation after
   purge cheap without touching the main DB.

## Compatibility Position

The client/bridge wire contract is the only compatibility boundary. Published
apps call `POST /session/messages` with `SessionIdRequest` and expect
`MessageWithPartsResponse`; that route keeps working (served from the store,
full transcript, inline base64 attachments materialized on read). A new
paginated route is added alongside; new clients prefer it and fall back to the
legacy route against an old bridge.

`PATCH /session/update/archive` currently accepts `archived: false`.
Published apps send it, so the bridge keeps accepting the request shape, but
the permanence rule lives in `SessionLifecycleService.updateArchiveStatus`,
which throws a typed rejection for unarchive attempts;
`UpdateSessionArchiveStatusHandler` only maps that exception to 409 (mirroring
the existing `SessionArchiveConflictException` branch). This is a deliberate
one-way behavior change, surfaced explicitly, not silent breakage.
`// COMPATIBILITY 2026-08-06` comment on the service-side rejection; remove
the request-shape tolerance when pre-change apps are out of support.

Plugin-interface and internal Dart contracts have no external consumers and
change in lockstep — no shims.

## Architecture

Touched workspaces: `bridge/app`, `client/module_core` + `client/app`,
`shared/sesori_shared`.

### New storage layout (all under the account data directory, chmod 700)

```
<dataDir>/sesori.db                    — existing main DB (session metadata)
<dataDir>/chat_history.db              — NEW: live transcripts (Drift, WAL)
<dataDir>/attachments/<sessionId>/<attachmentId>   — NEW: raw attachment bytes
<dataDir>/archived_sessions/<sessionId>.json       — NEW: archive audit files
```

### `chat_history.db` schema (new Drift database, `ChatHistoryDatabase`)

Separate `@DriftDatabase` class beside `AppDatabase`
(bridge/app/lib/src/api/database/), own `schemaVersion`, own step-by-step
migrations, own drift_schemas folder. Same file hardening as `sesori.db`
(0600, WAL, foreign_keys ON). No cross-database foreign keys; `sessionId` is a
plain TEXT key referencing the main DB logically. `ChatHistoryRepository`
never reads main-DB session data; cross-store consistency is owned by a
dedicated startup service (see Reconciliation below).

Tables:

- `chat_messages` — PK `{session_id, message_id}`; columns: `role` (textEnum),
  `agent`, `model_id`, `provider_id`, `error_name`, `error_message`,
  `created_at`, `completed_at`, `seq` (monotonic per-session ordering integer,
  see Ordering below). Index `(session_id, seq)`.
- `chat_parts` — PK `{session_id, part_id}`; columns: `message_id`, `type`
  (textEnum), `part_json` TEXT (the shared `MessagePart` serialized, minus
  inline attachment base64), `order_in_message`. Index
  `(session_id, message_id)`.
- `chat_attachments` — PK `{session_id, attachment_id}`; columns: `part_id`,
  `slot` (textEnum: `part-attachment` for `MessagePart.attachment`,
  `tool-state-attachment` for `ToolState.attachments`), `slot_index` (0 for the
  single-field slot, list index otherwise), `mime`, `filename`, `byte_length`,
  `kind` (inline-file / remote-url / metadata), `remote_url`. Bytes for inline
  kind live on disk at `attachments/<sessionId>/<attachmentId>`; the DB stores
  no blob. The slot discriminator lets re-inlining reconstruct the exact wire
  part.
- `chat_session_sync` — PK `{session_id}`; columns: `imported_at` (nullable —
  null means lazy import not yet done), `last_event_at`.

Rationale for `part_json` TEXT instead of fully columnar parts: `MessagePart`
is a flat model with 12 type-dependent nullable fields that evolves with the
product. Persisting the shared wire model as JSON (which already has
freezed `fromJson`/`toJson` and `include_if_null: false`) avoids a second
schema that must chase it, and read paths deserialize with the same code the
wire uses. Only fields needed for querying/pagination (`seq`, ids, type) are
columns. This mirrors the existing `session_options_cache_table` JSON-in-TEXT
precedent, with encode/decode owned by the repository layer.

### Attachment extraction

Base64↔file mapping is owned entirely by `ChatHistoryRepository` (Layer 2),
which aggregates `ChatHistoryDao` and a new Layer-1 `AttachmentStorage` file
API. On persist, the repository decodes each `MessageAttachmentInlineImage`
and has `AttachmentStorage` write the bytes atomically (temp + rename, chmod
600, mirroring `AppOnboardingStateStorage.writeMarker`) to
`attachments/<sessionId>/<attachmentId>`; the stored part JSON replaces the
inline variant with a reference (attachment row). On read, the repository
re-inlines base64 so both the legacy full-transcript route and paginated
pages keep the client contract unchanged in shape. `ChatHistoryService` has no
file-IO dependency. A follow-up (out of scope here) can add an on-demand
attachment fetch route so pages stop carrying base64 at all; the storage
design already supports it.

Attachment IDs: derived from `{part_id, slot, slot_index}` (stable across
re-imports), not content hashes — no dedup machinery.

### Write paths into the store

1. **Live capture (primary).** A new
   `ChatHistoryListener(source: sessionEventDispatcher.events, ...)` in
   `bridge/app/lib/src/listeners/`, constructed and started by
   `Orchestrator.create()` alongside `SessionDeletionListener`
   (bridge/app/lib/src/bridge/orchestrator.dart:491), owning its own
   subscription and `dispose()`. It consumes events after
   `SessionEventService` normalization — the last point with typed parts and
   bridge session ids (bridge/app/lib/src/bridge/repositories/mappers/session_event_mapper.dart:155).
   Persists on `message.updated`, `message.part.updated`,
   `message.part.removed`, `message.removed`. Deltas (`message.part.delta`)
   are **not** persisted; the finalized `part.updated` carries the complete
   part. Writes are upserts keyed by id, serialized per session through a
   simple sequential queue inside the service (no cross-session lock).
2. **Lazy import (backfill).** On a history read for a session whose
   `chat_session_sync.imported_at` is null, `ChatHistoryService` calls the
   existing `SessionRepository.getSessionMessages` (Layer 2 — the only place
   that touches the plugin runtime; may start the backend),
   persists everything in one transaction, marks `imported_at`, and serves
   from the store. Concurrent reads for the same session await the same
   in-flight import future. An import failure propagates as the same typed
   error the route returns today (cache miss must not masquerade as an empty
   thread) and leaves `imported_at` null for retry on next open.
   Sessions already active in the live stream before their import runs:
   upserts by id keep rows unique, and the import transaction **reassigns
   `seq` for the whole session in plugin-returned transcript order** —
   the transcript is the backend's authoritative ordering and includes any
   messages live capture already stored. Store rows absent from the
   transcript (live events newer than the fetch) keep their relative order
   above the imported maximum. This makes import + live capture idempotent
   and yields a consistent keyset order regardless of interleaving.

### Ordering and pagination

`seq` is assigned by the bridge: on insert of a new message, `max(seq)+1` for
the session (import assigns in plugin-returned order). Pagination is
keyset-based on `seq` descending:

- New route `POST /session/messages/page` with
  `SessionMessagesPageRequest { sessionId, limit, beforeSeq? }` returning
  `SessionMessagesPageResponse { messages: List<MessageWithParts>,
  nextBeforeSeq?, hasMore }`. Default page ~50 messages, newest first; the
  client renders the last page immediately and pulls older pages on scroll.
- The legacy `POST /session/messages` route stays and returns the full
  transcript from the store (fast now — no plugin call).

Client layers, explicitly: `SessionApi.getMessagesPage` (Layer 1, transport
only) → `SessionRepository.getMessagesPage` (Layer 2 — owns the 404 →
legacy-route fallback against an old bridge and result mapping) →
`SessionDetailLoadService` (Layer 3, paging policy: newest page on open,
older pages on scroll) → `SessionDetailCubit` (Layer 4, state only; no 404
branch in the cubit or the API class). Existing by-id SSE patching is kept (a
part update for a not-loaded older message no-ops, which is already today's
behavior).

### Read path change

`GetSessionMessagesHandler` (and the new page handler) call a single
`ChatHistoryService` method that internally resolves the source — live store
vs. archived audit file — and returns the same typed result. Handlers do no
file IO, no `fromJson`, and no source decision. The plugin call (via
`SessionRepository`) remains only inside the lazy-import path. This removes
the `startIfNeeded` backend start from the ordinary open path entirely.

Layering (mirrors `SessionOptionsCache*`):

```
ChatHistoryDatabase + ChatHistoryDao        (API — dumb queries)
AttachmentStorage                           (API — attachment file IO)
ArchivedSessionStorage                      (API — audit-file IO)
ChatHistoryRepository                       (Repository — aggregates the three
                                             APIs; owns encode/decode,
                                             base64↔file mapping, typed errors)
ChatHistoryService                          (Service — import policy, seq,
                                             pagination, archive export/purge,
                                             live-vs-archived resolution,
                                             per-session queue; depends on
                                             ChatHistoryRepository +
                                             SessionRepository)
ChatHistoryListener                         (Consumer — live capture)
Handlers                                    (Consumer — wire)
```

Wired in `Orchestrator.create()` like existing pairs
(bridge/app/lib/src/bridge/orchestrator.dart:242).

### Archiving (one-way, purge + audit file)

`SessionLifecycleService._doArchive` calls
`ChatHistoryService.archiveSessionHistory(...)` **before** the repository
archive flip: export must succeed before the session is marked archived, so an
archived session always has a valid audit file (archived reads depend on it).
If export fails, the archive operation fails with a typed error and the
session stays active with its live-store history intact. The service method
(no `dart:io` or JSON decoding in `SessionLifecycleService`):

1. Ensures the transcript is complete in the store. If `imported_at` is null,
   runs the lazy import first (may start the backend one last time). If that
   import fails, the archive **fails** with a typed error — never write an
   audit file known to be incomplete, and never purge without an audit file.
2. Has `ChatHistoryRepository` (via `ArchivedSessionStorage`) write
   `archived_sessions/<sessionId>.json` atomically. Persisted envelope: a
   freezed `ArchivedSessionFileDto` in
   `bridge/app/lib/src/api/models/` with `schemaVersion` (int, 1),
   `archivedAt` (ms), `session` (a freezed `ArchivedSessionSnapshotDto`
   capturing the main-DB session metadata: ids, project, directory, branches,
   agent/model, timestamps, title), and
   `messages: List<MessageWithParts>` (shared wire model JSON).

   Version in the payload; parts reference attachments by relative path
   (`attachments/<sessionId>/...`), which are **retained on disk** — they are
   part of the audit record. Corrupt-file handling on later reads follows the
   `CodexToolOutcomeStorage` quarantine pattern
   (bridge/sesori_plugin_codex/lib/src/api/codex_tool_outcome_storage.dart).
3. In one `chat_history.db` transaction deletes the session's messages, parts,
   attachment rows, and sync row.

Best-effort `plugin.archiveSession` stays as today in
`SessionLifecycleService`.

Ordering guarantees: audit-file write → main-DB archive flip → DB purge. A
crash after the file write but before the flip leaves an orphan audit file for
an active session (harmless; overwritten on the next archive attempt). A crash
after the flip but before the purge leaves duplicate data (file + rows),
resolved at startup by the reconcile service (below). Bounded transient
duplication is accepted.

**Archived reads:** handlers call the same `ChatHistoryService` read method;
it detects the archived state and has `ChatHistoryRepository` load and decode
the JSON file (single parse; pagination sliced in memory — archived reads are
rare audit views, performance is secondary). The repository checks
`schemaVersion`; a future v2 adds an explicit upgrade step there. The shared
`MessageWithParts` JSON is the persisted shape; wire model evolution must
keep `fromJson` tolerant of old payloads (it already is: nullable fields,
`include_if_null: false`, attachment `fallbackUnion`).

### Reconciliation (one owner)

A new Layer-3 `ChatHistoryReconcileService` — a startup peer of
`DeletedSessionStorageCleanupService`, invoked from `bridge_runtime_runner`
before relay traffic — with constructor dependencies
`{required SessionRepository sessionRepository, required
ChatHistoryRepository chatHistoryRepository}`. It owns all three
cross-store consistency behaviors:

1. Delete chat rows and attachment directories whose session no longer exists
   in the main DB (session deleted while bridge was down or delete partially
   failed).
2. Re-purge chat rows for sessions marked archived in the main DB that already
   have a valid audit file (crash between file write and purge).
3. Delete audit files and attachment directories whose bridge `sessionId` has
   no session row in the main DB. Archived sessions keep their metadata row,
   so a file without a row means the session was deleted (inline cleanup
   failed or the bridge was down). Deletion tombstones are keyed by backend
   session id and cannot address these files; existence of the session row is
   the mapping.

The live session-deletion path also deletes the audit file and attachment
directory inline via `ChatHistoryRepository`; the reconcile service is the
catch-up for failures. Introduced in PR step 3 (rows/attachments behaviors)
and extended in step 6 (audit-file behaviors).

### Unarchive removal (cleanup)

- Bridge: remove `_doUnarchive`, `unarchiveStoredSession`,
  `SessionDao.clearArchived`, worktree restore-on-unarchive;
  `SessionLifecycleService.updateArchiveStatus` throws a typed rejection for
  `archived: false`, mapped to 409 by the handler (see Compatibility
  Position).
- Client: remove `unarchiveSession` from api/repository/service/cubit, the
  swipe/menu Unarchive actions, undo-of-archive snackbar path (undo of a
  *just-made* archive would now be unarchive — remove the undo affordance for
  archive), related l10n strings, and tests.
- Archived session detail becomes read-only in the client: composer hidden,
  actions disabled. (The bridge additionally rejects sends to archived
  sessions — it may already; verify and enforce.)

## Size And Maintenance

- Purge-on-archive is the primary size control for `chat_history.db`.
- After each archive purge, run `PRAGMA incremental_vacuum` (create the DB
  with `auto_vacuum = INCREMENTAL`) so space returns to the OS without a full
  VACUUM. One pragma at creation + one call after purge; no scheduler.
- No TTL/pruning for active sessions: active transcripts are bounded by actual
  usage, and text-only rows (attachments on disk, tool output truncated) are
  small. Revisit only with evidence of growth.
- Audit files and attachment dirs are bounded by the user's own archive
  volume; they are plain files the user can inspect or delete.

## Evidence And Proportionality

- Slow opens, backend cold-starts, and 25 GB backend DBs are **observed**
  failures — the store, pagination, and purge-on-archive address them.
- Per-session write serialization in `ChatHistoryService` addresses the
  ordinary flow of live events racing a lazy import; resolved with idempotent
  upserts + a per-session queue, not global locks.
- Crash-between-file-and-purge is a theoretical narrow window; handled by an
  idempotent startup reconcile, accepting bounded duplication. No journaling
  machinery.
- Content-hash attachment dedup, on-demand attachment routes, and columnar
  part schemas are deliberately **not** built now. `ponytail:` comments will
  mark the re-inline-base64 read path (ceiling: page payload size; upgrade:
  attachment fetch route) and in-memory pagination of archived JSON.

## Cleanup Assessment

- **Removed by this work:** unarchive (bridge + client + tests + l10n),
  worktree restore-on-unarchive, the plugin round-trip in the ordinary
  `getSessionMessages` path.
- **Kept:** `plugin.getSessionMessages` interface (needed for lazy import),
  plugin-side truncation and attachment normalization, `notifySessionArchived`
  best-effort backend call.
- No other obsolete artifacts found.

## PR Series

Soft cap 1,500 changed lines per PR; codegen-heavy steps note expected
overage. Titles are fixed:

1. `🌱 [internal-chat-history] Raise plan [step 1/8]` — this document.
2. `⚙️ [internal-chat-history] Add chat history database and attachment storage [step 2/8]`
   — `ChatHistoryDatabase` (tables, DAO, migrations scaffold, schema dumps),
   `AttachmentStorage`, `ChatHistoryRepository`, wiring, unit tests. Likely
   exceeds the soft cap due to Drift codegen; accepted.
3. `🚧 [internal-chat-history] Persist live session events and lazy-import history [step 3/8]`
   — `ChatHistoryService` (import, seq, per-session queue),
   `ChatHistoryListener`, attachment extraction,
   `ChatHistoryReconcileService` (rows/attachments behaviors), tests.
4. `⚙️ [internal-chat-history] Serve session messages from the store [step 4/8]`
   — switch `GetSessionMessagesHandler` to the store; keep wire shape
   identical; tests proving empty-vs-error semantics survive.
5. `⚙️ [internal-chat-history] Add paginated session messages route and client paging [step 5/8]`
   — new shared DTOs, bridge handler, client load-newest-page +
   scroll-back + old-bridge fallback.
6. `🚧 [internal-chat-history] Make archiving read-only with JSON audit export [step 6/8]`
   — `ArchivedSessionStorage` + archive export + purge, reconcile audit-file
   behaviors, typed unarchive rejection (409), archived reads from JSON,
   incremental vacuum, delete-path file cleanup.
7. `🌿 [internal-chat-history] Remove unarchive from the client [step 7/8]`
   — UI/cubit/service/api removal, read-only archived detail, l10n, tests.
8. `🌱 [internal-chat-history] Retire plan [step 8/8]` — move plan to
   `.plan/completed/`.

Steps 2–4 are bridge-only and invisible to users until step 4 flips the read
path. Step 6 is the behavior change; step 7 aligns the client.

## Verification

- Per-PR: owning-package tests + analyzer; migration tests for the new DB via
  drift `SchemaVerifier` fixtures (as `bridge/app/test/drift/`).
- Step 3: idempotency test — same transcript via import then live events (and
  reversed) yields identical rows; attachment bytes written once.
- Step 4: golden comparison — store-served response equals plugin-served
  response for a fixture transcript, per plugin mapper fixtures.
- Step 6: archive round-trip test — archive, restart-simulated reconcile,
  read from JSON equals pre-archive read; crash-window test (file exists, rows
  present) re-purges cleanly.
- Manual: open a large Codex/ACP session before/after step 4 and confirm no
  backend start and sub-second load.

## Risks

- **Store divergence from backend truth:** the bridge store only sees what the
  bridge sees. Sessions driven directly via backend TUI/CLI while the bridge
  runs are captured via live events; activity while the bridge is *down* is
  missed after the initial import. Accepted: Sesori-driven sessions are the
  product surface. If evidence of divergence appears, a re-sync affordance can
  be added later (the `imported_at` flag supports forcing re-import).
- **Legacy full-transcript route stays unbounded** for old apps until they
  upgrade; unchanged from today's exposure, now faster.
- **Archive JSON is a persisted contract with our own future code**; guarded
  by `schemaVersion` + tolerant freezed decoding + quarantine-on-corrupt.
