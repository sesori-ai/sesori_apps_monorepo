# Concurrent Relay Request Routing

## Status

- **Plan slug:** `relay-request-concurrency`
- **Status:** Active — Step 1 PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) and
  post-merge correction PR
  [#688](https://github.com/sesori-ai/sesori_apps_monorepo/pull/688) and Step 2 PR
  [#690](https://github.com/sesori-ai/sesori_apps_monorepo/pull/690) merged;
  Step 3 PR [#696](https://github.com/sesori-ai/sesori_apps_monorepo/pull/696) open
- **Plan date:** 2026-08-02
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Current implementation base:** `main` at
  `fdc8ad67eafe18edb774249329f707bc6394c187`
- **Delivery:** one plan PR, eight sequential implementation PRs, and one
  plan-retirement PR
- **Plan PR:** [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687)

This document and `TRACKER.md` are the implementation authority for this
series.

## Goal

Keep the bridge transport and independent plugins usable while any individual
client request or backend plugin operation is slow or unresponsive.

The relay read loop will continue decoding frames, completing client key
exchange, observing disconnects, and accepting additional requests without
awaiting routed business work. Each request will execute independently and
return through its existing request ID. Ordering will exist only at the domain
resource whose invariant requires it, never as an accidental bridge-wide
transport policy.

## Incident Evidence

On 2026-08-02, a standalone bridge remained alive for more than four hours, its
debug health route remained responsive, and its relay TCP socket remained
established, but mobile clients appeared offline. The bridge later logged:

```text
slow route POST /session/create for connId 1 took 305654ms
```

Immediately after that route completed, queued client key exchanges completed
and the devices came back online. The causal path on `main` is:

1. `OrchestratorSession._runRelayLoop` awaits
   `_handleDecryptedMessage` for each decrypted frame.
2. A `RelayRequest` makes `_handleDecryptedMessage` await
   `RequestRouter.route` through response encryption and send.
3. No later relay frame is read while that route is unresolved, including
   another client's key exchange, disconnect notification, health request, or
   force-restart command.

This is head-of-line blocking in the bridge transport. The stalled request was
not introduced by PR #686; that PR exposed the pre-existing behavior during
long-running testing.

## Success Criteria

1. A routed request never blocks the relay read loop from processing a later
   frame.
2. Requests from different clients, from one client, and for different plugins
   can execute concurrently and may respond out of order through their existing
   request IDs, except operations sharing an explicit session-family, pending
   interaction, or project-path causal lane.
3. A stalled plugin-A request does not delay key exchange, global health,
   database-only reads, plugin-B requests, or a force-restart command for
   plugin A.
4. A response is sent only to the exact client-connection incarnation that
   originated its request. Disconnect, rekey, relay reconnect, or `connId`
   reassignment makes the old response ineligible for delivery without
   cancelling a mutation that may already have been accepted.
5. An accepted bridge restart dispatches exactly once even if its originating
   client disconnects, rekeys, or suffers a send failure. When the origin remains
   current, its response is synchronously enqueued (or debug HTTP is closed)
   before handoff; stale delivery is skipped without cancelling the accepted
   action. Relay enqueue is not represented as remote delivery acknowledgement.
6. Initial SSE summary construction does not block relay ingestion after the
   subscription itself is registered.
7. Shutdown stops accepting new routed work from both relay and debug consumers,
   prevents late sends, and drains every accepted shared route plus each
   transport's surrounding work before disposing dependencies under the
   existing process backstop.
8. Prompt/command/defaults, abort, and conflicting pending permission/question
   responses preserve arrival order for one session family. Auto approval uses
   the same owner; another family/plugin and force restart remain independent.
9. Rename, archive/unarchive, and complete delete workflows preserve arrival
   order across a root and all descendants. Root deletion cannot race a child
   mutation or restore a worktree after cleanup.
10. A new stable session is hidden by the authoritative repository from catalog
    reads and events until its initial command and metadata rename settle, so
    another surface cannot mutate a partially initialized binding.
11. Create/open/hide and Git initialization for one canonical project path
    preserve arrival order, while unrelated paths remain independent.
12. Slow work is observable while it is still running through stable route
    templates, while local diagnostics retain useful errors, stack traces,
    paths, connection/session identifiers, and relay-control context. Known
    prompt/transcript content and other user data with no debugging value stays
    selectively omitted.
13. There is no wire-contract, database-schema, persisted-data, client API, or
     analytics change.

## Locked Decisions

### Transport versus business ordering

- Relay frame decoding remains sequential. Local decrypt/unframe and key
  exchange may be awaited because they are bounded local cryptographic work
  required to interpret the frame safely.
- `RelayRequest` execution is not serialized globally, per connection, or per
  plugin at the transport layer.
- The client already correlates responses through
  `Map<String, Completer<RelayResponse>>`; response ordering on the WebSocket is
  not part of the protocol contract.
- `DebugServer` already routes independent HTTP requests concurrently. Relay
  routing will use the same concurrency assumption rather than maintaining a
  stricter hidden API contract.
- A plugin adapter that cannot safely accept concurrent calls owns that backend
  restriction locally. `PluginRuntime` continues to own per-plugin generations,
  leases, durable-commit fences, and force-stop/restart behavior.
- Domain serialization remains only where an explicit invariant requires it.
  Session-targeting mutations use one ordered admission owner that resolves the
  stable root family before long work and preserves pending-interaction choices;
  project create/open/hide uses a separate canonical-path owner. The bounded
  local scope-resolution phase is ordered, but unrelated resolved families and
  paths execute concurrently. Force restart stays outside all domain lanes.

### No generic timeout or global worker pool

- Do not add a generic route timeout. Timing out a non-idempotent write cannot
  cancel its underlying operation and could report failure while the backend
  later commits it.
- Existing endpoint-specific deadlines and acceptance contracts remain. The
  OpenCode plugin, for example, continues to detach synchronous command runs
  after its fast-fail acceptance window.
- Do not add a global semaphore or fixed worker pool. Enough stalled requests
  could consume every slot and recreate the same inability to reach health or
  force restart.
- If production evidence later requires overload admission, design per-plugin
  bulkheads with an independent control lane as separate work. It is not needed
  to solve this demonstrated failure.

### Connection and response semantics

- Relay `connId` is a temporary routing address, not a durable device identity.
- Each successful key exchange or resume creates a private local connection
  incarnation. Each relay WebSocket connection also has a local epoch.
- A routed request captures both values. Its response is eligible only while
  both still match the active connection.
- If the origin disconnects, rekeys, or reconnects, the operation is allowed to
  finish because it may be non-idempotent, but its obsolete response is dropped.
  The disconnected client already reports a timeout or typed uncertain response
  loss and refreshes authoritative state after reconnect.
- A send failure for the current relay epoch drives the existing relay close and
  reconnect path. A completion from an obsolete epoch cannot affect the current
  socket.

### Restart sequencing

- The current `BridgeRestartService._restartRequested` boolean is an accidental
  serialization dependency. A restart handler sets it, and whichever route
  next calls `consumeRestartRequest` owns the handoff.
- Before concurrent relay routing lands, replace that global flag with a typed
  request-local sealed route outcome: ordinary `ResponseOnly` or
  `RestartAccepted`. `RestartAccepted` carries only the request ID and constructs
  the fixed successful `{restarting:true}` response, so an error response plus
  restart action is unrepresentable. Route selection separately exposes a typed
  privacy-safe identity synchronously, before route completion.
- An unsuccessful restart preflight returns an ordinary `ResponseOnly` error.
- The debug transport closes its HTTP response before dispatching an accepted
  handoff. The relay transport first reaches a terminal delivery disposition:
  current origins synchronously enqueue on their exact connection; stale origins
  skip delivery; current send failure synchronously claims that handle through
  `closeIfCurrent` and starts its asynchronous close. It then dispatches
  `RestartAccepted` exactly once without awaiting the close handshake. The WebSocket
  API has no per-frame remote-delivery acknowledgement, so this plan does not
  claim one. Graceful close retains the existing delivery opportunity. No new
  wire field is added.
- Replace the `BridgeRuntime`-forwarded `restartHandoff` callback with one
  concrete `BridgeRestartDispatcher` composition peer. It owns duplicate
  handoff suppression, calls `BridgeRestartService.performRestartHandoff`, and
  emits a synchronous typed shutdown-request stream only after a successful
  handoff. Relay and debug consumers receive the dispatcher directly;
  `OrchestratorSession` subscribes to the stream and drives normal cancellation.
  The runtime composition owns and disposes the dispatcher after debug and
  session request work drains.

### Plugin restart behavior

- Concurrent transport dispatch makes plugin lifecycle routes reachable while
  a plugin-backed route holds a stalled lease.
- Existing safe restart may continue returning an in-flight conflict. Existing
  force restart remains the explicit override: it uses a bounded barrier,
  retires the old generation, shuts it down, and starts a successor.
- Existing `PluginRuntime.use` and `useAndCommit` generation checks continue to
  reject results that return after replacement; `useAndCommit` cannot enter its
  durable commit under a retired generation.
- This plan does not add cancellable Dart futures or reinterpret an accepted
  backend mutation. An old operation that never settles can retain one tracked
  future, but it cannot block relay ingestion or a successor plugin generation;
  the existing process shutdown backstop remains the final bound.
- Concurrent async dispatch cannot recover from a plugin implementation that
  synchronously blocks the Dart isolate. Current plugins communicate with
  out-of-process backends through asynchronous APIs. Moving plugins to separate
  Dart isolates/processes is a non-goal unless a concrete synchronous stall is
  demonstrated.

## Non-Goals

- Plugin process/isolate sandboxing.
- A new relay role, control frame, request ID, response replay protocol, or
  client reconnect contract.
- Cancelling or rolling back a write merely because its client disconnected or
  timed out.
- Generic request deadlines, retries, deduplication, or idempotency keys.
- Global or per-plugin concurrency limits without overload evidence.
- Reworking plugin runtime generation, force-stop, or durable-commit semantics.
- Broad repository/DAO locking or serialization changes.
- Client UI, copy, push notification, unseen-state, or analytics changes.

## Current Repository Baseline

At the audited `main` tip:

- `OrchestratorSession._runRelayLoop` processes one frame at a time and awaits
  all work in `_handleDecryptedMessage`.
- A `RelayRequest` sets one `_inFlightRequestLabel`, routes synchronously from the
  loop's perspective, waits for shutdown or the response, encrypts it, and sends
  it before the next `StreamIterator.moveNext`.
- The slow-route diagnostic appears only after completion and is incorrectly
  prefixed `[shutdown]`, even when no shutdown is active.
- `RelaySseSubscribe` also awaits `_buildProjectsSummary` before the next frame.
- `RelayClient.send` routes solely by numeric `connId`.
- Client `RelayClient.sendRequest` stores independent request-ID completers and
  therefore already accepts out-of-order responses.
- `RequestRouter.route` returns only `RelayResponse`; restart attribution is a
  shared mutable boolean in `BridgeRestartService` consumed by both
  `OrchestratorSession` and `DebugServer`.
- `DebugServer` already tracks and routes multiple in-flight HTTP requests.
- `OrchestratorSession._teardown` disposes collaborators used by that shared
  router, while the shutdown coordinator starts session and debug drain futures
  concurrently; there is no current cross-consumer route barrier.
- `PluginRuntime` has independent slots per plugin, allows concurrent leases,
  and fences operation results by generation. Force restart waits for its
  bounded stop barrier and can replace a generation with outstanding work.
- `PluginLifecycleService` coordinates active lifecycle commands per plugin.
- `SessionPromptService.sendPrompt` awaits backend prompt/command acceptance and
  local defaults publication, while `SessionAbortService.abortSession` calls the
  backend independently. The serial relay loop currently prevents a later abort
  from overtaking acceptance; no domain owner preserves that order once routes
  are detached.
- Permission/question repositories perform binding, tombstone, or pending-item
  reads before invoking the plugin. Conflicting replies from multiple surfaces
  can therefore reach the backend out of arrival order after detachment;
  `PermissionAutoApprovalService` is another production writer.
- `SessionMutationDispatcher` has one `_tail` and one `_backendTail` for every
  session. It uses them to make persisted rename, backend rename propagation,
  and delete order correctly, but an unrelated plugin/session can wait behind a
  slow backend mutation.
- Session deletion tombstones the complete root/descendant subtree, while
  archive/unarchive and child mutations currently bypass the mutation
  dispatcher. Unarchive can restore a dedicated worktree during root cleanup.
- Session creation publishes its stable binding before optional first-command
  acceptance and metadata rename finish, allowing another surface to observe
  and mutate a partially initialized session.
- Project open/create performs filesystem and optional Git work before the
  existing activity write tail; hide bypasses that service. Same-path operations
  can therefore invert or overlap, while different projects need no ordering.
- Open PR #686 changes adjacent `OrchestratorSession` PR-update subscription and
  session-route behavior. This series does not fold into that feature branch;
  every implementation step rebases on current `main` and resolves any merged
  drift explicitly.

## Proposed Architecture

### 1. Two-phase routing and typed completion

`RequestRouter` remains the sole route matcher, but its entry point becomes
synchronous and two-phase:

```text
PendingRoutedRequest
  routeIdentity: Matched(HttpMethod, declaredPathTemplate)
               | Unmatched(HttpMethod)
               | InvalidMethod
               | InvalidTarget(HttpMethod)
  completion: Future<RoutedRequestOutcome>

RoutedRequestOutcome
  ResponseOnly(RelayResponse)
  RestartAccepted(requestId) -> fixed successful RelayResponse
```

The synchronous phase first parses the raw external method into the existing
closed `HttpMethod` enum, excluding handler-only `any`. Unsupported or malformed
method text becomes fixed `InvalidMethod` identity for routing decisions. A
known method with an invalid URI uses `InvalidTarget(HttpMethod)`;
a valid request with no handler uses `Unmatched(HttpMethod)`. A match exposes
only the handler's declared template for bounded route categorization. Transport
consumers may still log the concrete request/control context when diagnostically
useful; they never log request bodies, headers, prompts, or transcripts.

Step 2 audits every existing route log, not only the new slow timer. Receipt,
ordinary handler failures and shutdown completion/drain use the selected identity
for stable categorization while preserving caught errors and stack traces.

The asynchronous completion preserves current handler/error mapping. Ordinary
successes, router errors, handler errors, restart preflight failures, unmatched
requests, and invalid requests are `ResponseOnly`. Only a successful restart
preflight returns `RestartAccepted`; that variant creates the fixed successful
response from its request ID and cannot carry an arbitrary/error response.

Relay and debug consumers switch exhaustively over the exact outcome. For
`RestartAccepted`, the debug transport closes its HTTP response before asking a
directly injected `BridgeRestartDispatcher` to hand off. The serial relay
transport encrypts and synchronously enqueues the response first. The dispatcher
owns single-flight handoff, invokes `BridgeRestartService`, and emits a typed
shutdown request that `OrchestratorSession` observes through a stream rather
than a callback passed through `BridgeRuntime`. This change ships before request
concurrency, removes the shared restart flag/callback, and gives later slow-route
timers a privacy-safe identity at dispatch time.

### 2. One lifecycle barrier for both route consumers

The relay session and `DebugServer` share one `RequestRouter` and the same
repository/service graph, but currently maintain independent in-flight state.
`OrchestratorSession` can dispose those collaborators while a debug request is
still routing because both drain actions start concurrently.

Add one concrete `RoutedRequestDispatcher` at the routing boundary. It owns:

- the `RequestRouter`;
- synchronous acceptance of a `PendingRoutedRequest` from relay or debug;
- one registry of every accepted route-completion future;
- an idempotent `beginShutdown` that rejects later dispatch with a typed 503;
  and
- an idempotent `drain` future that settles only after every accepted route
  completion has settled.

The same instance is injected into `OrchestratorSession` and `DebugServer` from
the composition root. Each transport still owns its surrounding work: relay
encryption/send and HTTP body/response lifecycle remain with their transport.
`DebugServer` retains its full-request registry, and `OrchestratorSession` later
adds a registry for detached relay completion work.

`OrchestratorSession.beginShutdown`/teardown and `DebugServer.beginShutdown`
close dispatcher acceptance idempotently. Session teardown does so before its
first dependency disposal even when it starts because the session failed before
the outer shutdown coordinator can close the debug listener; any HTTP request
racing afterward receives the typed shutdown rejection. Both the session
teardown and debug drain await the same dispatcher barrier. Only after it settles
may `OrchestratorSession` dispose the shared route-owned services/repositories.
This ordering remains safe even though the shutdown coordinator starts session
and debug drain futures in the same phase.

### 3. Epoch-bound relay transport operations

Before detaching request completion, make the relay connection itself an
explicit internal value. A successful `RelayClient.connect`/`reconnect` returns
an opaque `RelayConnection` handle owning that exact WebSocket generation.

`RelayClient.read`, close-code inspection, synchronous `sendIfCurrent`, and
`closeIfCurrent` accept the captured handle rather than implicitly operating on
whichever mutable channel happens to be current. `sendIfCurrent` rechecks handle
identity inside `RelayClient` and returns a closed sent/stale result; an obsolete
handle can neither send through nor close its successor.

For response delivery, asynchronous JSON encryption/frame creation completes
first. The orchestrator then validates the client incarnation and calls
`sendIfCurrent` with the captured relay handle with no `await` between those
operations. Dart's single event loop plus the transport's own identity check
makes validation and `sink.add` one non-interleavable final-send gate.

If `sink.add` fails, `closeIfCurrent` synchronously claims only that handle
before any asynchronous close handshake. The normal read-loop loss/reconnect
path then recovers. Failure from an obsolete handle only settles/logs that old
operation and cannot close the successor connection.

This transport refactor lands while relay request routing is still serial, so
its current behavior and reconnect tests can be reviewed independently.

### 4. Ordered session-family and pending-interaction admission

Before detaching routes, add one concrete `SessionOperationDispatcher`. Every
accepted operation receives a monotonic ticket synchronously before its first
await. A short admission tail resolves the target's stable root session through
`SessionRepository`, in ticket order, then appends the operation to that root
family's FIFO lane without waiting for earlier long work to complete. Therefore
only bounded local catalog lookup is globally ordered; unrelated resolved root
families execute concurrently.

Family resolution returns both stable root ID and plugin ID. An operation may
also carry a sealed pending-interaction request that becomes a plugin-scoped key:

```text
PendingInteractionRequest
  Permission(requestId)
  Question(questionId)

ResolvedPendingInteractionKey
  (pluginId, stableOwnerSessionId, permission, requestId)
  (pluginId, stableOwnerSessionId, question, questionId)
```

The dispatcher appends one completion token atomically to both the resolved
family lane and optional resolved interaction lane, then awaits all predecessors.
This preserves first-response order for approve/reject and answer/reject without
nested lock acquisition or cross-plugin/session ID assumptions. Modern requests
key by their resolved stable owner session as well as plugin and request ID, so
reused IDs in unrelated families remain independent.

Legacy question rejection without `sessionId` maps to the fixed OpenCode plugin
and synchronously registers a plugin-scoped unresolved-family barrier before its
first await. `PendingInteractionService` resolves the question against pending
OpenCode questions: exactly one stable owner claims that family and interaction
lane before releasing the barrier; zero matches returns not-found; multiple
matches returns an explicit compatibility conflict because the old payload is
ambiguous. Later OpenCode session operations await the earlier barrier before
family admission, preserving delete/reject arrival order; other plugins and
modern questions remain independent. Failures release every claimed lane, and
settled idle lanes are removed.

`SessionPromptService`, `SessionAbortService`, and a new
`PendingInteractionService` use this owner. The latter depends on
`PermissionRepository` and `QuestionRepository`; all three response handlers and
`PermissionAutoApprovalService` call it, so no production writer bypasses the
interaction lane. Prompt/command operations retain the family lane through
backend acceptance and local defaults persistence/publication, preserving
defaults FIFO as well as prompt-before-abort behavior. Force restart remains
outside the dispatcher.

The composition root constructs one peer and stores sole lifecycle ownership on
`OrchestratorSession`. Teardown first closes shared route acceptance and cancels
every non-route plugin-event producer that can invoke auto approval. It then
awaits both the shared route barrier and all accepted
`_pluginEventProcessingTails`, closes session-operation acceptance, drains and
disposes it exactly once, and only afterward disposes auto approval,
prompt/abort/pending-interaction services and repositories. Step 5 lands that
full producer-quiescence lifecycle while relay routing remains serial.

### 5. Session-family lifecycle and creation publication

Step 6 enrolls rename, archive/unarchive, and complete deletion in the same
root-family dispatcher. `SessionMutationDispatcher` retains sole repository
deletion, tombstone, backend-title propagation, and `deletedSessions` event
ownership; its global tails become family-scoped operations:

- a child mutation and root deletion resolve to the same root lane;
- a delete ticket reserves the complete cleanup, backend/database deletion,
  subtree tombstone, and event workflow before any await;
- archive/unarchive reserves the family lane before stored-session lookup,
  cleanup, archive persistence, or worktree restoration;
- cleanup rejection preserves its typed response and releases the lane without
  deletion;
- another root family, including one owned by another plugin, remains
  independent; and
- failures release lanes and do not poison later work.

A focused `SessionDeletionService` depends on `SessionLifecycleService` and
`SessionMutationDispatcher`; `DeleteSessionHandler` depends only on that service.
`SessionMutationDispatcher.deleteSession` invokes callback-scoped cleanup after
the family lane is reserved, then retains repository deletion/tombstone/event
ownership. `SessionLifecycleService.cleanup` itself does not reacquire the lane;
its public archive/unarchive workflow does. Ordered scope resolution means an
earlier child operation queues before root delete, while a child lookup racing
after completed deletion fails rather than succeeding on an independent key.

### 6. Atomic session-creation visibility

Session creation has no stable family before backend creation. Change its
internal repository result to a typed `UnpublishedSessionBinding` owned by
`SessionRepository`. The repository marks the committed stable ID hidden before
its transaction becomes observable and every repository read that can return a
session identity—including project-scoped session lists—and every event
projection filters that repository-owned set.

The opaque token is also the only privileged initialization capability. It
carries repository-verified binding/root/plugin scope and is accepted by
dedicated initial-command and initial-rename methods on the existing repository,
mutation dispatcher, and session-operation dispatcher. Those methods do not use
ordinary filtered lookup; no boolean/nullable bypass or raw-ID privileged API is
added. `SessionCreationService` carries the token through both post-create steps,
then asks the repository to atomically reveal and publish it.

Reveal runs exactly once in `finally` after post-create work settles, including
when command/rename failure will be rethrown. A process restart clears the
in-memory gate so a committed session is recoverably visible rather than hidden
forever; ordinary concurrent consumers cannot discover or operate on it midway
through the same run. No callback, schema, persisted field, or wire field is
added.

### 7. Canonical project-path mutation lanes

Add a separate `ProjectMutationDispatcher` and `ProjectMutationService` for
create, open, hide, and optional Git initialization. Each request receives a
synchronous ticket. A bounded admission tail maps create/open's normalized
absolute path or hide's stable project ID to the authoritative canonical stored
path, in arrival order, then appends the complete operation to a per-path lane.
It never waits for filesystem, Git, or persistence work before resolving the
next ticket.

Create/open keeps validation, directory creation, Git preparation, and activity
persistence in one path operation. Hide uses the same service instead of calling
`ProjectRepository` directly. Thus a later hide cannot be undone by an earlier
slow open, and duplicate create/open Git initialization cannot overlap. Unrelated
canonical paths execute concurrently. Syntactic path aliases are normalized;
resolving arbitrary symlink aliases is not added because no demonstrated flow
requires filesystem-wide canonicalization.

`OrchestratorSession` solely owns project-dispatcher acceptance/drain/disposal
after the shared route barrier and before project services/repositories. No
database, wire, or project-ID change is introduced.

### 8. Concurrent relay request completion

`OrchestratorSession` owns relay connection lifecycle and the detached work that
surrounds shared routed completions; the shared dispatcher owns only router work
and its cross-transport disposal barrier.

For each active client request the session will:

1. capture the pending routed request, client incarnation, and opaque relay
   connection handle;
2. synchronously register one relay completion operation before returning to
   the read loop;
3. start a one-shot slow timer using `PendingRoutedRequest.routeIdentity` and
   cancel it on settlement;
4. await the shared routed completion independently;
5. encrypt/frame the correlated response;
6. immediately before the synchronous write, verify the same client incarnation
   and call `sendIfCurrent` with the captured relay handle with no intervening
   await;
7. establish a terminal delivery disposition: sent, stale, or current-send
   failure with `closeIfCurrent` synchronously claiming that exact handle;
8. ask the shared restart dispatcher to handle `RestartAccepted` exactly once
   after that disposition, even when no response could be delivered; and
9. remove itself from the relay completion registry in `finally`.

Every successful key exchange or resume replaces the local client incarnation.
`phone_disconnected` removes it. Each relay reconnect supplies a new opaque
connection handle and clears all client incarnations. Therefore disconnect,
rekey, reconnect, and numeric `connId` reuse all invalidate old delivery.

The read loop schedules the operation without awaiting it. It continues to
process disconnect/reconnect controls, key exchange/resume, later requests, SSE
subscription controls, and session-view controls.

SSE subscription registration remains synchronous, while initial project
summary construction becomes separately tracked session work on the existing
`_projectsSummaryTail`. Builds and broadcasts therefore retain monotonic order
with every other summary refresh even when subscriptions overlap, while a slow
summary source cannot hold relay ingestion.

On shutdown, the existing shutdown signal makes relay completion operations
abandon response delivery and accepted-restart dispatch. `OrchestratorSession`
awaits both its session-owned completion work and the shared route-dispatcher
barrier before disposing repositories, services, controllers, and relay state.
`DebugServer` awaits its HTTP work plus the same route barrier. The process-level
coordinator retains its bounded backstop for an upstream future that never
settles.

## User-Visible Behavior

### Before

- One five-minute create request makes every device appear offline even though
  the bridge process and relay socket remain alive.
- New key exchanges, health checks, plugin-B work, and plugin force restart wait
  behind that request.
- The slow diagnostic appears only once the outage ends.

### After

- Only the client request depending on the unresponsive operation remains
  pending or times out.
- Existing and newly connecting clients continue key exchange and can use
  healthy bridge/plugin functionality.
- A user can issue a force restart for the affected plugin while its old request
  remains unresolved.
- After reconnect, clients refresh authoritative state; they do not receive an
  obsolete response from a prior connection.
- Unrelated session families and project paths no longer wait on each other's
  mutations, while operations on one family/path retain arrival order.

## Compatibility, Data, And Privacy

- No `sesori_shared` transport type changes. `RelayRequest.id` and
  `RelayResponse.id` remain the correlation contract for old and new clients.
- No database migration, persisted settings change, cache change, or backfill.
- No backend plugin interface change is planned. Internal routing return types
  update all bridge consumers in lockstep.
- Old clients and new clients observe the same API responses and timeout/error
  semantics, except healthy requests are no longer delayed by unrelated work.
- A disconnected write can still complete. The client retains its existing
  typed response-loss/uncertain-outcome behavior rather than receiving a false
  cancellation claim.
- Local bridge diagnostics preserve useful caught errors, stack traces, concrete
  request/control paths, connection/session identifiers, and operation context;
  users decide whether to inspect, anonymize, and share those logs. Audits remove
  only known user data with no debugging value, such as prompt/transcript content,
  and do so selectively rather than suppressing whole errors or categories.
- This is internal reliability work, not a new user action or product-adoption
  question, so no analytics event is added.

## Cleanup Assessment

- Step 2 removes the obsolete global `_restartRequested` flag,
  `requestRestart`/`consumeRestartRequest`, the forwarded `restartHandoff`
  callback, their tests, comments relying on serial routing, and direct
  debug-server restart-service dependency if it has no remaining use.
- Step 3 replaces separate route-completion ownership with one shared dispatcher
  barrier; transport-specific HTTP/relay completion state remains with each
  transport.
- Step 4 removes mutable-current-channel `read`/`send` assumptions in favor of
  explicit opaque relay connection handles. Internal callers update in lockstep.
- Step 5 replaces accidental relay-loop ordering for prompt/command/defaults,
  abort, and pending choices with one explicit family/interaction owner. Direct
  permission auto-approval repository writes move through the same service.
- Step 6 removes the global session mutation/backend tails and tests that encode
  cross-family serialization, replacing them with root-family ordering and lane
  cleanup coverage.
- Step 7 replaces eager binding publication with a typed repository-owned
  unpublished creation token and atomic reveal.
- Step 8 replaces handler-level project mutation coordination and direct hide
  repository access with one canonical-path service/dispatcher; existing lower
  repository/activity primitives remain.
- Step 9 replaces the single `_inFlightRequestLabel` with honest tracked
  operations and removes/mends the completion-only `[shutdown] slow route`
  diagnostic. It does not preserve the serial route path for compatibility.
- Keep request IDs, client pending-request maps, plugin runtime leases,
  generation fences, endpoint-specific deadlines, and the shutdown backstop;
  each remains required under concurrent routing.
- No data field, database column, wire field, cache, job, watcher, flag, setting,
  UI state, or documentation outside this plan becomes obsolete.

## Delivery Rules

- The series has exactly ten steps and uses the fixed titles below.
- Step 1 raises this complete plan and tracker. Per the user's explicit
  direction, the 1,500 changed-line soft cap does not apply to this first
  plan-containing PR. It remains plan-only and runs documentation validation.
- Steps 2–9 are implementation PRs. Each targets no more than 1,500 additions
  plus deletions against its own base, including tests and generated output
  (none is currently expected).
- At roughly 1,300 projected changed lines, reassess the implementation/test
  boundary before opening the PR. Prefer a smaller independently valid split;
  if no coherent split exists, update this plan with the evidence and reason
  before exceeding the soft cap.
- Do not combine adjacent steps merely because one lands below its estimate.
- Step 10 contains no production change. It records completion and moves
  `.plan/active/relay-request-concurrency/` to
  `.plan/completed/relay-request-concurrency/`.
- Steps merge in numeric order. Every implementation branch starts from current
  `main` after its predecessor merges and records overlapping drift, especially
  PR #686 if it has merged.
- Every implementation PR updates `TRACKER.md` with its base, actual changed-line
  count, verification, review result, and cleanup outcome.
- Run `aristotle-impl-review` for Steps 2–9 because they change routing contracts,
  lifecycle ownership, transport connection identity, domain ordering, and
  concurrency. Do not run it for documentation-only Steps 1 or 10.
- No implementation starts until the Step 1 plan PR merges and the user-approved
  design remains unchanged.

## Fixed PR Series

| Step | Branch | Exact PR title | Complexity rationale | Changed-line target | Outcome |
|---|---|---|---|---:|---|
| 1/10 | `plan/relay-request-concurrency` | `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/10]` | Plan/tracker documentation only; no runtime behavior. | 1,400–1,600; explicitly cap-exempt | Publish the reviewed architecture, fixed delivery sequence, boundaries, and verification gates. |
| 2/10 | `relay-request-concurrency-route-outcomes` | `🚧 [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/10]` | Two-phase routing, valid-only outcomes, request/control diagnostics, and a shared restart dispatcher cross handler, relay/debug, runtime, and shutdown ownership. | 900–1,300 | Expose closed privacy-safe identity before completion and replace shared restart flag/callback wiring while preserving serial relay behavior. |
| 3/10 | `relay-request-concurrency-route-lifecycle` | `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/10]` | One cross-transport acceptance/drain barrier changes composition and shared-dependency shutdown ordering. | 600–1,000 | Ensure relay and debug route work drains through one lifecycle owner before shared collaborators are disposed. |
| 4/10 | `relay-request-concurrency-relay-epochs` | `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/10]` | Explicit connection handles update connect/read/send/close and reconnect fencing across transport lifecycle. | 550–950 | Make old relay generations unable to send through or close a successor while preserving serial request execution. |
| 5/10 | `relay-request-concurrency-session-actions` | `🚧 [relay-request-concurrency] refactor(bridge): preserve session action order [step 5/10]` | Ordered family-scope resolution plus interaction lanes cross prompt, abort, pending-choice, auto-approval, failure, cleanup, and shutdown ownership. | 900–1,400 | Preserve execution/default and first-response order within one root family while unrelated families and force restart remain concurrent. |
| 6/10 | `relay-request-concurrency-session-lifecycle` | `🚧 [relay-request-concurrency] refactor(bridge): scope session family mutations [step 6/10]` | Root/descendant coordination crosses rename, archive, worktree cleanup/restore, subtree deletion, events, and persistence. | 750–1,250 | Preserve complete root-family lifecycle order while unrelated roots remain concurrent. |
| 7/10 | `relay-request-concurrency-session-visibility` | `🚧 [relay-request-concurrency] refactor(bridge): gate new session visibility [step 7/10]` | Repository-owned provisional visibility crosses persisted bindings, every session-bearing catalog/event read, post-create failures, recovery, and publication. | 600–1,100 | Hide partially initialized new sessions until initial work settles, then reveal exactly once even on failure. |
| 8/10 | `relay-request-concurrency-project-mutations` | `🚧 [relay-request-concurrency] refactor(bridge): order project path mutations [step 8/10]` | Canonical-path admission coordinates filesystem, Git, project persistence/activity, hide, failure, cleanup, and shutdown. | 650–1,100 | Prevent same-path open/create/hide inversion and overlapping Git setup while unrelated project paths remain concurrent. |
| 9/10 | `relay-request-concurrency-dispatch` | `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 9/10]` | Concurrent request completion, client-incarnation fencing, encrypted sends, reconnect, SSE startup, shutdown draining, and multi-client regressions. | 950–1,450 | Remove relay head-of-line blocking after every required domain and lifecycle owner is explicit. |
| 10/10 | `relay-request-concurrency-retire-plan` | `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 10/10]` | Mechanical documentation state update and directory move. | 50–150 | Record completion and move the plan from active to completed. |

## Step 1/10 — Publish The Plan

### Complexity

`🌱` trivial: documentation-only plan and tracker with no production, wire, or
database behavior.

### What

- Add this `PLAN.md` and `TRACKER.md` under the active plan slug.
- Record the incident evidence, architecture, fixed titles, line budgets,
  cleanup, overlap, verification, and retirement lifecycle.
- Run `aristotle-plan-review` against the complete production plan and apply
  valid findings directly.

### Why

Concurrency, late-response delivery, restart handoff, and shutdown are coupled
lifecycle concerns. Agreeing on their ownership before code avoids replacing
one global stall with response leakage or restart races.

### Risk And Test Focus

Risk is documentation drift or an under-specified independently invalid split.
Cross-check exact titles, denominator, branches, line targets, and every current
source owner. No product suite applies.

### Expected Result

- **User-visible:** None.
- **Persisted/database:** None.
- **Internal:** One reviewed implementation authority and fixed ten-PR series.

### Verification

- `git diff --check`
- exact title/branch/step-total comparison between plan and tracker
- plan files only in the diff

## Step 2/10 — Scope Restart Handoffs

### Complexity

`🚧` complex: a two-phase internal route contract changes both transport
consumers and every route diagnostic while a new shared restart dispatcher
replaces cross-layer callback/flag lifecycle wiring; it does not yet add request
concurrency.

### What

- Parse the external method once into a closed internal `HttpMethod` value, then
  make router matching synchronous and return a pending route with a typed
  matched/unmatched/invalid privacy-safe identity plus asynchronous completion.
- Audit relay control branches as well as routed work: retain diagnostically
  useful paths, connection/session identifiers, caught errors, and stack traces
  while selectively excluding request bodies, headers, prompts, and transcripts.
- Add sealed `ResponseOnly` and `RestartAccepted` completion variants; the latter
  constructs only the fixed successful restart response from its request ID.
- Let the restart handler return `RestartAccepted` only for a successful preflight.
- Add one concrete `BridgeRestartDispatcher` that owns single-flight handoff,
  invokes `BridgeRestartService`, and emits a typed shutdown-request stream.
- Inject that dispatcher directly into relay and debug consumers, subscribe from
  `OrchestratorSession`, and remove the `BridgeRuntime` callback forwarding.
- Update `RequestRouter`, `OrchestratorSession`, and `DebugServer` in lockstep.
- Close the debug HTTP response or synchronously enqueue the encrypted relay
  response on the current socket before dispatching `RestartAccepted`. Do not
  claim WebSocket remote-delivery acknowledgement.
- Dispose the restart dispatcher from runtime composition only after debug and
  session work drains.
- Remove the shared restart-request flag/callback and causal obsolete wiring/tests.

### Why

The global flag assumes only one route can finish at a time. Removing it first
makes concurrent request completion unable to steal or suppress a restart.

### Risk And Test Focus

Risk is representing restart with an error response, acting before response
enqueue/HTTP close, acting after a failed preflight, acting twice, losing the
shutdown signal, disposing its dispatcher under a debug request, losing useful
diagnostic context, or changing ordinary response/error mapping. Focus on sealed
outcome construction, direct shared-dispatcher injection, duplicate handoffs,
successful/failed handoff signal behavior and disposal, supported/unsupported
methods, matched/unmatched/invalid-target route identity, concurrent debug
requests, relay restart enqueue-before-handoff ordering, duplicate restart
requests, control-message log capture, failed preflight, router errors, and
shutdown races. A relay integration
gate must observe the correlated restart response being enqueued for the
originating connection before the handoff collaborator is invoked; an
end-to-end test retains the existing graceful-close delivery expectation without
describing it as a protocol acknowledgement.

### Expected Result

- **User-visible:** Restart keeps its existing best-effort acknowledgement then
  reconnect behavior; normal routes behave identically.
- **Persisted/database:** None.
- **Internal:** Restart acceptance is a valid-only route variant; one concrete
  dispatcher replaces the shared flag and cross-layer callback.

### Verification

- focused request-router, restart-handler/service, debug-server, and relay
  restart tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider routing assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 3/10 — Coordinate Routed Request Shutdown

### Complexity

`🚧` complex: relay and debug are independent Layer-4 consumers of one router
whose shared dependencies are currently disposed by the session lifecycle.

### What

- Add one concrete `RoutedRequestDispatcher` around `RequestRouter` with
  synchronous acceptance, one in-flight route registry, `beginShutdown`, and
  idempotent `drain`.
- Construct one instance at composition and inject it into both
  `OrchestratorSession` and `DebugServer`.
- Stop dispatcher acceptance when shutdown signals close relay/debug intake;
  return a typed 503 to a dispatch racing after the stop.
- Make both session teardown and debug drain await the same route barrier before
  session-owned route collaborators can be disposed.
- Keep transport-specific HTTP and relay completion registries with their
  transport owners.

### Why

Concurrent debug routing already exists. Without a shared route barrier, session
teardown can dispose repositories/services while a debug request is using them.
The later relay concurrency change must not multiply that pre-existing ownership
gap.

### Risk And Test Focus

Risk is accepting work after the barrier snapshot, waiting on the wrong future,
deadlocking concurrent session/debug drains, or disposing shared dependencies
early. Gate one relay request and one debug request simultaneously, begin
shutdown, assert intake rejection and no dependency disposal, release the routes
in either order, and assert one complete drain. Cover route failure and repeated
begin/drain calls.

### Expected Result

- **User-visible:** No ordinary behavior change; shutdown/restart no longer races
  active debug routing.
- **Persisted/database:** None.
- **Internal:** One routing lifecycle owner covers both current consumers before
  shared collaborator disposal.

### Verification

- focused dispatcher, debug-server shutdown, orchestrator shutdown, and runtime
  coordinator integration tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider shutdown assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 4/10 — Bind Relay Connection Epochs

### Complexity

`⚙️` moderate: an explicit connection handle updates Layer-0 connect, read,
send, close, close-code, and reconnect interactions without changing routing
concurrency yet.

### What

- Return an opaque `RelayConnection` handle from successful connect/reconnect.
- Require that handle for inbound reads, close metadata, synchronous
  `sendIfCurrent`, and `closeIfCurrent`.
- Make stale-handle send/close a closed typed outcome rather than operating on
  the mutable current socket.
- Ensure `closeIfCurrent` claims/detaches the exact handle synchronously before
  awaiting its close handshake.
- Update `OrchestratorSession` and all internal relay tests/callers in lockstep
  while request routing remains serial.

### Why

Checking a session-owned epoch and then calling a mutable-current-channel send
after asynchronous encryption leaves a reconnect race. The Layer-0 client must
enforce exact-socket identity at the final write/close seam.

### Risk And Test Focus

Risk is an old handle reading/sending through or closing a successor, losing the
authoritative close code, duplicate connection-state emission, or changing
reconnect behavior. Test old/new handle overlap, send/close rejection, current
send failure, remote close codes, pending connect cancellation, token re-auth,
normal reconnect, revoke, and bridge takeover.

### Expected Result

- **User-visible:** No behavior change; reconnect and takeover remain as today.
- **Persisted/database:** None.
- **Internal:** Every relay operation is explicitly bound to one WebSocket
  generation, ready for detached response completion.

### Verification

- focused `RelayClient`, registration/reconnect, token re-auth, and shutdown tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider transport assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 5/10 — Preserve Session Action Order

### Complexity

`🚧` complex: ordered asynchronous family-scope resolution plus atomic
interaction/family admission crosses prompt/default, abort, three pending-choice
handlers, auto approval, lifecycle, failure, cleanup, and shutdown.

### What

- Add one `SessionOperationDispatcher` with synchronous monotonic tickets, a
  bounded in-order root-family resolver, per-family lanes, optional sealed
  permission/question interaction lanes, idle cleanup, and closed acceptance.
- Return `(rootSessionId, pluginId)` from family resolution and key interactions
  by plugin plus stable owner session plus closed kind plus request ID.
- For legacy sessionless rejection, synchronously register an OpenCode-scoped
  unresolved-family barrier, resolve exactly one pending owner before execution,
  and return explicit not-found/ambiguous compatibility errors otherwise. Later
  OpenCode session operations await that barrier; other plugins do not.
- Append one completion atomically to every required lane before awaiting its
  predecessors; never acquire nested locks from operation callbacks.
- Route prompt/command plus defaults publication and abort through the family
  owner so their current arrival order is preserved.
- Add `PendingInteractionService(PermissionRepository, QuestionRepository,
  SessionOperationDispatcher)` and route permission reply, question answer,
  question reject, and `PermissionAutoApprovalService` through it.
- Store sole lifecycle ownership on `OrchestratorSession`; after the shared route
  intake closes, cancel plugin-event producers, await both the route barrier and
  `_pluginEventProcessingTails`, close acceptance, drain/dispose once, then
  dispose consumers and repositories.
- Preserve useful session/request context and caught failures in these diagnostics;
  selectively omit prompt/transcript content itself.

### Why

Detachment must not let abort overtake prompt acceptance/defaults or let the
second of two conflicting pending choices become the backend winner merely
because its validation lookup completed first. Root-family resolution also
establishes the common owner needed by Step 6.

### Risk And Test Focus

Risk is operation callbacks starting before tickets are registered, scope
resolution completion reordering tickets, deadlock across family/interaction
lanes, cross-plugin/session question-ID collisions, ambiguous legacy rejection,
legacy family resolution letting a later delete overtake, auto approval bypassing
the service or submitting after acceptance closes, defaults inversion, failure
poisoning, or premature disposal. Gate
binding lookup and backend acceptance to prove prompt/abort/default FIFO,
approve/reject and answer/reject arrival order from two surfaces, auto-approval
competition, same-plugin reused question IDs across families, unique/missing/
ambiguous legacy owner resolution, legacy reject versus root delete, root versus
child scope resolution, unrelated-family/plugin parallelism, force-restart
independence, failure release, idle cleanup, and repeated drain.

### Expected Result

- **User-visible:** The first pending choice and prompt/abort order for one
  session family remain authoritative; another family remains responsive.
- **Persisted/database:** No schema change; prompt defaults retain FIFO order.
- **Internal:** One lifecycle-owned dispatcher makes session-family and pending
  interaction causality explicit.

### Verification

- focused session-operation dispatcher, prompt/default, abort, permission,
  question, auto-approval, handler, and shutdown tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 6/10 — Scope Session Family Mutations

### Complexity

`🚧` complex: root/descendant ordering crosses archive worktree cleanup/restore,
rename propagation, subtree deletion/tombstones/events, persistence, and
multi-service shutdown.

### What

- Enroll rename, archive/unarchive, and complete deletion workflows in the
  `SessionOperationDispatcher` root-family lane before their first await.
- Keep `SessionMutationDispatcher` as owner of title persistence/backend
  propagation, repository deletion, subtree tombstones, and `deletedSessions`.
- Add `SessionDeletionService(SessionLifecycleService,
  SessionMutationDispatcher)`; reserve the family before callback-scoped cleanup
  and do not reacquire it from `SessionLifecycleService.cleanup`.
- Put public archive/unarchive around stored-session lookup, cleanup, archive
  writes, and worktree restoration on that family lane.
- Preserve cleanup rejection without deletion and remove settled family/backend
  mutation state after failure or completion.
- Preserve useful session/path identifiers and caught failures in mutation,
  lifecycle, and repository diagnostics.
- Replace direct-session/global-order tests with both root/child arrival orders,
  archive/delete inversion, and unrelated-root parallelism.

### Why

Deleting a root deletes every child and their worktree state. Different stable
session IDs in one family are therefore not independent.

### Risk And Test Focus

Risk is a child resolving outside its root, root deletion starting before an
earlier child action, later child rename succeeding during deletion, unarchive
restoring after cleanup, nested lane deadlock, or loss of repository
deletion/event ownership. Gate scope lookup, cleanup, and restore to cover
root-delete/child-rename and root-delete/child-execution in both arrival orders,
archive/delete and unarchive/delete inversion, cleanup rejection, unrelated
roots/plugins, failures, drain, and disposal.

### Expected Result

- **User-visible:** Root/child lifecycle actions retain arrival order.
- **Persisted/database:** No schema change; existing titles, archive state,
  deletion tombstones, and bindings keep their current meanings.
- **Internal:** Session mutation scope is the stable root family, not an
  individual child ID or the whole bridge.

### Verification

- focused session dispatcher/mutation/deletion/lifecycle repositories, handlers,
  worktree, and event tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 7/10 — Gate New Session Visibility

### Complexity

`🚧` complex: a repository-owned provisional visibility state crosses persisted
bindings, every session-bearing catalog/event read, post-create command/title
failure, exactly-once publication, and restart recovery.

### What

- Return a typed `UnpublishedSessionBinding` from `SessionRepository` after
  commit and mark its stable ID hidden before the transaction becomes visible.
- Remove the hidden marker if the transaction rolls back; only a committed token
  can be revealed/published.
- Filter that repository-owned set from every session-bearing catalog read,
  project-scoped session list, and event projection.
- Carry the opaque token through dedicated initial-command and initial-rename
  methods; use its verified family/plugin scope instead of ordinary filtered
  lookup, and expose no boolean/nullable/raw-ID bypass.
- Let `SessionCreationService` finish those initial operations, then
  atomically reveal and publish the token exactly once in `finally`, including
  failure paths, before returning or rethrowing the current route outcome.
- On process restart, treat committed rows as visible recovery state; add no
  schema field, backfill, callback, or wire change.
- Preserve useful session/path identifiers and caught failures in creation and
  repository diagnostics while omitting prompt content.

### Why

Delaying only the SSE event is insufficient because catalog reads can discover a
committed stable ID. Repository-owned visibility prevents another surface from
mutating the new session before its initial workflow settles.

### Risk And Test Focus

Risk is marking hidden after the transaction becomes visible, a catalog/event
path bypassing the gate, reveal happening twice or never, failure leaving a
session hidden, rollback leaking a marker, or restart recovery suppressing
committed data. A privileged operation that falls back to ordinary lookup would
also self-reject initialization. Gate command and metadata work while querying
every session-bearing catalog/event path; prove token-scoped command/rename can
resolve while ordinary reads cannot, and cover success, command failure, rename
failure, exactly-once reveal/publication, transaction rollback, concurrent
reads, and simulated new-repository recovery.

### Expected Result

- **User-visible:** A newly discoverable session has completed its initial
  command/title workflow; accepted failures still reveal authoritative state.
- **Persisted/database:** No schema change; committed bindings remain the restart
  recovery authority.
- **Internal:** Session visibility has one repository-owned atomic transition.

### Verification

- focused session creation/repository/catalog/event/binding-listener tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 8/10 — Order Project Path Mutations

### Complexity

`🚧` complex: ordered canonical-path admission coordinates filesystem and Git
side effects with project persistence/activity, hide semantics, failures, lane
cleanup, and shutdown.

### What

- Add `ProjectMutationDispatcher` with synchronous tickets, a bounded in-order
  resolver from normalized path/stable project ID to canonical stored path, and
  per-path lanes.
- Add `ProjectMutationService` as the sole create/open/hide workflow owner and
  make the three handlers thin consumers.
- Hold create/open through directory validation/creation, optional Git setup, and
  project/activity persistence; hold hide on the same canonical path lane.
- Preserve existing typed HTTP outcomes and project IDs, remove idle lanes, and
  assign acceptance/drain/disposal to `OrchestratorSession` after the shared
  route barrier.
- Preserve useful project paths/IDs and caught failures in diagnostics reachable
  through these workflows.
- Do not add symlink-wide filesystem canonicalization without evidence.

### Why

A slow open must not commit `hidden=false` after a later hide, and two same-path
Git initialization requests must not overlap. Different project paths have no
such invariant and should remain concurrent.

### Risk And Test Focus

Risk is a later known-path request overtaking an earlier project-ID resolution,
path alias mismatch, duplicate Git side effects, hide resurrection, failure
poisoning, or disposal missing accepted work. Gate project lookup and Git setup
to prove open/hide and create/open order in both directions, duplicate same-path
initialization, normalized aliases, unrelated-path parallelism, failures, idle
cleanup, and repeated drain.

### Expected Result

- **User-visible:** Same-project open/create/hide follows arrival order; unrelated
  projects remain responsive.
- **Persisted/database:** No schema or ID change; hidden/activity values retain
  their current meanings.
- **Internal:** Project mutation serialization is keyed to canonical path rather
  than the whole bridge.

### Verification

- focused project dispatcher/service, create/open/hide handler, initialization,
  activity, filesystem/Git, and shutdown tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 9/10 — Route Requests Concurrently

### Complexity

`🚧` complex: this changes cross-client request scheduling, client-incarnation
identity, encrypted response delivery, SSE startup, and session-owned completion
draining on top of the already-landed route, ordering, and relay-epoch contracts.

### What

- Stop awaiting routed requests from the relay frame loop.
- Synchronously obtain each pending route from the shared dispatcher, then track
  its transport completion under `OrchestratorSession`; allow same-client and
  cross-client responses to complete out of order by request ID.
- Replace the active-phone boolean with an opaque incarnation renewed by every
  successful key exchange/resume and removed on disconnect/reconnect.
- Complete encryption first, then perform client-incarnation validation and
  epoch-bound `sendIfCurrent` with no intervening await.
- Drop stale responses without claiming their underlying writes were cancelled.
- For `RestartAccepted`, dispatch exactly once after terminal delivery
  disposition: after enqueue when `sent`, without delivery when stale, or after
  synchronously claiming the current handle on send failure without awaiting its
  close handshake.
- On a current-handle send failure, use `closeIfCurrent` so normal relay
  reconnection runs; obsolete failures cannot close the successor.
- Detach and track initial SSE summary construction after synchronous subscribe,
  but enqueue it on the existing summary-ordering tail before building so an
  older snapshot cannot broadcast after a newer one.
- Add ongoing stable slow-route diagnostics and honest multi-operation shutdown
  diagnostics without discarding useful local context.
- Run a final diagnostic audit that preserves errors, stack traces, paths, and
  identifiers while selectively omitting known prompt/transcript content.
- Drain session-owned completion work plus the shared dispatcher barrier before
  route-owned dependencies are disposed.

### Why

The bridge's control plane and independent plugins must not disappear because
one async request is slow. Concurrent transport dispatch also makes the existing
force-restart capability reachable during a stalled plugin operation.

### Risk And Test Focus

Risk is late response delivery to a new connection, a reconnect between
encryption and write, summary completion inversion, unhandled task failure,
response/action execution after shutdown, reconnect loss after send failure,
accepted restart suppression after disconnect/rekey/send failure, request-ID
mismatch, or incomplete session-owned drain. Highest-value tests use intentionally
gated work to prove:

- a stalled request on one client does not delay another client's key exchange
  or health response;
- a later request from the same client can complete first;
- plugin-B/global work and plugin-A force-restart routing remain reachable;
- same-family session actions and same-path project mutations still follow their
  explicit causal lanes;
- disconnect/rekey/relay reconnect invalidates the old response even if a
  numeric `connId` appears again;
- accepted restart still dispatches exactly once after stale-origin or current
  send-failure disposition, while a current origin enqueues first;
- a reconnect during asynchronous encryption cannot redirect the final send,
  and an obsolete send failure cannot close the successor;
- a current response is delivered exactly once;
- initial SSE summary work does not hold frame ingestion and two overlapping
  builds cannot broadcast an older snapshot after a newer one; and
- shutdown prevents late sends and drains tracked work under existing bounds.

### Expected Result

- **User-visible:** Healthy clients and plugins remain online while one request
  stalls; only the dependent request remains pending or uncertain.
- **Persisted/database:** None; accepted operations retain existing commit rules.
- **Internal:** Relay ingestion and business routing become separate lifecycles
  with connection-fenced, domain-ordered completion.

### Verification

- new focused orchestrator request-concurrency integration suite
- existing relay client, registration/reconnect, token re-auth, debug-server,
  plugin-runtime force-restart, summary-ordering, and shutdown/error-recovery
  suites
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 10/10 — Retire The Plan

### Complexity

`🌱` trivial: documentation-only completion record and directory move.

### What

- Record merged PRs, actual line counts, verification, review outcomes, and
  cleanup results.
- Mark all success criteria complete.
- Move this plan directory from `.plan/active/` to `.plan/completed/`.

### Why

The durable plan must not remain active after all implementation work merges.

### Risk And Test Focus

Risk is stale links or completion claims. Cross-check GitHub and the tracker; no
product suite applies.

### Expected Result

- **User-visible:** None.
- **Persisted/database:** None.
- **Internal:** The completed implementation record is archived and no active
  work remains.

### Verification

- `git diff --check`
- verify the source directory is absent and completed directory is present
- verify every PR URL, merge SHA, title, line count, and check result

## Material Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Old request responds to a new/reused `connId` | Fence by relay epoch plus opaque client incarnation, not numeric ID alone. |
| Responses finish out of order | Preserve request IDs; test same-client inversion explicitly. |
| Restart acceptance is stolen or paired with failure | Land the sealed valid-only route outcome and shared single-flight restart dispatcher before concurrency. |
| Restart acknowledgement is overstated | For a current origin, guarantee only synchronous enqueue before handoff; for stale/failing delivery, dispatch the accepted handoff without claiming an acknowledgement. |
| Disconnect/rekey suppresses an accepted restart | Separate delivery disposition from the request-local action and dispatch exactly once after sent, stale, or current-send-failure disposition. |
| Disconnect falsely cancels an accepted write | Drop only delivery; preserve operation and existing uncertain-outcome semantics. |
| Reconnect occurs during response encryption | Encrypt first, then perform incarnation validation plus epoch-bound synchronous send with no await; Layer-0 rechecks the handle. |
| Obsolete send failure closes the successor | `closeIfCurrent` synchronously claims only the captured handle before asynchronous close. |
| Stalled operations accumulate | Track and observe them; do not introduce a global pool that can starve control work. Reassess per-plugin bulkheads only with evidence. |
| Force restart returns while old operation later completes | Keep generation checks and durable-commit fencing; late old-generation result maps to failure and cannot commit through `useAndCommit`. |
| Shutdown disposes dependencies under relay/debug routes | One shared dispatcher closes acceptance and drains both consumers before session-owned collaborators; each transport separately drains its surrounding work. |
| Abort/defaults overtake earlier prompt/command work | Land root-family session admission before transport concurrency; keep force restart outside it. |
| A later pending choice wins or reused ID blocks another family | Atomically claim plugin + stable owner + interaction identity and the modern request's family lane; route auto approval through the same service. |
| Legacy rejection races deletion | Register an OpenCode unresolved-family barrier before lookup; resolve one owner or return an explicit not-found/ambiguity limitation before mutation. |
| Root deletion races a child mutation | Resolve root family in admission order and reserve the complete subtree delete workflow before cleanup. |
| Unarchive restores a worktree after delete cleanup | Put archive/unarchive and delete on the same root-family lane around their complete filesystem/database workflows. |
| A partially initialized creation is announced | Return a typed unpublished binding and publish only after initial command and metadata rename settle. |
| Slow open resurrects a later-hidden project | Resolve canonical project path in admission order and serialize complete create/open/hide workflows per path. |
| Same-path Git setup overlaps | Keep directory/Git setup inside the canonical project-path lane. |
| Overlapping initial summaries regress client activity | Put initial builds and broadcasts on the existing summary-ordering tail while detaching that tracked work from frame ingestion. |
| Concurrent mutation corrupts session order | Keep explicit root-family lanes, whole-workflow reservation, and transactional repository writes. |
| Diagnostics lose useful request/control context | Keep closed route categorization while retaining errors, stacks, paths, and identifiers; selectively omit known prompt/transcript content. |
| Synchronous plugin code blocks the isolate | Keep synchronous work bounded; isolate/process redesign requires separate evidence and plan. |
| PR #686 changes adjacent code | Rebase every step on current `main`, audit overlap, and keep this implementation out of the feature PR. |

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Initial verdict:** rejected with four actionable findings; all findings
  applied directly
- **Second verdict after considerable PR-feedback changes:** rejected with four
  actionable findings; all findings applied directly
- **Third verdict after domain-ordering expansion:** rejected with four
  actionable findings; all findings applied directly; latest revision not
  re-reviewed
- **Reviewed scope:** complete `PLAN.md` and `TRACKER.md`
- **Findings applied:** added one shared relay/debug route-dispatch barrier;
  replaced completion-only route metadata with a synchronous two-phase router
  identity; added an explicit epoch-bound `RelayConnection` send/close seam with
  an atomic final-send gate; weakened restart delivery wording to enforceable
  enqueue-before-handoff semantics
- **Delivery correction:** split lifecycle and transport prerequisites so every
  implementation step remains below the 1,500-line soft cap
- **PR review corrections:** nine valid bot findings added closed method parsing,
  a complete route/control diagnostic audit, session-family execution and
  pending-choice ordering, root/child and archive/delete lifecycle ordering,
  whole-delete reservation, and monotonic detached summary delivery. A broader
  audit included only plausible multi-surface races: prompt-default FIFO,
  post-create publication, and same-path project mutation/Git ordering. The fixed
  series expanded to ten steps so creation visibility and each domain owner land
  independently before concurrent dispatch.
- **Second-review findings applied:** made ordinary/restart route outcomes sealed
  valid-only variants; replaced the forwarded restart callback with a concrete
  dispatcher and shutdown stream; assigned sole execution-dispatcher lifecycle
  ownership and exact teardown order; and kept repository deletion, tombstones,
  and deletion events unambiguously in `SessionMutationDispatcher` behind the
  callback-scoped cleanup lane.
- **Third-review findings applied:** made unpublished creation visibility
  repository-owned across catalog/event reads; scoped pending interactions by
  plugin with an explicit legacy OpenCode mapping; quiesced plugin-event
  producers/tails before session-dispatcher closure; and staged privacy audits
  through every touched lower-layer call graph.
- **Post-merge review corrections:** scoped modern interactions by stable owner
  session as well as plugin/request ID; added an OpenCode-scoped unresolved-family
  barrier and explicit ambiguity result for legacy sessionless rejection; and
  separated accepted restart execution from response eligibility so stale/send
  failure cannot suppress the handoff. These corrections do not change the fixed
  ten-step delivery series.
