# Fast New Session Launch

## Status

- **Plan slug:** `fast-new-session-launch`
- **Status:** Active - plan ready for review
- **Plan date:** 2026-08-13
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `14a4e405`
- **Current branch:** `speed-up-new-session-load`
- **Delivery:** six PRs; Step 1 raises this plan before production work

This plan and `TRACKER.md` are the authority for implementation. The code and
released product behavior remain authoritative where this document becomes
stale.

## Goal

Make pressing Send on the new-session composer feel immediate and remove
avoidable bridge latency without inventing a provisional session lifecycle.

The delivered experience is:

1. Send immediately replaces the composer presentation with the normal
   session-detail chrome, a generic `New session` title, one activity indicator,
   and honest rotating launch copy. The URL remains
   `/projects/<projectId>/sessions/new` until the bridge returns a real durable
   session.
2. The bridge creates the backend session, waits for the initial prompt,
   attachment, or slash command to be accepted, commits the stable Sesori
   `ses_...` binding, and returns the canonical catalog `Session` without waiting
   for generated metadata or backend title propagation.
3. The client replaces `/projects/<projectId>/sessions/new` with the real
   `/projects/<projectId>/sessions/<ses-id>` route. Existing SSE plus the detail
   snapshot hydrate the final title and transcript.
4. A failed or unconfirmed creation returns automatically to the filled
   composer. Timeout/disconnect/bad-response copy warns that the session may
   still appear in the list before the user resubmits.
5. Leaving while creation is in flight retains today's background-launch
   behavior; the durable session appears only after bridge commit.

## Non-Goals

- No bridge-issued pending session ID before plugin creation.
- No pending-session database row, route, wire state, retry registry,
  idempotency key, or exactly-once claim.
- No automatic resend, newest-session guessing, list polling, or optimistic
  prompt/transcript rendering.
- No cancellation or rollback when the user leaves the launch view.
- No staged/partial `SessionDetailLoaded` snapshot. The existing coherent
  aggregate detail load remains intact.
- No plugin-name branches or plugin-specific implementation changes.
- No auth-server endpoint versioning in this series.
- No general background-job framework, progress-phase protocol, launch
  analytics event, duration bucket, or permanent timing log.

## Current Behavior And Findings

### Identity

Sesori already owns a backend-neutral stable session ID. `SessionRepository`
persists a unique `(pluginId, backendSessionId)` binding and exposes a random
`ses_<32 hex>` ID to clients. However, it allocates that ID only after
`BridgePluginApi.createSession` returns. There is no current bridge session to
navigate to before backend creation.

Relevant seams:

- `bridge/app/lib/src/bridge/repositories/session_repository.dart`
  commits the mapping and publishes `SessionBindingsCommitted` before returning.
- `bridge/app/lib/src/bridge/repositories/mappers/session_catalog_mapper.dart`
  builds the canonical client session from the committed row.
- `bridge/app/lib/src/bridge/repositories/mappers/plugin_session_mapper.dart`
  currently builds an intermediate plugin-shaped response that is enriched
  afterward.

### Current critical path

`SessionCreationService.createSession` currently waits for:

1. project-handle validation;
2. plugin routability/startup and metadata generation in parallel;
3. metadata completion;
4. dedicated-worktree preparation or in-place HEAD capture;
5. backend session creation and initial prompt/attachment acceptance;
6. durable stable-ID binding;
7. slash-command acceptance, when selected;
8. generated-title persistence and backend propagation; and
9. response enrichment.

Metadata is best-effort but has a 45-second deadline and one 401 retry. A slow
metadata call can therefore outlive the client's 30-second relay request timeout
even when backend creation itself succeeds.

The safe early-response boundary is after the initial input and optional command
have been accepted and the stable binding is committed. Returning before that
would weaken the common plugin contract, hide currently synchronous failures,
and make Claude/OpenCode cleanup and restart recovery unreliable.

### Current client transition

`NewSessionCubit` emits `NewSessionSending` immediately, but
`NewSessionScreen` keeps the composer mounted under a dimming loading card. It
navigates only after `ApiResponse<Session>` succeeds. The real detail route then
loads its existing coherent snapshot.

The create request has no idempotency key. A timeout or relay response loss can
occur after bridge side effects, so any automatic or one-tap resend can create a
second session and worktree.

## Locked Product Decisions

- The immediate transition is presentation-only and remains on the
  `/projects/<projectId>/sessions/new` route until a durable Sesori ID exists.
- Launching uses normal detail chrome, a centered status, and refreshed friendly
  rotating copy. It does not fabricate transcript rows.
- A reusable presentation widget is allowed; no client attempt model is added
  before the bridge supports pending attempts.
- `New session` is an acceptable temporary title; the generated title updates
  quietly later.
- Metadata does not choose dedicated-worktree names. Branch and worktree use the
  same locally generated lowercase ASCII `color-animal` slug, for example
  `blue-otter`.
- The vocabulary is a small curated code-owned list. Naming is local,
  dependency-free, backend-neutral, and reusable for future workspace names.
- On collision, sample another pair for a bounded number of attempts. If those
  attempts are exhausted or the final create races, append the existing secure
  short hexadecimal suffix to the last pair rather than losing workspace
  isolation.
- Creation failures return automatically to the filled composer. Text/voice
  provenance, slash command, and attachments are restored. The user explicitly
  presses Send again.
- Every creation-originated error uses copy that says Sesori could not guarantee
  that no session was created and that it may still appear in the list. Timeout,
  response loss, malformed/empty success, and generic failures are inherently
  uncertain; server rejection is also covered because command rejection can
  occur after durable commit.
- Back continues launch in the background, as today.
- Implementation is plugin-agnostic. Automated bridge tests prove the normalized
  contract; release verification enumerates every plugin registered in the build
  under test. Unregistered packages receive no product claim or plugin-specific
  production code.
- Generated title runs fully off the response path. A user title must not be
  overwritten if avoiding that race is a focused conditional write rather than
  a new lifecycle state machine.
- Detail first-content staging is explicitly out of scope. The real detail
  route keeps its coherent snapshot and uses the same launch presentation while
  loading, avoiding a launch-view-to-spinner regression.
- Performance proof is deterministic timing/order tests plus recorded manual
  before/after measurements, not permanent telemetry.

## Design

### 1. Client launch and retry state

Add one sealed, immutable new-session submission snapshot in `module_core` with
variants that preserve valid combinations:

- text submission: exact trimmed `ComposerDraft` (including voice spans) plus an
  unmodifiable attachment list;
- command submission: exact trimmed `ComposerDraft` plus non-null command and no
  attachment field.

The snapshot does not duplicate agent/model/variant/plugin/workspace settings.
Agent/model/variant/plugin remain in the existing new-session configuration, and
the parent `_NewSessionBodyState` keeps the dedicated-worktree toggle while only
its body switches presentation. The snapshot exists only to restore authored
composer content.

`NewSessionSending` carries the snapshot. A
`NewSessionRestoringSubmission` variant carries that same snapshot after
failure; once the remounted composer consumes it, a
`NewSessionCreationError` variant retains the warning but no authored bytes.
Discovery/options errors remain a separate variant with no submission or
creation warning. This makes impossible states explicit instead of coordinating
nullable text, command, attachment, and warning fields.

Discovery, option, capability, and reconnect refreshes update the configuration
inside both `NewSessionRestoringSubmission` and `NewSessionCreationError`; they
must not replace either with idle or a discovery error, drop the attachment
snapshot before its consumed acknowledgement, or erase the uncertain-outcome
warning. The warning is cleared only by the next explicit submission (which
enters `NewSessionSending`) or by leaving the new-session route. This requires
replacing the current direct idle emit in `_discoverPlugins` with the same
variant-preserving state update used by the other refresh paths.

`PromptInput` extends its submit callback with the exact trimmed
`ComposerDraft` it already computes before clearing the controller. This is the
only source that can preserve voice-origin spans accurately; reconstructing a
draft from text plus `ComposerInputMode` would falsely mark all text as typed or
all text as voice. `SessionDetailCubit` continues to derive its existing queue
and analytics values from that draft without persisting the submission.

`NewSessionCubit` builds the snapshot before the first async gap. If it is still
open when creation fails, it:

1. restores the Cubit's cached `ComposerDraft` and the draft repository from the
   snapshot before emitting any state that remounts `PromptInput`;
2. restores the staged command when present;
3. emits the transient restoring state carrying the attachments until the
   composer remounts;
4. retains current outcome analytics semantics, with explicit documentation that
   unconfirmed outcomes remain counted by the released failure event until
   idempotent creation exists.

If the Cubit was closed because the user left while creation continued, failure
does not restore the shared draft repository, staged command, or attachments;
the snapshot is released when that background request settles. This prevents an
abandoned submission from reappearing on a later visit to the new-session route.

The sending branch removes `PromptInput` from the tree. On failure the composer
therefore runs a fresh `initState`, copies `initialAttachments` exactly once,
and schedules a post-frame acknowledgement. The Cubit then moves from the
restoring variant to the ordinary creation-error variant while the composer
keeps a stable key, so Flutter preserves the newly staged attachments and the
state drops its snapshot reference. Ordinary rebuilds never reapply initial
attachments. On success the sending state is replaced and releases the snapshot.
Leaving the route deliberately lets creation continue in the background, so the
in-flight method/request retains its submission bytes until the response or the
client's 30-second timeout settles; then the closed Cubit and snapshot become
collectible. No extra cache outlives that request, no attachment is copied at the
byte-buffer level, and no attachment is persisted.

`PromptInput` gains required `initialAttachments` and
`onInitialAttachmentsConsumed` inputs used only at construction or a real
`draftIdentity` change. It copies attachment objects into its existing private
mutable staging list, invokes the one-shot consumed callback post-frame, and
never reapplies them on an ordinary parent rebuild. It does not expose
attachment ownership or persist bytes. Existing-session callers pass `const []`
and a no-op callback.

`NewSessionCubit` emits `NewSessionSending` synchronously and keeps its creation
intent surface-neutral. For attachment submissions, a `SessionApi` serializer
first yields one event-loop turn, then incrementally base64-encodes attachment
bytes and assembles request JSON in bounded chunks, yielding between chunks.
This lets Flutter render the scheduled launch frame without passing frame
lifecycle into shared business logic and without copying retained attachment
buffers through an isolate port. Text-only requests retain the direct path.

Bounded serialization continues through the existing relay envelope:
`RelayHttpApiClient` passes the pre-encoded inner body as today, and
`RelayClient` incrementally JSON-escapes that body and UTF-8-encodes the complete
`RelayMessage.request` envelope into its plaintext byte builder with yields
between bounded chunks. Encryption still receives the complete plaintext bytes
and the wire JSON shape remains byte-equivalent; no new relay or client-bridge
contract is introduced. Small/non-request relay messages retain the direct encoder.
The request and all existing acceptance semantics remain otherwise synchronous.

The shared crypto boundary also avoids boxed frame assembly:
`RelayCryptoService.encrypt` returns a preallocated `Uint8List` containing nonce,
ciphertext, and MAC via `setRange`; `SessionEncryptor` exposes that typed result,
and `RelayClient` preallocates only the required version-prefixed frame. The
cipher algorithm and byte layout remain unchanged.

### 2. Reusable detail-shaped launch presentation

Replace `NewSessionLoadingOverlay` with `PregoLaunchStatus`, a reusable
presentation primitive at
`client/module_prego/lib/components/loaders/prego_launch_status.dart`, exported
from `module_prego.dart` and covered in that package's widget tests. It accepts
only a semantics label and already-localized message list; it knows nothing about
sessions, Cubits, routes, plugins, prompts, or transport. `module_prego` owns the
reduced-motion-aware message timer, activity indicator, layout, and transitions,
but owns no product copy or localization dependency.

The app remains the owner of session chrome and localization:

- `NewSessionScreen` renders its own detail-shaped `PregoGlassScaffold` plus
  `PregoLaunchStatus` while `NewSessionSending`;
- `SessionDetailBody` keeps its existing scaffold/title/back/split logic and
  replaces only the `SessionDetailLoading` body with `PregoLaunchStatus`;
- `client/app/lib/l10n/app_en.arb` owns refreshed broad messages that remain
  honest across plugin startup, workspace preparation, backend creation, and
  snapshot loading. They are presentation rotation, not authoritative phases.

This removes the black scrim, card, entrance animation, hidden composer, and
fake progress semantics. A future pending-session route can reuse the Prego
status primitive without inheriting today's route-local Cubit state.

On error, `NewSessionScreen` immediately remounts the normal composer with the
restored submission and the existing error banner. Every creation-originated
failure adds a warning that Sesori could not guarantee that no session was
created and that resending may duplicate it. The current transport/server error
taxonomy cannot distinguish project validation from a slash-command rejection
that occurs after durable commit, so narrower copy would be dishonest.

The URI remains `/projects/<projectId>/sessions/new` throughout sending.
Success still uses `replaceRoute` only after a real `Session.id` returns,
preserving late-navigation hijack protection and split-view behavior.

### 3. Local workspace naming

Move naming ownership into `WorktreeService`, which already owns collision
checks and worktree creation. It generates a candidate from static curated
`colors` and `animals` lists using `Random.secure`, and uses that exact slug for
both branch and worktree directory.

Algorithm:

1. Resolve the project, git readiness, and base branch/commit as today.
2. Sample a color-animal pair and check branch existence.
3. Retry distinct sampled pairs up to the current bounded creation-attempt
   budget; do not add an unbounded loop or enumerate the whole vocabulary.
4. If normal attempts are exhausted, make one final attempt with a secure short
   suffix on the last pair.
5. Preserve existing non-git, commitless, base-resolution, and genuine Git
   creation failure fallback semantics.

The generated words are lowercase ASCII and inherently valid Git/path slugs, so
the metadata-oriented preferred-name parameter and runtime unsafe-name validator
are deleted. Durable branch/worktree/base facts and the worktree system prompt
remain unchanged.

### 4. Early canonical response

Change `SessionRepository.createSession` to return the canonical catalog
`Session` mapped from the row committed in its existing transaction. This
preserves:

- stable Sesori ID;
- stable project attribution, including moved bridge-derived projects;
- actual working directory;
- worktree presence; the current-branch field remains null until normal branch
  observation populates it;
- created/updated time;
- plugin attribution and prompt defaults; and
- bridge-owned/catalog title precedence.

At this boundary the bridge-owned title is still null. The initial response
therefore uses `row.title ?? row.catalogTitle`: the backend's creation title when
it supplied one, otherwise null. A later generated title intentionally becomes
the bridge-owned override and may supersede the backend catalog title, matching
today's title precedence, but its conditional write cannot supersede an explicit
user/local rename.

On route replacement, `NewSessionScreen` passes `session.title` through as the
nullable `sessionTitle`; it deletes the current `?? ""` conversion. This
preserves missingness so `SessionDetailBody` shows its localized `New session`
fallback until the snapshot or late title supplies a real value.

No PR identity verification occurs because creation has never supplied a
verified GitHub login. The single-session `enrichSession`,
`enrichPluginSession`, and now-unused plugin-session mapping helpers are removed;
batch `enrichSessions` remains for list reads.

`SessionCreationService` continues to await project validation, plugin
routability, git/worktree preparation, backend creation, first-input acceptance,
durable commit, and slash-command acceptance. It then tracks late title
completion and returns the canonical committed session immediately.

### 5. Managed late generated title

Metadata starts only after durable creation and first-input/slash-command
acceptance. Unknown projects and failed creations therefore cause no metadata
side effect, while each successfully accepted first session still reaches the
auth server's activation path. Metadata no longer overlaps worktree/plugin
creation, but because it starts as tracked late work immediately before the
canonical response returns, it cannot delay that response or escape lifecycle
ownership on an earlier failure path.

Replace the layer-skipping `MetadataService` with the normal bridge dependency
flow while keeping the auth server as one provider boundary:

- Layer 1 existing `SesoriServerApi` owns the typed metadata POST alongside its
  other auth-server operations, including abort/deadline behavior, a method-aware
  status exception, token acquisition through injected `TokenRefresher`, one
  typed 401 force-refresh/retry, and the title-only response DTO;
- Layer 2 `SessionMetadataRepository` under `bridge/app/lib/src/repositories/`
  owns the 500-character payload normalization and maps the typed API result;
- Layer 3 `SessionCreationService` consumes the repository and owns the product
  decision that metadata failure is logged and degraded to no generated title.

This follows the bridge architecture's explicit authenticated-provider boundary:
`SesoriServerApi` consumes `TokenRefresher` and owns the complete authenticated
HTTP operation. The repository does not inspect HTTP status or coordinate token
lifecycle.

The title-only DTO ignores the deployed response's extra `branchName` and
`worktreeName` keys. The auth server response remains unchanged for released
bridges. API/repository errors retain status/cause/stack context; only the
creation service converts them into the best-effort result.

Late work is owned by `SessionCreationService`, not by a detached route future.
Immediately after all synchronous acceptance gates pass, the service starts and
registers the complete metadata-to-title workflow in the tracked set before it
can return the canonical session:

- one set tracks accepted title-completion futures;
- standalone `TokenManager` refresh HTTP gains an injected request deadline, so
  token acquisition always settles; the desktop control-channel implementation
  retains its existing timeout;
- one shutdown signal aborts in-flight metadata HTTP;
- `beginShutdown` stops accepting new late work and triggers that request abort;
- `drain` waits for tracked title work before session operations/listeners and
  the shared HTTP client are disposed.

`drain` awaits the actual tracked workflows, never only a race wrapper while a
losing operation continues. `SesoriServerApi` aborts an in-flight metadata HTTP
request when shutdown wins; token acquisition settles through its provider's
bounded request behavior before the tracked workflow completes. A typed request
abort is treated as expected only when the shutdown signal is set; deadline,
token, status, and parse failures retain their original context, are logged by
the creation service, and fail soft.

The composition root wires lifecycle ownership explicitly:

1. `Orchestrator.create` constructs API -> repository ->
   `SessionCreationService`, passes the service to the create handler, and also
   injects that same instance into `OrchestratorSession`.
2. `OrchestratorSession.beginShutdown` first fences
   `RoutedRequestDispatcher`, then calls
   `SessionCreationService.beginShutdown` to stop late-title admission and abort
   metadata HTTP. An already accepted create may still finish its request, but
   if it reaches durable commit after this fence it returns without scheduling a
   generated title; title generation is best-effort during shutdown.
3. The normalized `SessionEventDispatcher.events` subscription moves out of the
   broad `_subscriptions` composite into its own field. `_teardown` cancels
   external/plugin event producers but deliberately keeps both that normalized
   event consumer and `SessionMutationListener` subscribed. It drains routed
   requests and relay completions first, so no accepted route can still reach
   the late-title registration seam.
4. `_teardown` then awaits `SessionCreationService.drain`. While it drains, a
   successful title mutation flows through the still-live listener and
   normalized event consumer. Afterward it disposes `SessionMutationListener`
   to fence the final local source, then disposes `SessionEventDispatcher` while
   the normalized consumer is still live; dispatcher disposal waits its existing
   per-plugin tails and closes the stream only after every normalized output was
   published.
5. `_teardown` then awaits the latest `_pluginEventProcessingTails` and
   `_pendingPartCaptures`, which drains delivery of those final normalized
   outputs, and only then cancels the normalized event subscription.
6. Only after the full event path drains does `_teardown` begin/drain
   `SessionOperationDispatcher` and dispose `SessionMutationDispatcher`. The
   shutdown coordinator closes the shared HTTP client/database only after the
   whole `OrchestratorSession` drain phase.

This order gives every tracked title task live mutation/event dependencies,
admits no task after the drain snapshot, and requires no global job registry.

Generated title applies through `SessionMutationDispatcher` under the existing
session-family lane. Add an atomic repository/DAO operation that writes only
when the bridge-owned title is still null. A zero-row result means a user rename
or deletion won; no plugin propagation follows. This is one focused guard for
an ordinary reachable flow, not a title state machine.

Generalize the dispatcher's existing deletion-only local mutation stream to a
sealed stream with `titleUpdated(Session)` and `deleted(Session)` variants.
Rename `SessionDeletionListener` to `SessionMutationListener`; it forwards the
appropriate event through `SessionEventDispatcher`. A local title success emits
the existing backend-neutral `session.updated` wire event immediately, then
performs best-effort plugin propagation. Clients already consume this event in
session list and detail cubits, so no new wire model is needed.

## Failure Semantics

- **Still synchronous:** invalid project, unroutable backend, git/worktree setup
  required to determine the actual working directory, backend session creation,
  initial prompt/attachment rejection, slash-command rejection, and durable
  binding failure.
- **Best-effort after response:** metadata generation, bridge-owned generated
  title application, and backend title propagation.
- **Client creation failure:** restore the composer with a duplicate-risk
  warning for every creation-originated error; never auto-resend. Timeout,
  response loss, malformed/empty success, generic errors, and even some server
  rejections cannot prove that no durable session was committed.
- **Background leave:** do not cancel bridge work. Existing list SSE/reconnect
  reconciliation remains authoritative once the binding commits.
- **Shutdown:** cancel metadata HTTP, drain tracked title completions, then close
  operation/event/mutation infrastructure. Do not persist prompt or pending title
  work across process restart; generated title is explicitly best-effort.

## Compatibility

- Client and bridge wire contracts are unchanged. A new client still waits for
  a real `Session` response from an older bridge; an older client receives the
  same `Session` shape from the new bridge, only sooner and initially without a
  generated title when metadata is slow.
- Older clients already accept nullable `Session.title` and consume later
  `session.updated` events.
- No database migration is needed.
- The auth server continues returning `title`, `branchName`, and `worktreeName`
  because released bridges require all three fields. The new bridge ignores the
  latter two. Narrowing that external response is deferred until those released
  bridges are outside support.
- Production behavior remains plugin-neutral through `BridgePluginApi`.

## Cleanup Assessment

### Delete in this series

- `client/app/lib/features/new_session/new_session_loading_overlay.dart`.
- Its black scrim/card/entrance animation, overlay slot, body `AbsorbPointer`,
  old widget keys, and overlay-only tests.
- The direct `cue` dependency from `client/app/pubspec.yaml`; `module_prego`
  keeps its independent dependency.
- Obsolete loading copy or keys after refreshed copy moves to the shared launch
  view; generated localization outputs are regenerated, never hand-edited.
- `SessionMetadata.branchName` and `SessionMetadata.worktreeName` plus the old
  generated bridge model output; Step 3 replaces them with the title-only API
  response DTO and regenerates its output.
- `preferredBranchAndWorktreeName`, the metadata preferred-name branch, its
  runtime safe-name validator, and tests/fake fields that exist only for that
  path.
- The synchronous `_maybeRenameSession` response-tail helper.
- `SessionRepository.enrichSession`, `enrichPluginSession`, and plugin-session
  mapping helpers that have no production callers after canonical creation
  return.
- `SessionDeletionListener` and deletion-only stream naming, replaced in place
  by one local mutation stream/listener rather than adding a second stream.
- Tests that prove the obsolete plugin-start/metadata-join ordering or preferred
  AI worktree names; replace them with response-not-gated, local naming, late
  title, and shutdown tests.

### Keep because still required

- Generated title, auth/token refresh, first-message truncation, and the metadata
  endpoint activation side effect through the new API/repository layers.
- Durable `Session` and database title/branch/worktree/base fields.
- Explicit user rename APIs and every plugin's `renameSession` implementation.
- `SessionMutationDispatcher` family serialization.
- `NewSessionSending`, duplicate-submit protection, background-launch snackbar,
  `ModalRoute.isCurrent` navigation guard, and existing detail snapshot loading.
- Existing worktree fallback for non-git, commitless, unresolved-base, and real
  Git command failure.
- Existing session-created/binding buffering and SSE replay machinery.

### Deferred cleanup

- Auth-server response narrowing/removal of generated branch/worktree values,
  solely because released bridges deserialize them as required fields.
- Replacing the metadata endpoint's activation side effect with a dedicated
  activation outcome.
- Creation idempotency/pending-session persistence and true instant stable URLs.
- Detail snapshot staging and the unused PR enrichment in `/session/detail`;
  the former overlaps active refresh/reconciliation work and neither is required
  for the approved opening-speed scope.

### Explicitly out of scope

- Broad `SessionRepository.enrichSessions` or PR-sync refactoring.
- Worktree cleanup redesign after plugin creation failure.
- Renaming existing persisted worktrees or rewriting arbitrary `session-*` test
  fixtures unrelated to generation.
- Changing plugin prompt semantics, session options discovery, relay timeout,
  or session-detail refresh reconciliation.

## Complexity Budget

### New mutable parts

1. **Client submission snapshot:** one immutable state-owned object while a
   launch is sending or being restored. It is required to preserve memory-only
   attachments and voice/command intent across the immediate visual transition;
   the still-mounted screen State retains the independent workspace toggle.
2. **Late-title future set:** one `Set<Future<void>>` owned by
   `SessionCreationService`, required so post-response title work cannot outlive
   bridge dependencies.
3. **Late-title abort controller/signal:** one shutdown signal shared by
   metadata requests, required to keep graceful shutdown from waiting for the
   45-second metadata deadline.
4. **Memoized drain future/accepting flag:** lifecycle state local to the same
   service, required for idempotent shutdown and no post-drain admission.

### Net coordination

- Zero new database columns or persisted states.
- Zero pending-session maps, queues, timers, retry registries, correlation IDs,
  long-lived dedupe sets, or plugin-specific branches. Worktree naming may hold
  at most the three sampled slugs in one call so retries are actually distinct;
  that ephemeral local set is bounded by the existing attempt count.
- Zero net long-lived stream controllers/subscriptions: the deletion-only
  mutation stream/listener is generalized in place.
- One UI timer, replacing rather than adding to the current rotating-copy timer.
- No prompt/transcript persistence and no attachment persistence.
- One transient sealed restore state and one post-frame consumption callback;
  neither retains state after the composer copies the snapshot.

If implementation needs a pending-attempt registry, per-session title map,
second mutation stream/listener, or partial-detail reconciliation machinery,
stop and ask before expanding scope.

## Delivery Plan

| Step | Exact PR title | Target | Scope |
|---|---|---:|---|
| 1/6 | `🌱 [fast-new-session-launch] docs: plan faster new-session launch [step 1/6]` | 750-900 lines | Add this reviewed plan and tracker only. |
| 2/6 | `🌿 [fast-new-session-launch] feat(bridge): use local workspace names [step 2/6]` | 200-500 lines | Generate color-animal worktree/branch slugs and remove obsolete preferred-name code/tests. Metadata response fields are removed once in Step 3 with the API/repository replacement. |
| 3/6 | `🚧 [fast-new-session-launch] feat(bridge): return sessions before generated titles [step 3/6]` | 950-1,450 lines | Add shared typed metadata request plus bridge API/repository layering, return canonical committed sessions, run title generation off the response path with exact shutdown ownership, conditional local title update, local `session.updated`, generated output, and obsolete-path deletion. |
| 4/6 | `⚙️ [fast-new-session-launch] feat(client): open launching sessions immediately [step 4/6]` | 800-1,400 lines | Add sealed submission restoration, reusable Prego launch status, detail-shaped launch/loading, honest error warning, delete overlay/dependency/tests, regenerate state/localization. |
| 5/6 | `🌱 [fast-new-session-launch] docs: define launch regression coverage [step 5/6]` | 80-180 lines | Reconcile affected regression docs and complete cleanup audit against actual implementation. |
| 6/6 | `🌿 [fast-new-session-launch] test: verify faster new-session launch [step 6/6]` | 80-250 lines | Run the recorded level/matrix, record automated/manual results and timings, then move this plan from `active` to `completed` only on full required coverage. |

Each implementation PR must stay below the 1,500 changed-line soft cap. If a
step exceeds its target, prefer removing unnecessary machinery or splitting
tests by owner without changing the fixed six-step lifecycle. Do not combine the
bridge and client production steps into one large PR.

## Per-Step Verification

### Step 2

- `bridge/app`: focused `worktree_service_test`, creation handler/service tests,
  `dart analyze --fatal-infos`, and relevant package tests.
- Prove lowercase ASCII `color-animal`, same branch/worktree slug, pair retry,
  suffix fallback, existing non-git/commitless/Git-failure behavior, and no
  metadata dependency.

### Step 3

- `shared/sesori_shared`: metadata request source/codegen, tests, and strict
  analysis.
- `bridge/app`: metadata API/repository, creation service/repository, mutation
  dispatcher/listener, event dispatcher, routing, and shutdown tests plus
  `dart analyze --fatal-infos`.
- Prove a gated/failed metadata request cannot gate a successful create response.
- Prove first prompt/attachment and slash-command acceptance remain before 2xx.
- Prove returned session is queryable and has canonical project, directory,
  worktree presence, prompt-default, plugin, time, and initial
  backend/catalog-title facts before response. Assert the current branch remains
  null until normal branch observation; the generated branch plus base
  branch/commit remain durable bridge facts but are not exposed by this creation
  response.
- Prove late title reaches list/detail through existing `session.updated`, user
  rename/deletion wins, propagation failure retains the local title, and shutdown
  aborts metadata HTTP and drains the actual underlying workflow before disposing
  dependencies. Cover a stalled standalone token refresh settling at its request
  deadline without an unhandled future.

### Step 4

- `client/module_core`: new-session cubit/state tests and strict analysis.
- `client/module_prego`: launch-status timer, reduced-motion, semantics, export,
  widget tests, and analysis.
- `client/app`: new-session, split-shell, detail-title/loading, accessibility,
  reduced-motion, navigation, and attachment restoration widget tests plus
  analysis.
- `shared/sesori_shared`: crypto layout/typed-return tests and strict analysis;
  `bridge/app`: relay encryption/framing tests and strict analysis.
- Validate mobile/desktop client shells and bridge callers because Step 4 changes
  shared client packages and crypto.
- Prove URI remains `/projects/<projectId>/sessions/new` while unresolved,
  duplicate Send is blocked, Back keeps background launch, late success cannot
  hijack another route, success replaces with real ID while retaining nullable
  title fallback, every failure restores text/voice/command/attachments, and
  every creation-originated error warns before manual resend. Cover failure
  followed by reconnect/discovery refresh during both restoration variants, and
  prove background failure after route exit does not repopulate the shared draft.
- With a maximum-sized attachment fixture, prove bounded serialization yields
  before and between chunks across attachment base64, inner request JSON, and
  outer relay-envelope JSON/UTF-8 encoding. Prove it preserves the exact wire
  payload, does not copy attachment buffers through an isolate, and does not
  block launch rendering; do not use a wall-clock-only test.
- Prove encryption returns the exact existing nonce/ciphertext/MAC layout in a
  preallocated `Uint8List` and final framing does not materialize boxed integer
  lists for the maximum-sized payload.
- Prove mixed typed/voice spans survive submission failure exactly, and the
  existing-session queue plus analytics retain their released input-mode
  behavior after the richer callback input.

## Regression Documentation And Final Matrix

Affected feature documents:

- `docs/regression/session-creation-and-options.md` - authoritative capability;
- `docs/regression/projects-and-sessions.md` - dedicated workspace naming and
  durable list/title update;
- `docs/regression/attachments-and-images.md` - memory-only attachment
  restoration after failed creation.

`session-turns.md` is inspected for consistency but should not change unless the
implementation alters existing-session sends, which is not planned.

The durable-plan lifecycle intentionally reconciles these documents in the
penultimate Step 5. Steps 2-4 record doc deltas in `TRACKER.md` as they merge,
and the series is not release-complete until Step 5 updates the active contracts;
this follows `docs/regression/README.md` rather than scattering partial feature
wording across production steps.

### Highest required level

**L3 Release** is required because the delivered claim includes client
navigation/presentation plus bridge-to-plugin creation across production
plugins. Automated tests are not a substitute for that client/plugin boundary.

### Required matrix

- **Client:** one release-target phone platform, narrow and wide/split layouts,
  normal and reduced motion.
- **Bridge:** release-target host, headless bridge, warm and cold plugin start.
- **Plugins:** enumerate every plugin registered by the production
  `knownPlugins` composition in the build under test. For each, exercise a text
  prompt; exercise attachment creation only where declared; exercise slash
  command where supported. One representative plugin additionally covers
  metadata slow/failure, title update, and dedicated-worktree naming because
  those behaviors are bridge-owned after the normalized boundary.
- **Workspace:** in-place and dedicated; dedicated includes normal generated
  name, collision retry, and suffix fallback through automated tests.
- **Failure:** definitive rejection plus timeout/relay-loss simulation restoring
  the composer with honest warning; reconnect/discovery completion must not
  erase that warning before another explicit submission or route exit.
- **Compatibility:** current client against the minimum supported released
  bridge and current bridge response shape against an older released client or
  an equivalent wire fixture. Older bridge remains slower but functional;
  nullable initial title and later update remain decodable.

### Measurements

Record privacy-safe elapsed values only; never prompts, titles, names, paths,
IDs, or attachment bytes.

For warm and cold representative runs, record:

1. Send to launch view rendered;
2. Send to durable create response/route replacement; and
3. Send to complete detail snapshot.

Compare baseline and final builds under the same plugin/workspace conditions.
The acceptance criterion is structural, not a brittle wall-clock SLA:

- launch view appears in the next rendered frame without waiting for bridge
  response or synchronous attachment/request/relay-envelope encoding; a
  maximum-sized fixture verifies the launch view paints and remains schedulable
  while every large serialization stage proceeds;
- metadata/title completion cannot extend create response time;
- route replacement occurs only after the real session is durable/queryable;
- no accepted first input or command is moved behind the success response.

## Risks And Accepted Limits

- Cold plugin startup and Git/worktree creation still delay the real stable
  route. The immediate visual transition addresses perceived opening latency;
  this plan intentionally does not model pending sessions.
- A transport failure can still leave an already-created session. Restored
  composer copy warns about this; manual resubmission can duplicate it. True
  deduplication is deferred.
- Generated title is best-effort and is not persisted as pending work across a
  bridge restart. A session may keep its backend/generic title if shutdown wins.
- The detail snapshot may remain slower than route replacement. It uses the
  same launch view for continuity, but staged transcript rendering and PR-read
  optimization are separate work.
- Color-animal combinations are finite. Bounded distinct-pair retry plus one
  secure-suffix attempt handles collisions without an unbounded hot path; a real
  final Git creation failure still follows the existing project fallback.
- Auth-server branch/worktree generation remains wasted work for new bridges
  until released bridge compatibility allows endpoint narrowing. Bridge-side
  dead fields and coupling are still removed now.

## Expected Result

Pressing Send immediately presents the session experience. Metadata service
latency and backend rename latency no longer delay the durable session response.
Dedicated workspaces receive friendly local names without a network dependency.
Success still means the backend accepted the initial action and the stable
Sesori session is queryable. Failure restores the user's exact submission
without unsafe automatic retry. No database or client-bridge wire migration is
introduced.
