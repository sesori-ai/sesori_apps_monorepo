# Concurrent Relay Request Routing

## Status

- **Plan slug:** `relay-request-concurrency`
- **Status:** Reviewed — four architecture findings applied; revised plan not
  re-reviewed; Step 1 PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) open
- **Plan date:** 2026-08-02
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at
  `f6ec9e9dc66782197a46261de3bcc002e261a5bd`
- **Delivery:** one plan PR, five sequential implementation PRs, and one
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
   request IDs.
3. A stalled plugin-A request does not delay key exchange, global health,
   database-only reads, plugin-B requests, or a force-restart command for
   plugin A.
4. A response is sent only to the exact client-connection incarnation that
   originated its request. Disconnect, rekey, relay reconnect, or `connId`
   reassignment makes the old response ineligible for delivery without
   cancelling a mutation that may already have been accepted.
5. A successful bridge-restart response is synchronously enqueued on the exact
   current relay connection (or its debug HTTP response is closed) before that
   request's restart handoff runs. Concurrent unrelated responses cannot steal,
   suppress, or trigger the handoff. Relay enqueue is not represented as remote
   delivery acknowledgement.
6. Initial SSE summary construction does not block relay ingestion after the
   subscription itself is registered.
7. Shutdown stops accepting new routed work from both relay and debug consumers,
   prevents late sends, and drains every accepted shared route plus each
   transport's surrounding work before disposing dependencies under the
   existing process backstop.
8. Rename/delete ordering is retained for one session, while unrelated sessions
   and plugins no longer share the current global mutation tails.
9. Slow work is observable while it is still running through privacy-safe route
   templates; logs never include request bodies, headers, query values, source
   paths, prompts, session IDs, or other raw entity identifiers.
10. There is no wire-contract, database-schema, persisted-data, client API, or
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
  This plan changes the session rename/delete dispatcher from one global lane to
  one lane per stable session ID.

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
  request-local route result containing the `RelayResponse` and a closed
  post-response action (`none` or `restartBridge`). Route selection separately
  exposes a typed privacy-safe identity synchronously, before route completion.
- An unsuccessful restart preflight returns an ordinary error result with no
  post-response action.
- The debug transport closes its HTTP response before executing the attached
  action. The relay transport completes response encryption and synchronously
  enqueues it on the exact current connection before executing the action. The
  WebSocket API has no per-frame remote-delivery acknowledgement, so this plan
  does not claim one. Graceful close retains the existing delivery opportunity.
  No new wire field is added.

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
- `SessionMutationDispatcher` has one `_tail` and one `_backendTail` for every
  session. It uses them to make persisted rename, backend rename propagation,
  and delete order correctly, but an unrelated plugin/session can wait behind a
  slow backend mutation.
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
  routeIdentity: Matched(method, declaredPathTemplate)
               | Unmatched(method)
               | Invalid(method)
  completion: Future<RoutedRequestResult>

RoutedRequestResult
  response: RelayResponse
  postResponseAction: none | restartBridge
```

The synchronous phase selects exactly one handler and exposes only its declared
template, never concrete path parameters or query values. URI/matching failures
use `Invalid(method)`; a valid request with no handler uses `Unmatched(method)`.
No consumer repeats matching or inspects a raw request path for diagnostics.

The asynchronous completion preserves current handler/error mapping. A matched
handler declares its successful post-response action. Router errors, handler
errors, restart preflight failures, unmatched requests, and invalid requests
carry `none`.

Relay and debug consumers switch exhaustively over the action attached to that
exact completion. The debug transport closes its HTTP response before acting.
The serial relay transport encrypts and synchronously enqueues the response
before acting. This change ships before any request concurrency, removes the
shared restart flag, and gives later slow-route timers a privacy-safe identity
at dispatch time.

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

### 4. Concurrent relay request completion

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
7. run that result's post-response action only after a `sent` result;
8. on current-handle send failure, call `closeIfCurrent`; and
9. remove itself from the relay completion registry in `finally`.

Every successful key exchange or resume replaces the local client incarnation.
`phone_disconnected` removes it. Each relay reconnect supplies a new opaque
connection handle and clears all client incarnations. Therefore disconnect,
rekey, reconnect, and numeric `connId` reuse all invalidate old delivery.

The read loop schedules the operation without awaiting it. It continues to
process disconnect/reconnect controls, key exchange/resume, later requests, SSE
subscription controls, and session-view controls.

SSE subscription registration remains synchronous, while initial project
summary construction becomes separately tracked session work so a slow summary
source cannot hold relay ingestion.

On shutdown, the existing shutdown signal makes relay completion operations
abandon response delivery and post-response actions. `OrchestratorSession`
awaits both its session-owned completion work and the shared route-dispatcher
barrier before disposing repositories, services, controllers, and relay state.
`DebugServer` awaits its HTTP work plus the same route barrier. The process-level
coordinator retains its bounded backstop for an upstream future that never
settles.

### 5. Per-session mutation lanes

`SessionMutationDispatcher` retains its current contract but scopes its two
ordering tails by stable session ID:

- persisted title writes for one session stay ordered;
- backend title propagation for that session stays ordered;
- deleting that session waits for its pending backend rename;
- another session, including one owned by another plugin, uses another lane;
- failed operations release their lane and do not poison later work;
- settled idle lanes are removed so the map does not grow with historical
  sessions; and
- `drain`/`dispose` snapshot and await all active lanes before closing output.

Create-session metadata rename continues through the same dispatcher, so a
later delete of that newly created session cannot overtake its title propagation.
No plugin-wide queue is introduced.

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
- Unrelated session rename/delete operations no longer wait across plugins.

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
- Slow-route diagnostics use handler templates only. They never include body,
  headers, query/fragment values, concrete path parameters, prompts, source
  paths, branch/repository names, or raw identifiers.
- This is internal reliability work, not a new user action or product-adoption
  question, so no analytics event is added.

## Cleanup Assessment

- Step 2 removes the obsolete global `_restartRequested` flag,
  `requestRestart`/`consumeRestartRequest`, their tests, comments relying on
  serial routing, and the debug-server restart-service dependency if it has no
  remaining use.
- Step 3 replaces separate route-completion ownership with one shared dispatcher
  barrier; transport-specific HTTP/relay completion state remains with each
  transport.
- Step 4 removes mutable-current-channel `read`/`send` assumptions in favor of
  explicit opaque relay connection handles. Internal callers update in lockstep.
- Step 5 replaces the single `_inFlightRequestLabel` with honest tracked
  operations and removes/mends the completion-only `[shutdown] slow route`
  diagnostic. It does not preserve the serial route path for compatibility.
- Step 6 removes the global session mutation/backend tails and tests that encode
  cross-session serialization, replacing them with per-session ordering and lane
  cleanup coverage.
- Keep request IDs, client pending-request maps, plugin runtime leases,
  generation fences, endpoint-specific deadlines, and the shutdown backstop;
  each remains required under concurrent routing.
- No data field, database column, wire field, cache, job, watcher, flag, setting,
  UI state, or documentation outside this plan becomes obsolete.

## Delivery Rules

- The series has exactly seven steps and uses the fixed titles below.
- Step 1 raises this complete plan and tracker. Per the user's explicit
  direction, the 1,500 changed-line soft cap does not apply to this first
  plan-containing PR. It remains plan-only and runs documentation validation.
- Steps 2–6 are implementation PRs. Each targets no more than 1,500 additions
  plus deletions against its own base, including tests and generated output
  (none is currently expected).
- At roughly 1,300 projected changed lines, reassess the implementation/test
  boundary before opening the PR. Prefer a smaller independently valid split;
  if no coherent split exists, update this plan with the evidence and reason
  before exceeding the soft cap.
- Do not combine adjacent steps merely because one lands below its estimate.
- Step 7 contains no production change. It records completion and moves
  `.plan/active/relay-request-concurrency/` to
  `.plan/completed/relay-request-concurrency/`.
- Steps merge in numeric order. Every implementation branch starts from current
  `main` after its predecessor merges and records overlapping drift, especially
  PR #686 if it has merged.
- Every implementation PR updates `TRACKER.md` with its base, actual changed-line
  count, verification, review result, and cleanup outcome.
- Run `aristotle-impl-review` for Steps 2–6 because they change routing contracts,
  lifecycle ownership, transport connection identity, concurrency, and mutation
  ordering. Do not run it for documentation-only Steps 1 or 7.
- No implementation starts until the Step 1 plan PR merges and the user-approved
  design remains unchanged.

## Fixed PR Series

| Step | Branch | Exact PR title | Complexity rationale | Changed-line target | Outcome |
|---|---|---|---|---:|---|
| 1/7 | `plan/relay-request-concurrency` | `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/7]` | Plan/tracker documentation only; no runtime behavior. | 900–1,100; explicitly cap-exempt | Publish the reviewed architecture, fixed delivery sequence, boundaries, and verification gates. |
| 2/7 | `relay-request-concurrency-route-outcomes` | `⚙️ [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/7]` | Two-phase internal routing contract crosses handlers, router, relay/debug consumers, diagnostics, and restart sequencing. | 700–1,100 | Expose route identity before completion and replace the shared restart flag with a request-local post-response action while preserving serial relay behavior. |
| 3/7 | `relay-request-concurrency-route-lifecycle` | `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/7]` | One cross-transport acceptance/drain barrier changes composition and shared-dependency shutdown ordering. | 600–1,000 | Ensure relay and debug route work drains through one lifecycle owner before shared collaborators are disposed. |
| 4/7 | `relay-request-concurrency-relay-epochs` | `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/7]` | Explicit connection handles update connect/read/send/close and reconnect fencing across transport lifecycle. | 550–950 | Make old relay generations unable to send through or close a successor while preserving serial request execution. |
| 5/7 | `relay-request-concurrency-dispatch` | `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 5/7]` | Concurrent request completion, client-incarnation fencing, encrypted sends, reconnect, SSE startup, shutdown draining, and multi-client regressions. | 950–1,450 | Remove relay head-of-line blocking using the already-scoped route, lifecycle, and connection contracts. |
| 6/7 | `relay-request-concurrency-session-mutations` | `⚙️ [relay-request-concurrency] refactor(bridge): scope session mutation ordering [step 6/7]` | Keyed asynchronous ordering and drain/cleanup invariants across session persistence and plugin propagation. | 450–850 | Preserve same-session rename/delete order while allowing unrelated sessions/plugins to mutate concurrently. |
| 7/7 | `relay-request-concurrency-retire-plan` | `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 7/7]` | Mechanical documentation state update and directory move. | 50–150 | Record completion and move the plan from active to completed. |

## Step 1/7 — Publish The Plan

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
- **Internal:** One reviewed implementation authority and fixed seven-PR series.

### Verification

- `git diff --check`
- exact title/branch/step-total comparison between plan and tracker
- plan files only in the diff

## Step 2/7 — Scope Restart Handoffs

### Complexity

`⚙️` moderate: a two-phase internal route contract changes both transport
consumers, privacy-safe diagnostics, and restart lifecycle sequencing, but does
not yet add concurrency.

### What

- Make router matching synchronous and return a pending route with a typed
  matched/unmatched/invalid privacy-safe identity plus asynchronous completion.
- Add a typed completion with response and closed post-response action.
- Let the restart handler declare `restartBridge` only for a successful preflight.
- Update `RequestRouter`, `OrchestratorSession`, and `DebugServer` in lockstep.
- Close the debug HTTP response or synchronously enqueue the encrypted relay
  response on the current socket before exhaustively applying its action. Do not
  claim WebSocket remote-delivery acknowledgement.
- Remove the shared restart-request flag and causal obsolete wiring/tests.

### Why

The global flag assumes only one route can finish at a time. Removing it first
makes concurrent request completion unable to steal or suppress a restart.

### Risk And Test Focus

Risk is acting before response enqueue/HTTP close, acting after a failed
preflight, acting twice, exposing raw paths, or changing ordinary response/error
mapping. Focus on matched/unmatched/invalid route identity, concurrent debug
requests, relay restart enqueue-before-handoff ordering, duplicate restart
requests, failed preflight, router errors, and shutdown races. A relay integration
gate must observe the correlated restart response being enqueued for the
originating connection before the handoff collaborator is invoked; an
end-to-end test retains the existing graceful-close delivery expectation without
describing it as a protocol acknowledgement.

### Expected Result

- **User-visible:** Restart keeps its existing best-effort acknowledgement then
  reconnect behavior; normal routes behave identically.
- **Persisted/database:** None.
- **Internal:** Restart intent belongs to its routed result; no shared request flag.

### Verification

- focused request-router, restart-handler/service, debug-server, and relay
  restart tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider routing assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 3/7 — Coordinate Routed Request Shutdown

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

## Step 4/7 — Bind Relay Connection Epochs

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

## Step 5/7 — Route Requests Concurrently

### Complexity

`🚧` complex: this changes cross-client request scheduling, client-incarnation
identity, encrypted response delivery, SSE startup, and session-owned completion
draining on top of the already-landed route and relay-epoch contracts.

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
- Run a post-response action only after `sendIfCurrent` reports `sent`.
- On a current-handle send failure, use `closeIfCurrent` so normal relay
  reconnection runs; obsolete failures cannot close the successor.
- Detach and track initial SSE summary construction after synchronous subscribe.
- Add ongoing privacy-safe slow-route diagnostics and honest multi-operation
  shutdown diagnostics.
- Drain session-owned completion work plus the shared dispatcher barrier before
  route-owned dependencies are disposed.

### Why

The bridge's control plane and independent plugins must not disappear because
one async request is slow. Concurrent transport dispatch also makes the existing
force-restart capability reachable during a stalled plugin operation.

### Risk And Test Focus

Risk is late response delivery to a new connection, a reconnect between
encryption and write, unhandled task failure, response/action execution after
shutdown, reconnect loss after send failure, request-ID mismatch, or incomplete
session-owned drain. Highest-value tests use intentionally gated routes to prove:

- a stalled request on one client does not delay another client's key exchange
  or health response;
- a later request from the same client can complete first;
- plugin-B/global work and plugin-A force-restart routing remain reachable;
- disconnect/rekey/relay reconnect invalidates the old response even if a
  numeric `connId` appears again;
- a reconnect during asynchronous encryption cannot redirect the final send,
  and an obsolete send failure cannot close the successor;
- a current response is delivered exactly once;
- initial SSE summary work does not hold frame ingestion; and
- shutdown prevents late sends and drains tracked work under existing bounds.

### Expected Result

- **User-visible:** Healthy clients and plugins remain online while one request
  stalls; only the dependent request remains pending or uncertain.
- **Persisted/database:** None; accepted operations retain existing commit rules.
- **Internal:** Relay ingestion and business routing become separate lifecycles
  with connection-fenced completion.

### Verification

- new focused orchestrator request-concurrency integration suite
- existing relay client, registration/reconnect, token re-auth, debug-server,
  plugin-runtime force-restart, and shutdown/error-recovery suites
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 6/7 — Scope Session Mutation Ordering

### Complexity

`⚙️` moderate: keyed asynchronous lanes must preserve same-session persistence,
backend propagation, deletion, failure release, cleanup, and shutdown drain.

### What

- Replace global session mutation/backend tails with per-session lanes.
- Keep rename persistence before backend propagation and keep delete behind the
  same session's pending backend rename.
- Allow unrelated sessions and plugins to progress independently.
- Remove settled idle lanes and drain every active lane on dispose.
- Replace global-order tests with same-session and cross-session concurrency
  coverage.

### Why

Once the transport stops imposing global order, this directly caused secondary
bottleneck should represent its real invariant rather than serializing unrelated
plugins.

### Risk And Test Focus

Risk is delete overtaking rename, lane removal losing queued work, failure
poisoning a lane, or dispose missing an operation added before shutdown. Focus on
same-session rename/delete, metadata rename/delete, unrelated plugin/session
parallelism, failures, repeated drain, and disposal.

### Expected Result

- **User-visible:** A slow rename/delete for one session no longer delays an
  unrelated session; same-session behavior remains ordered.
- **Persisted/database:** No schema change; existing title and deletion writes
  retain their order.
- **Internal:** Mutation serialization is keyed to the stable session resource
  instead of the whole bridge.

### Verification

- focused `SessionMutationDispatcher`, create/rename/delete handler, and session
  creation service tests
- `dart analyze --fatal-infos` from `bridge/app`
- full `bridge/app` tests if focused changes expose wider assumptions
- `git diff --check`, changed-line count, and `aristotle-impl-review`

## Step 7/7 — Retire The Plan

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
| Restart action is stolen by another response | Land typed request-local post-response action before concurrency. |
| Restart acknowledgement is overstated | Guarantee only synchronous enqueue on the exact relay handle before handoff; keep graceful close and end-to-end delivery coverage without claiming remote acknowledgement. |
| Disconnect falsely cancels an accepted write | Drop only delivery; preserve operation and existing uncertain-outcome semantics. |
| Reconnect occurs during response encryption | Encrypt first, then perform incarnation validation plus epoch-bound synchronous send with no await; Layer-0 rechecks the handle. |
| Obsolete send failure closes the successor | `closeIfCurrent` synchronously claims only the captured handle before asynchronous close. |
| Stalled operations accumulate | Track and observe them; do not introduce a global pool that can starve control work. Reassess per-plugin bulkheads only with evidence. |
| Force restart returns while old operation later completes | Keep generation checks and durable-commit fencing; late old-generation result maps to failure and cannot commit through `useAndCommit`. |
| Shutdown disposes dependencies under relay/debug routes | One shared dispatcher closes acceptance and drains both consumers before session-owned collaborators; each transport separately drains its surrounding work. |
| Concurrent mutation corrupts session order | Keep explicit per-session lanes and transactional repository writes. |
| Synchronous plugin code blocks the isolate | Keep synchronous work bounded; isolate/process redesign requires separate evidence and plan. |
| PR #686 changes adjacent code | Rebase every step on current `main`, audit overlap, and keep this implementation out of the feature PR. |

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Verdict:** rejected with four actionable findings; all findings applied
  directly; revised plan not re-reviewed
- **Reviewed scope:** complete `PLAN.md` and `TRACKER.md`
- **Findings applied:** added one shared relay/debug route-dispatch barrier;
  replaced completion-only route metadata with a synchronous two-phase router
  identity; added an explicit epoch-bound `RelayConnection` send/close seam with
  an atomic final-send gate; weakened restart delivery wording to enforceable
  enqueue-before-handoff semantics
- **Delivery correction:** split lifecycle and transport prerequisites so every
  implementation step remains below the 1,500-line soft cap
