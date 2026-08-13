# Lazy Transcript Attachments

## Status

- **Plan slug:** `attachment-references`
- **Status:** Step 8/11 - client thumbnail cache ready for review
- **Plan date:** 2026-08-10
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `57e1d0ea`
- **Delivery:** one plan PR, nine sequential implementation PRs, and one
  plan-retirement PR
- **Related future work:** prompt-upload decisions are recorded separately in
  `.plan/drafts/prompt-attachment-uploads/CONSIDERATIONS.md`; they are not part
  of this series.

## Goal

Stop carrying bridge-owned raster image originals inside every transcript page
and live message-part event. Capable clients receive small attachment metadata
with a session-scoped attachment identifier, load one fixed thumbnail on
demand, and fetch the original only when the user opens it.

The visible result is a stable square attachment presentation that loads
quickly, uses an app-private thumbnail cache, and preserves the existing image
viewer actions without making bridge content public or readable by the relay.

## Success Criteria

1. A capable app opening a 50-message history page receives no bridge-owned
   original image bytes in that page.
2. A capable app receiving a live `message.part.updated` event receives the
   attachment reference inside that existing event, not a second attachment
   event.
3. A referenced image is addressable only within its owning bridge session and
   remains E2E encrypted while crossing the relay.
4. Chat first renders a fixed square tile. The tile reserves its space while
   loading, center-crops the thumbnail, overlays available filename/type/size
   metadata, and offers an in-place retry after failure.
5. Tapping a referenced image opens the existing single-image viewer with the
   thumbnail immediately visible, automatically fetches the original, then
   enables the existing copy, share, and save actions against the original.
6. GIF and animated WebP previews are static first frames; their originals
   animate in the viewer through Flutter's normal image codec.
7. Thumbnails survive app restarts in an app-private bounded cache. Originals
   fetched for viewing remain temporary, are released when the viewer closes,
   and are not persisted as an offline media library.
8. Bridge-owned transcript images support up to 20 MB each and 50 MB aggregate
   per existing logical attachment collection. The existing four-candidate
   collection limit remains unchanged.
9. Released compatibility is preserved in every direction: old apps receive
   the existing bounded inline/metadata shapes, and new apps continue to render
   inline images from old bridges.
10. Archive, session deletion, and history purge remove their data-directory-
    local metadata without deleting attachment bytes shared with another bridge
    database. Manually removed bytes degrade to metadata without adding an
    attachment table, refcounting, or background cleanup lifecycle.
11. HTTPS remote image attachments retain their current phone-fetched behavior;
    this work neither snapshots them on the bridge nor weakens their existing
    URL, redirect, MIME, signature, timeout, and size checks.

## Locked Product Decisions

### Chat presentation

- One attachment uses a larger square tile; multiple attachments in an existing
  collection use a responsive two-column square grid.
- The preview uses center crop. The viewer uses contain and reveals the full,
  uncropped original.
- Every tile has a bottom metadata overlay. Missing values are omitted rather
  than represented with empty strings.
- Loading and error states retain the same square dimensions to prevent chat
  reflow. A failed thumbnail has an explicit retry action.
- A cached thumbnail remains visible if the original is unavailable. The viewer
  explains the failure and offers retry instead of replacing the preview.
- The current viewer remains scoped to one image. Swipe galleries across a
  message or session are deferred because they conflict with the existing
  pinch, pan, double-tap zoom, Hero, and drag-dismiss gesture system.
- Metadata-only and unsupported files use the same square footprint with a file
  icon and available metadata. This plan does not make their bytes downloadable
  or openable.

### Delivery and privacy

- The attachment reference is part of the current `MessageAttachment` carried
  by `message.part.updated` and history responses. There is no new SSE event.
- Bridge content has no public or relay-hosted URL. The client loads it through
  the existing encrypted relay request path.
- `cached_network_image`, an in-app loopback HTTP server, and a relay plaintext
  proxy are intentionally not used.
- One thumbnail or original is returned per request as bounded base64 in JSON.
  There is no binary framing, chunking, range request, or resumable transfer in
  this plan.
- The app caches only thumbnails on disk. The cache is scoped by account,
  bridge, session, attachment, rendition version, and is cleared when its
  authenticated local scope is removed.
- Remote HTTPS images continue to be fetched by the phone as today. Their
  third-party origin and existing privacy behavior are not disguised as a
  bridge-owned attachment.

### Bridge attachment persistence

- Bridge-owned attachment bytes live outside `--data-dir` in one owner-only,
  platform-native persistent root shared by bridge instances for the current OS
  user: `~/Library/Application Support/Sesori Attachments` on macOS,
  `${XDG_DATA_HOME:-~/.local/share}/sesori-attachments` on Linux, and
  `%LOCALAPPDATA%\Sesori Attachments` on Windows.
- A storage scope is the durable `(pluginId, backendSessionId)` binding, not the
  database-local random `ses_...` id. Importing the same backend session into a
  different data directory therefore reaches the same attachment files after
  that database backfills the transcript and recreates its local references.
- Account identity and `--data-dir` are intentionally absent from the disk
  scope. Access still requires a session row with the matching durable backend
  binding in the requesting bridge database.
- Shared attachment bytes have manual lifetime. Archive, unarchive, local
  history purge, and session deletion do not copy or delete them because another
  bridge database may still reference the same scope. Removing the shared root
  or one scoped directory is supported and degrades affected references to
  metadata/404 until the backend supplies those bytes again.

## Explicitly Excluded

- Prompt/composer upload references. See the separate considerations document.
- Restart-safe attachment drafts, upload queues, upload percentages, upload
  cancellation/resume, and cross-device draft synchronization.
- Video playback, video posters, PDF rendering, document opening, generic file
  downloads, SVG rendering, and audio playback.
- Camera and file-picker expansion.
- Full-screen image galleries or session-wide media browsing.
- A relay-server route, public URL, plaintext relay cache, room-key disclosure,
  or any other trust-posture change.
- A new binary relay message, chunk/range protocol, or transfer registry.
- Multiple thumbnail sizes, adaptive quality tiers, or network-specific image
  variants.
- Cross-session content deduplication, attachment refcounts, a new attachment
  database table, or a background attachment garbage collector.
- Client-side persistence of full transcript originals.

## Current Behavior And Evidence

### Transport cost

- `MessageAttachment.inlineImage` stores base64 directly in the shared message
  part (`shared/sesori_shared/lib/src/models/sesori/message_part.dart`).
- `POST /session/messages` returns 50 messages per client page
  (`client/module_core/lib/src/services/session_detail_load_service.dart`). A
  page can therefore repeat several full images even when no image is visible.
- `BridgeEventMapper` maps a finalized `BridgeSseMessagePartUpdated` to the full
  shared part. `SSEManager` retains that event independently for each live or
  orphan subscriber queue, so inline bytes also increase bridge memory and
  reconnect replay traffic.
- Relay request/response and SSE bodies are strings. The relay forwards opaque
  encrypted frames and enforces a 64 MiB frame ceiling. It has no HTTP content
  proxy, binary body, streaming, or range primitive.

### Existing storage supplies the original-persistence primitive

- `AttachmentSpillStorage` stores decoded originals under
  `history/attachments/<session>/<sha256>` with atomic, idempotent,
  content-addressed writes and hardened permissions.
- `ChatHistoryRepository` currently converts `inline_image` to an internal
  `stored_file` reference before database/archive persistence, then reads and
  base64-encodes the original again on every history response.
- Before Step 3's shared-root revision, archive export copied the session spill
  directory before live purge, and session/archive deletion removed the
  respective spill directories. Those data-directory-local lifecycle rules are
  the behavior being replaced because independent databases cannot coordinate
  deletion of shared files.
- The completed internal-history plan explicitly identified an on-demand
  attachment route as the upgrade path. This work uses that path rather than
  replacing the history store.

### Existing client behavior

- `MessageImageRepository` validates raster MIME, decoded size, HTTPS redirects,
  and magic bytes before returning image bytes.
- Every `FilePartWidget` creates its own `MessageImageCubit`; inline bytes are
  decoded and remote bytes fetched before the current variable-aspect preview
  appears.
- `file_part_widget.dart` uses `BoxFit.contain` with only a maximum height, so
  message layout varies by source aspect ratio.
- `ImageAttachmentViewer` already owns Hero transition, contain rendering,
  pinch/pan, double-tap zoom, drag-dismiss, copy, share, save, and remote
  open-original behavior. Replacing it is unnecessary.

## Architecture

### 1. Shared wire contract

Add a new image-specific attachment source to `MessageAttachment`:

```text
stored_image
  attachmentId
  bridgeId
  mime
  filename?
  byteLength
```

The exact identifier remains an opaque client contract even if the first bridge
implementation uses the existing content address internally. `bridgeId` is the
required identity from the bridge's existing `BridgeIdProvider`; every fetch
also requires `sessionId`. Clients must not treat the identifier as a globally
reusable URL.

Keep `fallbackUnion: "unknown"`. A capable reference must nevertheless never be
sent to an old app because that app currently hides unknown attachment sources.

Add one closed delivery mode enum:

```text
MessageAttachmentDelivery.inline
MessageAttachmentDelivery.storedReference
```

Use it in both existing request surfaces:

- `SessionMessagesRequest.attachmentDelivery`, defaulting to `inline` for old
  apps; and
- `RelaySseSubscribe.attachmentDelivery`, defaulting to `inline` for old apps.

New fields use a dated compatibility default tied to the first production
release that ships them. Old bridges ignore the extra JSON field. New apps must
continue to support all existing attachment variants when an old bridge
returns inline data.

Add typed shared request/response models for `POST /session/attachment`:

```text
SessionAttachmentRequest
  sessionId
  attachmentId
  rendition: thumbnail | original

SessionAttachmentResponse
  mime
  base64
  byteLength
```

The endpoint returns one rendition only. It uses 404 for a missing/purged
original and an explicit non-success response when a thumbnail cannot be
decoded. Raw filesystem errors stay in local bridge logs; remote errors remain
content-safe.

### 2. Stored originals and one thumbnail rendition

Continue using `AttachmentSpillStorage` for originals, but compose it over the
platform-native shared attachment root rather than `--data-dir`. Its directory
scope is derived from the stored session's required `pluginId` and
`backendSessionId`, both encoded as path segments; the database-local session id
continues to scope queues, history rows, archives, routes, and client caches but
never disk identity. Extend that shared scope with a versioned
derived-thumbnail filename. Do not introduce a new table, refcount, or garbage
collector.

The root resolver belongs in `sesori_bridge_foundation` beside
`sesoriDataDirectory` and uses `resolveUserHomeDirectory`; it honors
`XDG_DATA_HOME` on Linux and never reads `HOME`/`USERPROFILE` outside that
foundation boundary. `AttachmentSpillStorage` owns encoded scope paths, atomic
idempotent writes, and owner-only hardening. Two bridge processes writing the
same backend session and digest converge on the same file.

The shared root has one copy of each file per backend session scope. There is no
live/archive attachment split: archive audit JSON retains the same internal
content reference, while archive/history/session deletion removes only the
requesting data directory's rows and audit files. Shared bytes remain available
to another database and are removed only by the OS user. A new database does
not infer message-to-attachment metadata by listing the root; its first normal
backend transcript backfill recreates those local references and the
content-addressed write reuses existing bytes.

The previous data-directory-local spill layout was implementation-only and has
no supported production compatibility requirement. Step 3 replaces it cleanly:
there is no startup migration, fallback read, dual write, or sync-state repair.
Files left by development/internal builds are ignored and may be removed with
their old data directory.

The thumbnail contract is fixed for this series:

- 512 x 512 physical pixels;
- center crop;
- first frame for animated input;
- orientation baked before crop;
- opaque output encoded as bounded-quality JPEG;
- alpha-bearing output encoded as PNG; and
- a rendition-version suffix in the derived filename, so a future algorithm can
  coexist without mutating an existing file in place.

Generate the thumbnail lazily on the first request and persist it atomically.

The concrete bridge owners are:

- `AttachmentThumbnailBuilder` in
  `bridge/app/lib/src/bridge/repositories/attachment_thumbnail_builder.dart`
  is a pure, zero-collaborator Layer-2 transformation over the pure-Dart image
  codec, beside the attachment projection/mapping policy it implements. It runs
  off the main isolate, reads metadata first, rejects dimensions/pixel counts
  above its documented decode-memory ceiling, bakes orientation, crops, and
  encodes one rendition. It owns no files, cache decisions, or queue.
- `AttachmentStorageScope` in
  `bridge/app/lib/src/api/attachment_spill_storage.dart` is the required
  Layer-1 value passed across the service/repository/storage seam. It carries
  non-null `pluginId` and `backendSessionId`; only `AttachmentSpillStorage`
  encodes those values into directory segments.
- `ChatHistoryRepository` remains the Layer-2 aggregate owner of transcript
  attachment references. New methods store/read an original or derived
  thumbnail in the one shared spill root, project a stored message's attachment
  collection for capable/legacy delivery, and atomically persist a generated
  thumbnail through the existing Layer-1 storage API. Repository methods that
  touch bytes require the durable attachment scope supplied by the service.
- `ChatHistoryService` requires `AttachmentThumbnailBuilder`; its
  attachment-read and attachment-persistence paths resolve the local session to
  its durable plugin/backend binding inside the existing per-session queue. It
  owns one coarse generation lane inside that queue so a page of uncached
  previews cannot launch many full-image decodes concurrently. It does not
  touch `AttachmentSpillStorage` directly.
- `GetSessionAttachmentHandler` in
  `bridge/app/lib/src/bridge/routing/get_session_attachment_handler.dart`
  requires `ChatHistoryService` and maps typed route success/failure only.

`StoredAttachmentLocation`, the second `AttachmentSpillStorage` dependency, and
the `archivedAttachmentStorage` wiring in `Orchestrator` and
`BridgeRuntimeRunner` become obsolete and are removed in Step 3. Transcript
selection still distinguishes live database rows from archived audit JSON, but
that state no longer parameterizes attachment byte access.

The single service lane addresses an ordinary reachable flow with meaningful
memory impact; no per-session or per-digest lock registry is needed. A rejected
thumbnail does not delete or invalidate the original. Fetch selects the live or
archived transcript from durable session state, but both transcript states read
the same durable attachment scope. Scope resolution, original read, and the
final derived write remain inside the existing session queue. The thumbnail is
persisted beside its source original; archive and purge do not mutate that
shared scope.

### 3. History and archive projection

Thread `MessageAttachmentDelivery` from `GetSessionMessagesHandler` through
`ChatHistoryService` into `ChatHistoryRepository`.

For an internal `stored_file` reference:

- `storedReference` returns `stored_image` metadata without reading or
  base64-encoding the original; existing stored records without byte length
  derive it from the spill file; and
- `inline` preserves the released response shape, but sends at most the current
  5 MiB legacy collection budget and degrades excess images to `metadata` in
  collection order.

The same projection applies to active database pages and archived audit pages.
A missing original remains `metadata`, matching current fail-soft history
behavior.

### 4. Live event projection and ordering

Do not coordinate `ChatHistoryListener` and `Orchestrator` with callbacks,
acknowledgements, or another event stream.

`ChatHistoryService.requiresAwaitedAttachmentCapture(part:)` is the single
predicate for whether a shared message part contains inline images in its file
slot or tool attachments. Both consumers call that same service-owned method.
For those events only, `ChatHistoryListener` deliberately skips its ordinary
unawaited part capture and Orchestrator calls a named
`ChatHistoryService.capturePartForDelivery` method after mapping/truncation and
before wire delivery. Non-image parts and every other history event retain the
existing listener path.

`capturePartForDelivery` enters the existing per-session queue, performs the one
decode/spill/database write through `ChatHistoryRepository`, advances the same
sync state as ordinary capture, and returns a sealed result containing:

- a reference-shaped event for capable subscribers; and
- a legacy event with the existing 5 MiB inline/metadata budget for old
  subscribers.

This makes the write outcome directly available to wire delivery without a
callback, result registry, or second event. It also joins archive
export/flip/purge ordering instead of writing a new live spill outside the
session queue. If capture fails, the method logs the original error, clears
`syncedAt`, and returns a typed unavailable result; Orchestrator sends the mapped
legacy-safe inline/metadata shape rather than a dangling identifier.

Legacy projection evaluates the complete persisted logical collection, not
only the current SSE part. Tool attachments are already one part; ordered ACP
assistant image parts are projected against earlier stored sibling parts. This
preserves the released 5 MiB aggregate decision even after plugin trackers can
retain 50 MB for capable clients, without adding mutable bridge-side collection
accounting.

`SSEManager` records attachment delivery mode with each subscriber queue and
selects the corresponding event when enqueuing. Orphan queues retain their
mode; reconnect adoption uses only an orphan with the same mode. This avoids an
old app receiving a queued reference after a different capable connection and
does not require a global client capability registry.

Only message-part events with bridge-owned images need dual shapes. All other
SSE events remain one object. The local debug SSE stream retains the legacy
shape unless its own explicit capability surface is added by a future need.

### 5. Limits and backend boundaries

Keep the released 5 MiB `maxInlineMessageAttachmentBytes` as the legacy-wire
budget. Add separate bridge-reference limits:

- 20 MB decoded per image;
- 50 MB decoded aggregate per logical message/tool attachment collection; and
- the existing maximum of four output image candidates per collection.

Update output-image mapping in OpenCode, Codex, ACP, Cursor, and the in-repo
Claude plugin in lockstep. These are internal plugin contracts, so they receive
no compatibility shims. Prompt-input limits do not change in this series.

The bridge applies the legacy projection after plugin mapping, which preserves
old-app behavior: images that were previously metadata because they exceeded
5 MiB remain metadata for an old app, while a capable app can fetch the retained
larger original.

### 6. Client loading and cache ownership

Add a Layer-1 attachment API over `RelayHttpApiClient`, then extend
`MessageImageRepository` to load `thumbnail` and `original` renditions for a
stored image. Continue validating MIME, byte length, and magic bytes after
fetch; a bridge response is authenticated and encrypted but still treated as
untrusted image input.

The attachment API uses a sensitive-response mode on `RelayHttpApiClient`.
Malformed JSON or DTO fields log source-free parser details (type, message,
offset, stack, and operation context), never the caught exception whose
`FormatException.source` may retain decrypted bytes. The returned
`JsonParsingError` carries only a fixed privacy-safe marker; no response body or
base64 field is retained in an API error or diagnostics.

Add a named `RelayHttpApiClient.postWithTimeout` path and thread its required
duration through `_sendViaRelay` into a required per-request timeout on
`RelayClient.sendRequest`. Ordinary API methods continue to pass the existing
30-second default explicitly; `MessageAttachmentApi` passes the longer bounded
attachment timeout. This is not resumability: a disconnect or timeout retries
the complete image.

Add `AttachmentThumbnailStorage` under
`client/module_core/lib/src/foundation/platform/` as a dumb file-IO capability:
read, atomic write, list metadata, and delete within a caller-supplied scope. Its
`FlutterAttachmentThumbnailStorage` implementation under
`client/app/lib/core/platform/` resolves the OS app-private cache directory and
performs only those IO primitives. It requires the existing
`TemporaryDirectoryClient` constructor dependency rather than calling
`path_provider` statically. It does not construct keys, choose eviction,
coalesce requests, or react to authentication.

`MessageImageRepository` in `module_core` requires `AuthSession` and owns scoped
key construction, validation, corruption recovery, one in-flight fetch per key,
and the simple total-size/oldest-file pruning policy. At each stored-image load
boundary it captures the authenticated `AuthUser.id` from
`AuthSession.currentState`, takes `bridgeId` from the required `stored_image`
field, and receives the message-owned `sessionId`; these values form the cache
scope with attachment id and rendition version. No cache operation reads a
global current-bridge fallback. Only encoded thumbnails are persisted.

Each authenticated account scope is capped at 64 MiB; after a successful write,
the repository deletes the oldest modified entries (key order breaks timestamp
ties) until the scope is within budget. Reads do not update modification time,
so this remains simple oldest-on-write pruning rather than an LRU index.

A `@lazySingleton` `MessageThumbnailCacheService` in `module_core` requires
`MessageImageRepository` plus `AuthSession` and owns account-scope cleanup. The
mobile shell resolves it once immediately after `configureCoreDependencies`,
after registering its storage adapter; construction subscribes to auth before
any session UI can cache a thumbnail. Desktop neither binds nor resolves this
mobile cache path. Cleanup retires the account generation, rejects late writes,
settles started fetch/write futures, and only then deletes the scope. Its
`@disposeMethod` cancels the subscription during container teardown.

Do not add a persistent database, cache index, background cache worker, or full
original cache. The OS may evict cache files at any time; a miss simply refetches
the thumbnail.

Extend the existing `MessageImageCubit` in `module_core` to own thumbnail and
original load intents through `MessageImageRepository`. Its sealed state models
preview loading/ready/failure independently from original loading/ready/failure.
Every attachment collection threads its authoritative `MessagePart.sessionID`
as a required value through `FilePartWidget` into the cubit and repository; the
stored reference supplies its authoritative bridge identity. No loader or cache
key reads global current-session or current-bridge state. `FilePartWidget`
continues to construct the cubit at the existing composition seam. Flutter
widgets only render emitted encoded bytes through standard
`MemoryImage`/`ResizeImage` providers and dispatch retry/open/close intents back
to the cubit. No Flutter provider or feature widget calls the repository
directly.

### 7. Presentation

Introduce one reusable session-detail attachment collection widget that owns
square sizing, grid layout, metadata overlay, and per-tile states. Use it for
the attachment lists already owned by user messages and tool states. Preserve
assistant text/image/tool chronology; only contiguous assistant file parts may
be grouped.

Inline images from old bridges and directly fetched HTTPS images use the same
square presentation. Their existing bytes/URL paths remain unchanged.

For a stored image, the viewer receives thumbnail bytes from
`MessageImageCubit` immediately and dispatches the original-load intent after
opening. On success it replaces the standard in-memory provider without closing
the route and constructs the existing original-backed action state. On failure
it retains the thumbnail, shows retry, and leaves original actions unavailable.
Viewer route completion always dispatches `releaseOriginal`, returning the
tile-owned cubit to thumbnail-ready state and dropping encoded original bytes;
the repository coalesces only in-flight original requests and retains no
completed original cache. Do not add page swiping or another viewer route.

## Compatibility Matrix

| App | Bridge | Result |
|---|---|---|
| Old | Old | Existing inline/remote/metadata behavior. |
| Old | New | Missing delivery mode defaults to inline. Existing 5 MiB visible behavior is preserved; newly retained larger images degrade to metadata. |
| New | Old | Unknown request fields are ignored. The app receives and renders existing inline/remote/metadata variants. |
| New | New | History and live events carry stored references; thumbnail and original fetches remain E2E. |

Compatibility applies independently to paged history requests and each live SSE
subscription because multiple app versions may use one bridge concurrently.

## Failure And Recovery Contract

| Failure | User outcome | Local observability |
|---|---|---|
| Queued live capture fails before reference emission | Projection returns unavailable; the mapped legacy-safe image or metadata remains in the live event, with no dangling reference. | Bridge logs original error, stack, session/part operation context, and no content. |
| Original was purged or missing | Cached thumbnail remains visible; viewer reports unavailable and offers retry. | Fetch route returns 404; storage error context remains local. |
| Thumbnail decode is unsupported or unsafe | Stable square error tile with retry; original is not deleted. | Bridge reports bounded rendition failure without payload data. |
| Thumbnail cache read is corrupt | Cache entry is removed and fetched again. | Client logs cache operation context without paths in analytics. |
| Original fetch times out or connection drops | Viewer keeps thumbnail and offers full retry. | Client preserves the typed transport failure. |
| Old client would exceed legacy inline budget | That attachment becomes metadata, matching previous visible behavior. | No repeated warning per attachment; one bounded collection degradation signal is sufficient. |

## Security And Privacy

- Relay E2E framing and room-key handling are unchanged.
- Every fetch requires the owning `sessionId` plus a syntactically valid
  attachment id. The bridge resolves that session row to its required plugin and
  backend identity, then resolves storage under those encoded scope segments;
  malformed identifiers cannot select another scope or traverse the root.
- The first identifier implementation may reuse the content address inside the
  encrypted contract, but clients treat it as opaque and scope caches by bridge
  and session. Cross-session/public addressing is not provided.
- No source path, prompt, transcript, attachment bytes, URL, filename, raw id,
  or error text enters analytics.
- Thumbnail cache files contain decrypted user content. They remain app-private,
  are excluded from backup where the platform requires explicit configuration,
  and are cleared with the local authenticated scope.
- Decode concurrency and decoded-pixel bounds protect bridge thumbnail
  generation from disproportionate memory requirements. Original rendering
  retains the existing Flutter codec behavior and remains lazy behind the preview.

## Analytics

No analytics event is added for passive preview rendering or viewer taps. There
is no current product decision that requires measuring those UI interactions,
and attachment metadata is privacy-sensitive.

The separately considered prompt-upload work may add only a bounded
`has_attachments` parameter to the existing authoritative accepted-message and
session-created outcomes. It is not part of this series.

## Cleanup Assessment

Small directly caused cleanup is included:

- capable history reads stop rehydrating and base64-encoding stored originals;
- capable SSE queues stop retaining original bytes; and
- client reference previews stop requiring a full-original decode before a chat
  tile appears; and
- the obsolete archived attachment root, archive-copy path, and delete-time
  attachment-directory purge are removed because shared files cannot follow one
  database's lifecycle; and
- bridge operator documentation identifies the platform-native attachment root,
  its manual lifetime, and the fact that deleting a session does not erase
  those shared decrypted files.

Compatibility prevents deleting these paths now:

- internal `stored_file` to `inline_image` rehydration remains for old apps;
- `MessageAttachment.inlineImage` and its client validation remain for old
  bridges and legacy live delivery; and
- plugin-side legacy metadata mapping remains the old-client fallback.

No database column, table, cache, flag, job, or listener becomes wholly obsolete.
Do not remove compatibility paths until the relevant production app/bridge
baseline is intentionally raised in a separate task.

## Proportionality And Accepted Risk

| Decision | Evidence level | If omitted | Chosen response |
|---|---|---|---|
| Reference history images | Observed ordinary flow: every open/reload sends paged inline originals. | Repeated bandwidth, base64 work, and memory. | Implement. |
| Reference live images | Observed ordinary flow: finalized part events and replay queues carry full snapshots. | Duplicate live/reconnect traffic and bridge queue memory. | Implement with per-subscriber shaping. |
| Queue live capture and projection together | Archive and live activity can overlap for one session. | A reference could be emitted before its shared spill write completes. | One awaited service call reuses the existing per-session queue. |
| Project the complete legacy collection | ACP assistant images arrive as separate part updates. | Per-event shaping could exceed the released 5 MiB aggregate behavior. | Query bounded stored sibling parts; no mutable accounting registry. |
| Serialize thumbnail generation | Ordinary page can request several uncached previews together. | Concurrent full decodes can spike bridge memory. | One coarse lane, no keyed lock registry. |
| Persist one bridge thumbnail | Multiple devices/cache eviction can request the same derived image. | Repeated CPU-heavy decode. | One versioned sibling file in the shared backend-session scope. |
| Chunk/resume transfers | Theoretical benefit for this bounded image-only scope; no observed failed 20 MB attachment flow. | A failed transfer retries the complete image. | Accept and defer. |
| Gallery swiping | Convenience only; current viewer already opens every image. | User closes viewer to choose another tile. | Accept and defer. |
| Document/video support | No current ordinary production byte source. | Metadata tiles remain non-openable. | Accept and defer. |
| Shared attachment cleanup/refcount | Independent bridge databases can reference the same backend-session scope but cannot atomically enumerate each other's references. | Automatic deletion by one database can break another. | Keep manual lifetime; accept retained orphan bytes and avoid coordination machinery. |
| Global content dedup | The requested reuse boundary is one backend session; a globally addressed file would need an additional per-session authorization membership check. | Identical bytes in different sessions remain duplicated. | Accept and keep storage session-scoped. |

## Delivery Rules

- The series has exactly eleven PRs. Every title below is fixed and uses the
  `attachment-references` slug.
- Step 1 raises this plan, tracker, and the upload considerations document.
- Step 11 records final evidence and moves this directory from `.plan/active/`
  to `.plan/completed/`.
- Merge in numeric order. A successor may target its immediate predecessor, but
  each PR must remain independently buildable and safe at its own base.
- Target no more than 1,500 changed lines per PR, including generated output and
  tests. Update this plan before opening a step that cannot fit coherently. Step
  7 is the documented exception: 1,906 changed lines keep the typed transport,
  account/bridge/session scope, sensitive-response handling, generated DI, and
  security/cross-layer regression coverage reviewable as one coherent seam.
- Generated Freezed/JSON/DI files change only through their generators.
- The capability remains disabled in production client requests until Step 10,
  after bridge fetch, compatibility, cache, presentation, and viewer behavior
  exist together.
- Internal plugin contracts update all in-repository consumers in lockstep.
- Run architecture implementation review for Steps 2-5, 7-8, and 10. Step 6 is
  a bounded policy/limit migration and Step 9 is presentation-only; neither
  needs architecture review unless implementation changes their scope.
- Do not add prompt-upload behavior opportunistically to any step.

## Delivery Sequence

| Step | Exact PR title | Estimate | Boundary |
|---|---|---:|---|
| 1/11 | `🌱 [attachment-references] docs: plan lazy transcript attachments [step 1/11]` | 650-1,100 | Active plan/tracker and upload considerations only. |
| 2/11 | `🚧 [attachment-references] feat(protocol): describe stored transcript images [step 2/11]` | 750-1,100 | Shared variant, rendition models, delivery mode defaults, generated code, exhaustive compile-safe consumers. No peer enables references. |
| 3/11 | `🚧 [attachment-references] feat(bridge): serve stored image renditions [step 3/11]` | 1,800-2,300 | Shared backend-session storage, versioned thumbnail builder, session-queued rendition lookup, typed fetch handler, and decode/size/security tests. |
| 4/11 | `⚙️ [attachment-references] feat(bridge): reference images in history pages [step 4/11]` | 700-1,150 | Capability-aware active/archive projection and legacy budget preservation. |
| 5/11 | `🚧 [attachment-references] feat(bridge): reference images in live events [step 5/11]` | 1,100-1,500 | Awaited materialization, dual event shapes, subscriber/orphan delivery mode, SSE memory/compatibility coverage. |
| 6/11 | `⚙️ [attachment-references] feat(bridge): retain larger transcript images [step 6/11]` | 900-1,450 | OpenCode, Codex, ACP, Cursor, and Claude output limits move to 20 MB each/50 MB aggregate while legacy projection stays 5 MiB. |
| 7/11 | `🚧 [attachment-references] feat(client): load stored image renditions [step 7/11]` | 1,500-2,000 | Typed API/repository/state support, validation, timeout, request coalescing, but delivery mode remains inline. |
| 8/11 | `🚧 [attachment-references] feat(client): cache encrypted image previews [step 8/11]` | 1,250-1,600 | Platform cache boundary/adapter, scoped atomic storage/pruning/cleanup, Cubit integration, tests. |
| 9/11 | `⚙️ [attachment-references] feat(client): render square attachment grids [step 9/11]` | 900-1,450 | Square/grid/overlay/loading/error presentation for existing and reference-capable attachment widgets; capability remains disabled. |
| 10/11 | `⚙️ [attachment-references] feat(client): load originals in the image viewer [step 10/11]` | 900-1,450 | Thumbnail-first viewer, original retry/actions, enable history/SSE reference mode, end-to-end compatibility tests. |
| 11/11 | `🌱 [attachment-references] docs: retire lazy transcript attachments [step 11/11]` | 50-200 | Final evidence and plan move to completed. |

## Step Details And Verification

### Step 1/11 - Plan

- Add this `PLAN.md`, `TRACKER.md`, and the separate prompt-upload
  `CONSIDERATIONS.md`.
- Record architecture plan review and apply valid findings before opening the
  PR.
- Run `git diff --check`. No Dart or Flutter suites are needed.

Expected result: no user-visible, wire, database, or runtime behavior change.

### Step 2/11 - Shared contract

- Add `MessageAttachment.storedImage` and update every exhaustive in-repo
  consumer to a safe compile-time placeholder without enabling delivery. Its
  required `bridgeId` comes from the bridge's existing `BridgeIdProvider`.
- Add `MessageAttachmentDelivery` with legacy `inline` defaults on
  `SessionMessagesRequest` and `RelaySseSubscribe`.
- Add typed attachment rendition request/response models and exports.
- Keep existing inline, remote, metadata, unknown, and prompt request contracts.
- Regenerate shared code; run shared model/protocol tests, affected bridge/client
  compile tests, shared analysis, and architecture implementation review.

Expected result: no user-visible behavior; new and old JSON shapes decode with
the documented defaults.

### Step 3/11 - Bridge rendition endpoint

- Add zero-collaborator `AttachmentThumbnailBuilder` beside bridge repository
  mapping/building policy with the pure-Dart thumbnail dependency and bounded,
  off-main-isolate decoding.
- Move spill storage to the platform-native shared attachment root, key its
  owner-hardened scope by plugin/backend session identity, retain files across
  archive/history/session deletion, and add versioned derived thumbnails using
  the existing atomic content-addressed write conventions.
- Add durable-scope original/thumbnail methods to `ChatHistoryRepository`; extend
  `ChatHistoryService(repository, builder)` with session-queued rendition
  selection and the single generation lane; and
  register `GetSessionAttachmentHandler(chatHistoryService)` for
  `POST /session/attachment`.
- Cover platform root resolution, cross-data-directory reuse, scope isolation,
  manual deletion degradation, original/thumbnail success, first-frame
  behavior, transparency, orientation, concurrent generation,
  corrupt/oversized input, archived-session lookup, traversal rejection, and
  response bounds.
- Remove `StoredAttachmentLocation`, archived spill DI/composition, archive
  copy, and delete-time spill purge. Do not migrate or fall back to the
  development/internal data-directory layout.
- Run bridge app focused/full tests, fatal analysis, build/codegen as required,
  and architecture implementation review.

Expected result: no normal client calls the endpoint yet; a typed request can
retrieve one E2E-ready rendition from an existing spill file.

### Step 4/11 - History references

- Thread delivery mode through handler, service, active page, and archived page
  reads.
- Inject the existing `BridgeIdProvider` into `ChatHistoryService` when history
  projection first needs to stamp required bridge identity.
- Project internal `stored_file` to `stored_image` without reading originals for
  capable requests.
- Preserve legacy inline collection budgets and metadata degradation.
- Cover mixed inline/remote/metadata/stored parts, tool attachment order, old
  stored records without size metadata, missing files, pagination, and archive
  parity.
- Run bridge app tests, fatal analysis, and architecture implementation review.

Expected result: default requests are unchanged; explicit capable requests
receive lightweight references in history pages.

### Step 5/11 - Live references

- Add `ChatHistoryService.requiresAwaitedAttachmentCapture(part:)` as the one
  predicate the Orchestrator uses to await only inline-image parts. Route every
  finalized part capture through the Orchestrator so plugin event order remains
  storage order; the listener retains message, removal, and invalidation capture.
- Add one awaited `ChatHistoryService.capturePartForDelivery` call that joins the
  per-session queue, persists once, and returns typed reference/legacy shapes.
- Produce reference and legacy-safe event shapes without a new event type.
- Calculate legacy eligibility from the complete stored logical collection so
  separate ACP image-part updates preserve the released aggregate limit.
- Store subscriber delivery mode with active/orphan queues and only adopt a
  matching-mode orphan.
- Ensure reference queues never retain original base64 while legacy queues keep
  released behavior.
- Cover multiple simultaneous old/new subscribers, reconnect replay, write
  failure fallback, ACP multi-part legacy budgeting, archive/capture ordering,
  one materialization per event, generation fencing, and local debug behavior.
- Run bridge app SSE/orchestrator/storage tests, full bridge app tests, fatal
  analysis, and architecture implementation review.

Expected result: explicitly capable SSE subscriptions receive references; old
subscriptions remain unchanged.

### Step 6/11 - Larger backend outputs

- Separate reference-retention limits from the released inline-wire limit.
- Update OpenCode, Codex, ACP, Cursor, and Claude transcript output mapping to 20
  MB per image, 50 MB aggregate, and the existing candidate-count bound.
- Keep prompt input limits and backend-specific parsing inside their plugins.
- Prove old delivery degrades exactly where it did before and capable delivery
  retains/fetches larger originals live and after replay/backfill.
- Run focused and full tests plus fatal analysis in every changed plugin and
  bridge app limit-projection tests.

Expected result: no regression for old apps; capable requests can later access
larger backend-produced raster originals.

### Step 7/11 - Client data layer

- Add the typed attachment API/repository methods for thumbnail and original.
- Extend image loading state to distinguish preview availability from original
  loading/failure without flattening them into nullable booleans.
- Retain MIME/signature/size validation for inline, remote, and stored sources.
- Add source-free sensitive-response diagnostics and assert malformed attachment
  body/base64 substrings never reach `JsonParsingError`, logs, or diagnostics.
- Thread a required attachment timeout from a named `RelayHttpApiClient` method
  through `_sendViaRelay` and `RelayClient.sendRequest`; prove ordinary requests
  retain their 30-second default and attachment requests survive beyond it.
- Add complete-request retry semantics; do not add chunk offsets or fake
  progress.
- Coalesce concurrent requests for the same scoped rendition in memory.
- Extend `MessageImageCubit` to own preview/original load and retry intents; the
  Flutter shell consumes state and never calls the repository directly.
- Require message-owned `sessionId` through widget, cubit, repository request,
  and cache key. Capture account scope from `AuthSession.currentState` at the
  repository boundary and take bridge scope from the stored reference; never
  infer either identity from global route/connection state.
- Keep both delivery-mode call sites set to `inline`.
- Run module_core focused/full tests, codegen/DI generation, analysis, downstream
  mobile analysis, and architecture implementation review.

Expected result: no user-visible behavior; the client can load a stored image
when supplied in a test fixture.

### Step 8/11 - Client thumbnail cache

- Add dumb `AttachmentThumbnailStorage` file primitives in module_core and
  `FlutterAttachmentThumbnailStorage` over the app-private OS cache directory.
- Inject the existing `TemporaryDirectoryClient` into the Flutter storage
  adapter; do not call static `path_provider` APIs from the adapter.
- Keep scoped keys, corruption recovery, in-flight coalescing, oldest-on-write
  pruning in `MessageImageRepository`; register `MessageThumbnailCacheService`
  as a lazy core singleton, explicitly resolve it during mobile DI after the
  storage binding, and retain generation-fenced cleanup/disposal; keep backup
  exclusion in the platform IO configuration.
- Integrate the cache behind `MessageImageRepository` and the existing
  `MessageImageCubit`; widgets render emitted bytes with standard Flutter image
  providers and receive no repository, public URL, or relay/auth token.
- Run module_core tests, app platform/cache tests, codegen/DI generation, mobile
  analysis/tests including account-switch/mobile activation and desktop DI
  startup without the storage binding, and architecture implementation review.

Expected result: no reference delivery is enabled, but stored-image fixtures
reuse cached encoded thumbnails across widget remounts/app initialization.

### Step 9/11 - Square attachment presentation

- Add one attachment collection/grid widget and migrate user/tool collections
  plus contiguous assistant file parts without changing chronology.
- Render square center-cropped images, metadata overlays, stable loaders,
  explicit retries, and square metadata-file fallbacks.
- Preserve current remote URL safety and viewer behavior.
- Cover one/two/four attachments, narrow/wide layouts, user/assistant/tool
  contexts, accessibility, long/missing metadata, reduced motion, loading,
  rejection, and retry.
- Run focused session-detail widget tests, full mobile tests, and mobile
  analysis.

Expected result: current inline and remote attachments adopt the final square
presentation; stored delivery remains disabled.

### Step 10/11 - Viewer and activation

- Open stored images with the thumbnail already visible, automatically load the
  original, retain the thumbnail on failure, and retry the complete original.
- Release original bytes from the tile-owned cubit when the viewer route closes;
  retain only thumbnail-ready state and no completed-original repository cache.
- Enable copy/share/save only after validated original bytes arrive.
- Preserve current single-image gestures, route/back behavior, Hero transition,
  remote open-original action, and animated-original behavior.
- Set history requests and SSE subscriptions to `storedReference`.
- Cover all four app/bridge compatibility pairings, live/history/archive parity,
  cache cold/warm behavior, original timeout/retry, missing-after-thumbnail,
  logout during fetch/write, required session scoping, original release after
  close, action gating, GIF/WebP preview/original behavior, and no eager
  original request while scrolling.
- Run module_core and mobile focused/full tests, analysis/codegen, a local bridge
  integration check with cold/warm history and reconnect, and architecture
  implementation review.

Expected result: capable app/bridge pairs deliver the complete approved user
experience; old peer combinations remain usable.

### Step 11/11 - Retire plan

- Confirm Steps 1-10 merged in order and record final PRs and verification.
- Move `.plan/active/attachment-references/` to
  `.plan/completed/attachment-references/` in one commit.
- Run `git diff --check`. No Dart/Flutter suites or architecture review are
  needed for this documentation-only step.

Expected result: no user-visible, wire, database, or runtime behavior change.

## Material Risks

| Risk | Mitigation |
|---|---|
| Reference event outruns file persistence. | Await the single queued image-part capture and its typed result before enqueue. |
| Archive races live materialization. | Capture, projection, export, flip, and purge share the existing per-session queue. |
| Thumbnail generation races archive or purge. | Original selection, generation, and final derived write share the existing per-session queue. |
| Legacy ACP image parts exceed their old aggregate budget. | Project each event against the complete stored logical collection, not only the current part. |
| Old app receives an unknown source and hides it. | Default both independent delivery surfaces to inline and shape per subscriber/request. |
| New app requests a route from an old bridge. | It only calls the route for a received `stored_image`; old bridges never emit that variant. |
| A page triggers several expensive decodes. | One fixed rendition, lazy generation, decoded-pixel ceiling, and one coarse generation lane. |
| A full 20 MB response is slow on cellular. | Dedicated timeout, thumbnail remains visible, whole-image retry; chunking remains a documented upgrade path. |
| Thumbnail cache leaks decrypted content through backups or account reuse. | App-private cache, scoped keys, backup exclusion, and authenticated-scope cleanup. |
| Plugin limit bump creates an oversized legacy frame. | Legacy projection retains the independent 5 MiB collection budget before SSE/history serialization. |
| Active Claude work changes relevant mapper files. | Rebase Step 6 on then-current main and update every in-repo plugin consumer in lockstep; do not preserve unpublished intermediate shapes. |

## Plan Review Record

Architecture plan review rejected the first draft on 2026-08-10 with four
actionable findings: one live materialization layer skip plus unnamed bridge
owners, Flutter cache policy incorrectly left ambiguous at the platform
adapter, and image-provider ownership/injection left unspecified. The draft now
routes live writes through `ChatHistoryRepository`, names the bridge builder,
handler with required dependencies, keeps cache policy in
`module_core`, and routes image loading through `MessageImageCubit`. Subsequent
PR review further moved the thumbnail builder beside Layer-2 attachment mapping,
made attachment parse failures content-redacted, named the timeout path through
both client transport layers, and then consolidated live capture/projection on
the existing session queue. It also pins message-owned session scope, releases
viewer originals, injects the directory client, and generation-fences logout
cleanup. Per repository process, the corrected draft was not re-reviewed merely
to obtain an approval verdict. A focused second architecture review accepted the
revised capture, legacy collection, viewer, cache, and session-scope seams but
rejected the unnamed capture-split predicate. The plan now assigns that invariant
to `ChatHistoryService.requiresAwaitedAttachmentCapture(part:)`; this direct
finding correction was not reviewed again.
