# Fast New Session Launch

## Status

- **Plan slug:** `fast-new-session-launch`
- **Status:** Active - Step 6 release verification in progress
- **Plan date:** 2026-08-13
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `8ee8a47b4` after Step 5 merge and
  subsequent mainline changes
- **Current branch:** `fix/codex-new-session-prompt-history`
- **Delivery:** six numbered PRs, approved standalone follow-up 4A, and two
  approved standalone release prerequisites between Steps 5 and 6

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
- No plugin-name branches or plugin-specific implementation changes in the six
  numbered launch PRs. Release defects discovered by the final matrix remain in
  their owning plugins and ship only through the approved standalone prerequisites.
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
- Metadata never gates dedicated-worktree creation. The branch and worktree
  initially use the same locally generated lowercase ASCII `color-animal` slug,
  for example `blue-otter`.
- After the durable create response, successful metadata may rename only that
  initial branch to the generated `branchName`. The worktree directory remains
  the original `color-animal` path. Skip the rename when the worktree is no
  longer on its initial branch or that branch has an upstream or matching remote ref.
- The vocabulary is a small curated code-owned list. Naming is local,
  dependency-free, backend-neutral, and reusable for future workspace names.
- On collision, sample another pair for a bounded number of attempts. If those
  attempts are exhausted or the final create races, append the existing secure
  short hexadecimal suffix to the last pair rather than losing workspace
  isolation.
- A late generated branch collision likewise uses a bounded secure suffix. An
  invalid generated branch or any Git/persistence failure keeps the initial
  branch and cannot fail the session or generated-title update.
- Creation failures return automatically to the filled composer. Text/voice
  provenance, slash command, and attachments are restored. The user explicitly
  presses Send again.
- Every creation-originated error uses copy that says Sesori could not guarantee
  that no session was created and that it may still appear in the list. Timeout,
  response loss, malformed/empty success, and generic failures are inherently
  uncertain; server rejection is also covered because command rejection can
  occur after durable commit.
- Back continues launch in the background, as today.
- The launch implementation is plugin-agnostic. Automated bridge tests prove the
  normalized contract; release verification enumerates every plugin registered
  in the build under test. A matrix defect is fixed separately inside its owning
  plugin rather than adding backend knowledge to launch code. Unregistered
  packages receive no product claim.
- Generated title and eligible generated-branch rename run fully off the response
  path. A user title must not be overwritten, and a user/agent branch switch or
  published initial branch must not be renamed. These are focused conditional
  mutations, not a new lifecycle state machine.
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
the metadata-oriented preferred-name parameter and its old pre-creation runtime
validator remain deleted. Durable branch/worktree/base facts and the worktree
system prompt initially describe this local identity.

The approved follow-up does not rename or move the worktree directory after a
backend starts in it. It refines only the checked-out branch after metadata, so
the plugin working directory, stored session directory, and system prompt remain
valid. The prompt deliberately calls its value the initial branch.

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
durable commit, and slash-command acceptance. It then tracks late metadata
completion and returns the canonical committed session immediately.

### 5. Managed late generated metadata

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
  typed 401 force-refresh/retry, and the title-plus-branch response DTO;
- Layer 2 `SessionMetadataRepository` under `bridge/app/lib/src/repositories/`
  owns the 500-character payload normalization and maps the typed API result;
- Layer 3 `SessionCreationService` consumes the repository and owns the product
  decision that metadata failure is logged and degraded to no generated title or
  branch refinement.

This follows the bridge architecture's explicit authenticated-provider boundary:
`SesoriServerApi` consumes `TokenRefresher` and owns the complete authenticated
HTTP operation. The repository does not inspect HTTP status or coordinate token
lifecycle.

The DTO consumes the deployed response's `title` and `branchName` and ignores
`worktreeName`. The auth server response remains unchanged for released bridges.
API/repository errors retain status/cause/stack context; only the creation
service converts them into the best-effort result.

Late work is owned by `SessionCreationService`, not by a detached route future.
Immediately after all synchronous acceptance gates pass, the service starts and
registers the complete metadata workflow in the tracked set before it
can return the canonical session:

- one set tracks accepted metadata-completion futures, including title and any
  eligible branch refinement;
- standalone `TokenManager` refresh HTTP gains an injected request deadline, so
  token acquisition always settles; the desktop control-channel implementation
  retains its existing timeout;
- one shutdown signal aborts in-flight metadata HTTP;
- `beginShutdown` stops accepting new late work and triggers that request abort;
- `drain` waits for tracked metadata work before session operations/listeners and
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
   `SessionCreationService.beginShutdown` to stop late-metadata admission and abort
   metadata HTTP. An already accepted create may still finish its request, but
   if it reaches durable commit after this fence it returns without scheduling a
   generated title; title generation is best-effort during shutdown.
3. The normalized event subscription and Orchestrator-owned local-mutation
   subscription move out of the broad `_subscriptions` composite. `_teardown`
   keeps both live while draining routed requests and relay completions, so no
   accepted route can still reach late-metadata registration.
4. `_teardown` awaits `SessionCreationService.drain`, then begins/drains
   `SessionOperationDispatcher` while `OrchestratorSession` still maps typed
   local mutations to `SessionEventDispatcher`.
5. With all mutation producers fenced, `_teardown` disposes
   `SessionMutationDispatcher`, then the listener, and awaits the Orchestrator's
   local-mutation subscription. It disposes `SessionEventDispatcher`, which
   drains per-plugin tails before closing normalized output.
6. `_teardown` then awaits the latest `_pluginEventProcessingTails` and
   `_pendingPartCaptures`, which drains delivery of those final normalized
   outputs, and only then cancels the normalized event subscription.
7. The shutdown coordinator closes the shared HTTP client/database only after
   the whole `OrchestratorSession` drain phase.

This order gives every tracked metadata task live mutation/event dependencies,
admits no task after the drain snapshot, and requires no global job registry.

Generated title applies through `SessionMutationDispatcher` under the existing
session-family lane. Add an atomic repository/DAO operation that writes only
when the bridge-owned title is still null. A zero-row result means a user rename
or deletion won; no plugin propagation follows. This is one focused guard for
an ordinary reachable flow, not a title state machine.

Generalize the dispatcher's existing deletion-only local mutation stream to a
sealed stream with `titleUpdated(Session)` and `deleted(Session)` variants.
Rename `SessionDeletionListener` to `SessionMutationListener`; it exposes typed
local output only. `OrchestratorSession` decides and dispatches the corresponding
backend-neutral event (`session.updated` for title success) before best-effort
plugin propagation. Clients already consume it, so no new wire model is needed.

The follow-up extends the same ownership rather than adding another job or event
pipeline:

1. `SessionCreationService` receives the typed title and generated branch in the
   existing tracked metadata workflow. Title and branch application are
   independent so either may succeed when the other fails.
2. Generated branch application enters `SessionMutationDispatcher` under the
   existing session-family lane. The dispatcher requires a stored root session
   with a dedicated worktree and delegates Git decisions to `WorktreeService`.
3. `WorktreeService` asks `GitCliApi` through `WorktreeRepository` to validate the
   target, confirm the current branch still equals the durable initial branch,
   confirm it has no upstream or matching remote ref, resolve a bounded collision suffix, and rename the
   explicit old ref. It re-reads the current branch after the rename before
   claiming a current-branch projection. No process-global or filesystem lock is
   added for Git actions performed outside the bridge.
4. After Git succeeds, `SessionRepository` conditionally replaces the durable
   `branchName` expected by the operation and updates `currentBranchName` only
   when Git still reports the renamed ref. A persistence failure attempts a
   best-effort explicit Git rollback and logs both failures if rollback also
   fails, preserving diagnostic evidence without failing session creation.
5. A successful persisted rename emits a `branchUpdated(Session)` local mutation.
   `OrchestratorSession` maps it to the existing `session.updated` event with
   `titleChanged: false`; normal PR refresh later reconciles any PR cache. No new
   client wire shape is introduced.

## Failure Semantics

- **Still synchronous:** invalid project, unroutable backend, git/worktree setup
  required to determine the actual working directory, backend session creation,
  initial prompt/attachment rejection, slash-command rejection, and durable
  binding failure.
- **Best-effort after response:** metadata generation, bridge-owned generated
  title application, eligible generated-branch rename, and backend title
  propagation.
- **Client creation failure:** restore the composer with a duplicate-risk
  warning for every creation-originated error; never auto-resend. Timeout,
  response loss, malformed/empty success, generic errors, and even some server
  rejections cannot prove that no durable session was committed.
- **Background leave:** do not cancel bridge work. Existing list SSE/reconnect
  reconciliation remains authoritative once the binding commits.
- **Shutdown:** cancel metadata HTTP, drain tracked metadata completions, then
  close operation/event/mutation infrastructure. Do not persist prompt or
  pending metadata work across process restart; generated title and branch
  refinement are explicitly best-effort.

## Compatibility

- Client and bridge wire contracts are unchanged. A new client still waits for
  a real `Session` response from an older bridge; an older client receives the
  same `Session` shape from the new bridge, only sooner and initially without a
  generated title when metadata is slow.
- Older clients already accept nullable `Session.title` and consume later
  `session.updated` events.
- No database migration is needed.
- The auth server continues returning `title`, `branchName`, and `worktreeName`
  because released bridges require all three fields. The new bridge intentionally
  consumes `branchName` and ignores `worktreeName`; only the latter can be removed
  once released bridges requiring it are outside support.
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
- The old layer-skipping `SessionMetadata` model and its `worktreeName` coupling;
  the typed API response retains only the title and generated branch needed by
  the late workflow.
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
- Generated metadata `branchName`, `GitCliApi` branch validation/rename/upstream
  primitives, and the durable creation/current branch fields.
- Durable `Session` and database title/branch/worktree/base fields.
- Explicit user rename APIs and every plugin's `renameSession` implementation.
- `SessionMutationDispatcher` family serialization.
- `NewSessionSending`, duplicate-submit protection, background-launch snackbar,
  `ModalRoute.isCurrent` navigation guard, and existing detail snapshot loading.
- Existing worktree fallback for non-git, commitless, unresolved-base, and real
  Git command failure.
- Existing session-created/binding buffering and SSE replay machinery.

### Deferred cleanup

- Auth-server response narrowing/removal of generated `worktreeName`, solely
  because released bridges deserialize it as required. Generated `branchName`
  remains a live field for current bridges.
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
- Renaming a worktree directory after plugin creation, renaming an initial branch
  with an upstream or matching remote ref, or following a user/agent branch switch.
- Changing plugin prompt semantics, session options discovery, relay timeout,
  or session-detail refresh reconciliation.

## Complexity Budget

### New mutable parts

1. **Client submission snapshot:** one immutable state-owned object while a
   launch is sending or being restored. It is required to preserve memory-only
   attachments and voice/command intent across the immediate visual transition;
   the still-mounted screen State retains the independent workspace toggle.
2. **Late-metadata future set:** the existing `Set<Future<void>>` owned by
   `SessionCreationService`, renamed to describe that title and branch work cannot
   outlive bridge dependencies; no second set is added.
3. **Late-metadata abort controller/signal:** one shutdown signal shared by
   metadata requests, required to keep graceful shutdown from waiting for the
   45-second metadata deadline.
4. **Memoized drain future/accepting flag:** lifecycle state local to the same
   service, required for idempotent shutdown and no post-drain admission.

### Net coordination

- Zero new database columns or persisted states.
- Zero pending-session maps, queues, timers, retry registries, correlation IDs,
  or long-lived dedupe sets. The six numbered launch PRs add no plugin-specific
  branches; approved release prerequisites normalize only evidence-backed
  backend transcript behavior in the owning plugins. Worktree naming may hold at
  most the three sampled slugs in one call so retries are actually distinct;
  that ephemeral local set is bounded by the existing attempt count.
- Zero net long-lived stream controllers/subscriptions: the deletion-only
  mutation stream/listener is generalized in place.
- Zero new branch registries, watchers, locks, or reconciliation jobs. Each late
  rename carries only its expected/desired names through the existing tracked
  workflow and family lane.
- One UI timer, replacing rather than adding to the current rotating-copy timer.
- No prompt/transcript persistence and no attachment persistence.
- One transient sealed restore state and one post-frame consumption callback;
  neither retains state after the composer copies the snapshot.

If implementation needs a pending-attempt registry, per-session metadata map,
second mutation stream/listener, Git watcher/lock, or partial-detail
reconciliation machinery, stop and ask before expanding scope.

## Delivery Plan

| Step | Exact PR title | Target | Scope |
|---|---|---:|---|
| 1/6 | `🌱 [fast-new-session-launch] docs: plan faster new-session launch [step 1/6]` | 750-900 lines | Add this reviewed plan and tracker only. |
| 2/6 | `🌿 [fast-new-session-launch] feat(bridge): use local workspace names [step 2/6]` | 200-500 lines | Generate color-animal worktree/branch slugs and remove obsolete preferred-name code/tests. The old metadata model is replaced once in Step 3. |
| 3/6 | `🚧 [fast-new-session-launch] feat(bridge): return sessions before generated titles [step 3/6]` | 950-1,450 lines | Add shared typed metadata request plus bridge API/repository layering, return canonical committed sessions, run title generation off the response path with exact shutdown ownership, conditional local title update, local `session.updated`, generated output, and obsolete-path deletion. |
| 4/6 | `⚙️ [fast-new-session-launch] feat(client): open launching sessions immediately [step 4/6]` | 800-1,400 lines | Add sealed submission restoration, reusable Prego launch status, detail-shaped launch/loading, honest error warning, delete overlay/dependency/tests, regenerate state/localization. |
| 4A | `⚙️ Rename generated session branches after launch` | 350-700 lines | Standalone approved follow-up: consume generated branch metadata, conditionally rename only the unpublished initial dedicated branch off the response path, persist both branch facts, and publish the existing session update. |
| 5/6 | `🌱 [fast-new-session-launch] docs: define launch regression coverage [step 5/6]` | 80-180 lines | Reconcile affected regression docs and complete cleanup audit against actual implementation. |
| Codex prerequisite | `⚙️ Preserve Codex prompt content in transcripts` | 250-450 lines | Standalone approved release blocker: hide the bridge worktree envelope and preserve bounded user images in live and replayed Codex messages. |
| ACP prerequisite | `⚙️ Preserve ACP user attachments in transcripts` | 180-400 lines | Standalone approved release blocker: preserve text-plus-image and attachment-only user input after delivery and cold replay across ACP plugins. |
| 6/6 | `🌿 [fast-new-session-launch] test: verify faster new-session launch [step 6/6]` | 80-250 lines | Run the recorded level/matrix, record automated/manual results and timings, then move this plan from `active` to `completed` only on full required coverage. |

Each implementation PR must stay below the 1,500 changed-line soft cap. If a
step exceeds its target, prefer removing unnecessary machinery or splitting
tests by owner. The approved standalone follow-ups do not renumber the six-step
titles. Do not combine bridge and client production work.

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

### Follow-up 4A

- `bridge/app`: metadata API/repository, creation service, mutation dispatcher,
  worktree service/repository, Git API, DAO/repository persistence, local event
  mapping, and shutdown tests plus `dart analyze --fatal-infos`.
- Prove the canonical create response settles before metadata and branch rename,
  and metadata/title failure remains independent from branch failure.
- Prove only a stored root dedicated session on its original local branch is
  eligible; in-place/fallback sessions, switched or detached worktrees, and an
  initial branch with an upstream or matching fetched remote ref retain their
  current branch.
- Prove valid metadata renames only the branch, leaves the worktree/directory
  unchanged, uses bounded secure collision fallback, updates durable/current
  branch facts, and emits the existing `session.updated` with
  `titleChanged: false`.
- Prove generated-title behavior is unchanged, persistence failure attempts Git
  rollback, deletion/family serialization wins predictably, and shutdown drains
  the complete metadata workflow.

### Release prerequisites

- `bridge/sesori_plugin_codex`: prove live app-server and rollout replay hide
  only the bridge-owned worktree envelope while preserving authored text and
  bounded images, including an attachment-only initial prompt; run the complete
  package tests and strict analysis.
- `bridge/sesori_plugin_acp`: prove initial, queued follow-up, and replayed user
  messages preserve bounded images and attachment-only input without exposing
  host paths; run the complete package tests and strict analysis.
- Keep both changes within the existing plugin interface and transport shape.
  Do not change Cursor `session/load` fallback without a current protocol capture
  proving that a request-shape defect remains.

## Regression Documentation And Final Matrix

Affected feature documents:

- `docs/regression/session-creation-and-options.md` - authoritative capability;
- `docs/regression/projects-and-sessions.md` - dedicated workspace naming and
  durable list/title update;
- `docs/regression/attachments-and-images.md` - memory-only attachment
  restoration after failed creation.
- `docs/regression/diffs-and-source-control.md` - late refinement of the durable
  initial branch without moving the worktree;
- `docs/regression/pull-request-monitoring.md` - generated branch update through
  the existing current-branch/session update contract.
- `docs/regression/session-turns.md` - plugin user-message normalization defects
  found during the final live matrix.

`session-turns.md` changes only for the evidence-backed Codex and ACP transcript
normalization behavior delivered by the standalone release prerequisites.

The durable-plan lifecycle intentionally reconciles these documents in the
penultimate Step 5. Steps 2-4 and follow-up 4A record doc deltas in `TRACKER.md`
as they merge, and the series is not release-complete until Step 5 updates the
active contracts; this follows `docs/regression/README.md` rather than
scattering partial feature wording across production steps.

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
  initial name, collision retry, and suffix fallback through automated tests.
  A representative dedicated session additionally proves metadata arrives after
  response, renames only the unpublished initial branch, leaves the worktree path
  stable, updates the client branch, and skips after branch switch/upstream,
  matching remote ref, or metadata/Git failure.
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
- metadata/title/branch completion cannot extend create response time;
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
- Generated branch refinement is likewise best-effort. Metadata failure, an
  agent branch switch, an upstream or matching fetched remote ref, invalid output,
  collision/create races, or a Git failure leaves the safe initial
  `color-animal` branch in place.
- The detail snapshot may remain slower than route replacement. It uses the
  same launch view for continuity, but staged transcript rendering and PR-read
  optimization are separate work.
- Color-animal combinations are finite. Bounded distinct-pair retry plus one
  secure-suffix attempt handles collisions without an unbounded hot path; a real
  final Git creation failure still follows the existing project fallback.
- Auth-server branch generation is intentionally live again for current bridges.
  Worktree-name generation remains wasted until released bridge compatibility
  allows that field to be removed.

## Expected Result

Pressing Send immediately presents the session experience. Metadata service
latency and backend rename latency no longer delay the durable session response.
Dedicated workspaces receive friendly initial local names without a network
dependency, then eligible unpublished branches refine to the generated task name
after launch without moving the worktree.
Success still means the backend accepted the initial action and the stable
Sesori session is queryable. Failure restores the user's exact submission
without unsafe automatic retry. No database or client-bridge wire migration is
introduced.
