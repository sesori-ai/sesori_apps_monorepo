# S02-W04-P01: Add View-Scoped PR Polling

## 0. Metadata

- **ID:** S02-W04-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/session-pull-request-monitoring/s02-w04-p01-view-scoped-pr-polling`
- **Wave baseline:** pin the assessed current `main` tip after S02-W03 merges
- **Audited reference:** `e766684e0fdc22256419b7b99691021c9f14732d`
- **Contract-affecting:** Yes — bridge handling of additive relay declaration and cross-version freshness behavior

## 1. Goal and Cohesion

Activate bridge-side project presence and use it to own all recurring GitHub
work. This PR is cohesive because relay routing, per-connection aggregate state,
activation/branch/scheduled listeners, adaptive cadence, identity follow-up
eligibility, SSE completion wiring, and teardown land together. No client sends
the declaration until the next stage.

## 2. Dependencies and Baseline

- S02-W03-P01 is merged: dispatcher supports live/final requests, branch changes
  are durable, and archive is terminal.
- S01's `RelayProjectView` shared variant is available.
- Fetch/assess/pin current `main`, focusing on orchestrator connection handling,
  relay drop/disconnect paths, dispatcher result shape, and listener lifecycle.
- No schema migration is planned. If drift creates one, stop and stale-re-review
  rather than broadening this PR.

## 3. Scope

### In Scope

- Add `ProjectViewTracker` as the connection-scoped aggregate owner.
- Route `RelayProjectView` in `Orchestrator`; release a connection on phone
  disconnect and clear all declarations on relay loss/teardown.
- Expose typed `ProjectViewChange` 0->1 / 1->0 events and current membership
  reads needed only inside the tracker/consumer boundary.
- Add peer `ProjectViewPrRefreshListener`, `ScheduledPrRefreshListener`, and
  `PrBranchChangeListener` under `lib/src/listeners/pr_monitor/`.
- Wire each listener with typed streams and already-built dispatcher; no listener
  peer reference.
- On project 0->1, request all-state immediately.
- While viewed, request open refreshes at 15 seconds if any supported authored
  open PR exists, otherwise 90 seconds.
- Force successful all-state reconciliation at least every ten minutes without
  adding a second overlapping timer.
- Apply failure backoff at max(normal tier, 30s), doubling with fresh +/-20%
  jitter to a five-minute cap; success resets it.
- Trigger one immediate all-state refresh for a newly recorded branch only while
  viewed; unviewed branch persistence remains local-only.
- Let each origin issue at most one all-state follow-up on `identityChanged`
  after rechecking that project remains viewed.
- Ensure one-shot timers start after completion, never overlap, and cancel when
  the final viewer leaves.
- Complete `Orchestrator.compose` construction/wiring plus listener
  start/disposal and focused integration tests; `BridgeRuntime` remains
  lifecycle-only.

### Non-Goals

- Client API/repository/service/cubit sending.
- Changing session-view/unseen behavior.
- Branch observation only while viewed; it remains always-on for nonterminal
  sessions.
- Polling git, using `Timer.periodic`, or starting a second all-state deadline
  timer.
- Archive-final retries/follow-ups.
- Push notifications, PR UI, or removal of request compatibility triggers.

## 4. Audited Current Code and Assumptions

- `Orchestrator` already routes `RelaySessionView`, releases it per connection,
  and clears all on relay loss. Project presence follows the connection
  lifecycle shape but remains semantically separate.
- S02-W02 dispatcher exposes typed results/completions including mode,
  complete/truncated, authored-open count, identity change, rendered change,
  and coalesced satisfied request ids/origins.
- S02-W01 repository emits branch changes independently; S02-W03 final listener
  is already a peer in the target listener directory.
- GitHub provides no push stream through current `gh` integration, making
  view-scoped one-shot scheduling the concrete permitted polling case.
- No client sends `RelayProjectView` yet, so activation can be tested/released
  without changing production cadence for old clients.

## 5. Design and Ownership

### Expected files

Existing paths likely changed:

- `bridge/app/lib/src/bridge/orchestrator.dart`
- S02 `pr_refresh_dispatcher.dart` and typed result models only if completion
  fields needed by scheduling are absent
- orchestrator/runtime test harnesses and fakes

New target paths:

- `bridge/app/lib/src/services/project_view_tracker.dart`
- `bridge/app/lib/src/listeners/pr_monitor/project_view_pr_refresh_listener.dart`
- `bridge/app/lib/src/listeners/pr_monitor/scheduled_pr_refresh_listener.dart`
- `bridge/app/lib/src/listeners/pr_monitor/pr_branch_change_listener.dart`
- focused service/listener/integration tests

Do not merge these listeners into one class: activation, timer, and branch-event
triggers have distinct lifecycle/bookkeeping and must remain symmetric peers.

### ProjectViewTracker

State:

- `connectionId -> projectId`
- `projectId -> viewerCount`
- broadcast `ProjectViewChange(projectId, isViewed)` only for aggregate 0->1 or
  1->0 transitions

Operations:

- full-state `setViewing(connectionId, projectId?)` with idempotent replacement;
- `releaseConnection(connectionId)`;
- `clearAll()` that emits one 1->0 event per previously viewed project; and
- `isViewed(projectId)` for direct orchestrator diagnostics only if needed.

It owns state/invariants and deserves a standalone tracker; it performs no I/O,
calls no repository/dispatcher, and emits no transport event.

### Peer listeners

`ProjectViewPrRefreshListener`:

- owns one subscription to view transitions;
- dispatches all-state on 0->1;
- before one identity follow-up, verifies its locally tracked view state still
  contains the project;
- logs surfaced failure once; no timer.

`ScheduledPrRefreshListener`:

- owns view transition and dispatcher completion subscriptions plus exactly one
  timer per viewed project;
- marks the project active at 0->1 and waits only for an execution completion
  whose satisfied origins include `projectActivation` for that project;
- records the request id from each timer dispatch and thereafter
  cancels/reschedules only from completions whose satisfied request ids include
  its own id; session-request/branch/archive completions cannot rearm its timer
  or grant it another origin's identity follow-up;
- tracks last successful all-state completion, failure count, current tier, and
  generation token per project;
- chooses one next delay equal to the minimum of tier/backoff delay and remaining
  ten-minute all-state deadline while the deadline is not already overdue;
- upgrades the due trigger to all-state; only a complete successful all-state
  consumes the deadline;
- after an overdue all-state attempt fails, truncates, or changes identity,
  keeps the deadline pending but schedules the next all-state attempt from the
  bounded failure-backoff delay alone; the overdue zero remainder cannot cause
  an immediate retry loop;
- if its own scheduled request returns `identityChanged`, rechecks its locally
  tracked viewed set and issues at most one immediate all-state follow-up;
- schedules from completion time and never overlaps project work.

`PrBranchChangeListener`:

- owns independent branch-change and project-view stream subscriptions;
- maintains its own viewed set from typed transitions (no tracker/listener peer);
- dispatches one all-state request for a changed branch only if still viewed;
- rechecks the same condition before one identity follow-up.

### Data flow

```text
RelayProjectView(conn, project?)
  -> ProjectViewTracker aggregate transition
  -> activation listener -> all dispatcher request
  -> scheduled listener -> one next timer

SessionBranchChanged
  -> Orchestrator immediate sessionsUpdated
  -> branch listener if viewed -> all dispatcher request

dispatcher completion
  -> Orchestrator sessionsUpdated only when rendered data changed
  -> scheduled listener updates tier/deadline/backoff
```

### Timing and failure policy

- Fast tier: 15 seconds when complete supported open query contains >=1 authored
  open PR anywhere in the repository, before branch matching.
- Idle tier: 90 seconds otherwise.
- First failure delay: max(current tier, 30 seconds).
- Later failures: double prior base, apply new random +/-20% jitter each time,
  cap final duration at five minutes.
- Success: zero failure count and normal 15/90 tier.
- Ten-minute deadline is measured from last complete successful all-state. A
  truncated/failed/unavailable/identity-changed attempt does not consume it.
- Once an unsuccessful all-state attempt occurs at/after that deadline, the
  deadline remains due but backoff temporarily overrides its zero remainder;
  the next timer is still all-state and success resumes normal deadline math.
- The one-shot timer uses a generation token/cancellation check before dispatch
  and after await so a departed project's stale callback cannot rearm.

### Lifecycle and concurrency

- Orchestrator starts listener subscriptions before accepting view messages.
- `Orchestrator.compose` constructs the tracker and peer listeners once and
  injects their already-built dependencies; no runtime/listener constructs a
  peer or a lower-layer collaborator.
- Phone connection drop calls both session and project release paths.
- Relay loss calls `clearAll`, which produces cancellation transitions before
  reconnect. Clients must explicitly reassert.
- Leaving view cancels future timer. An already-running dispatcher request may
  finish/write, but no new request is scheduled and identity follow-up is
  forbidden.
- Listener teardown cancels subscriptions/timers and rejects rearm after dispose.
- Dispatcher remains the sole per-project overlap guard.

## 6. Backward Compatibility

- Old clients never send `RelayProjectView`; they create no timers and continue
  using W02's request-driven dispatcher triggers.
- New clients are not released until S03, after bridge route support exists.
- Old bridges encountering the additive project-view variant isolate it and
  retain request-driven behavior; S03 adds the cross-version test before send.
- `RelaySessionView` routing and unseen state are unchanged.
- Request compatibility source marker remains in `GetSessionsHandler` and is not
  cleaned up here.

## 7. Schema and Generated-Code Work

- No schema or generated contract changes are expected.
- If source edits unexpectedly require a schema/shared contract change, stop and
  request stale-plan review rather than hiding it in this behavior PR.

## 8. Verification

### Automated tests

- Tracker idempotence, connection replacement, multi-connection counts,
  per-connection release, clear-all transitions, and disposal.
- Relay route with project id/null, phone disconnect, relay loss, and reconnect
  requiring reassertion.
- 0->1 activation dispatches one all-state; extra viewers do not duplicate;
  1->0 cancels.
- Any authored open result selects 15s; zero selects 90s; calculation happens
  before branch matching.
- Timers are one-shot, scheduled after completion, non-overlapping, and
  generation-safe after viewer loss/dispose.
- Coalesced completion correlation: activation is recognized by satisfied
  origin, timer work by its recorded request id, and unrelated
  session/branch/archive completions are ignored by scheduler state.
- Failure backoff exact progression bounds/jitter with deterministic random;
  success reset.
- Ten-minute deadline cannot be crossed by 15/90 tier, is not consumed by
  truncated/failure/identity change, uses no second timer, and an unsuccessful
  overdue attempt waits bounded backoff rather than spinning at zero delay.
- Branch change while viewed dispatches all; unviewed persists/invalidation only.
- Identity follow-up is at most one and only while still viewed for each origin;
  dispatcher still queues zero automatic follow-ups.
- Multi-project timers operate independently; relay loss removes all ghost work.
- Archive-final remains exactly one/no retry and terminal sessions never enter
  viewed polling scope.
- Orchestrator emits refresh completion SSE only for rendered change and branch
  SSE independently; unseen timestamps remain unchanged.

### Manual verification

Deferred to S03-W03-M01 because no production client sends presence yet.

### Exact commands

```text
# workdir: bridge
dart pub get
make codegen
make analyze
make test

# workdir: bridge/app
dart analyze --fatal-infos
dart test
```

### Regression guide

- Old clients still receive request-triggered PR refresh without timers.
- Session-view mark-seen counts and relay reconnect cleanup remain unchanged.
- Branch watchers continue while no project is viewed.
- No timer survives final viewer/relay loss/shutdown.
- Headless/standalone bridge needs no desktop control channel or Flutter runtime.
- GitHub unavailable/non-GitHub projects do not disturb relay/session requests.

## 9. Risks

- Activation and scheduled triggers can duplicate work; dispatcher serialization
  and completion-driven rescheduling prevent overlap without peer coupling.
- A stale callback can resurrect a timer after 1->0; generation/cancellation
  checks guard both before dispatch and after completion.
- Failure deadline can be accidentally consumed; track only complete successful
  all-state completion.
- Merging triggers into one listener would violate symmetric ownership; retain
  peer classes and typed composition streams.

## 10. Acceptance Criteria

- Only viewed projects schedule GitHub work; local branch observation remains
  independent.
- Multi-connection presence transitions and relay cleanup are correct.
- 15/90 cadence, bounded jittered backoff, ten-minute all-state deadline, and
  no-overlap are deterministic and tested.
- Identity follow-ups remain origin-owned, bounded, and view-eligible.
- Old-client request freshness and unseen behavior remain intact.

## 11. Definition of Done

- Listener/tracker/runtime/test scope and exact commands are complete.
- `aristotle-impl-review` approves before PR opening.
- PR targets `main`; tracker records baseline/branch/URL/check state.
- S03-W01 starts only after merge.
