# Concurrent Relay Request Routing: Tracker

## Current State

- **Plan slug:** `relay-request-concurrency`
- **Implementation base:** current `main` at
  `132694ea379b18bd8f87d45ca5a7323945363039`, including merged Step 6 at
  `e4605eb15b68f5433b5740981d03ff6e63f964cb`
- **Series state:** Steps 1–6 merged; over-defensive Step 7 implementation
  [#716](https://github.com/sesori-ai/sesori_apps_monorepo/pull/716) closed without merge
- **Current step:** Step 7/10 PR
  [#720](https://github.com/sesori-ai/sesori_apps_monorepo/pull/720) open
- **Plan PR:** [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) merged
- **Next action:** review and merge corrected Step 7; Step 8 remains blocked

## Incident Evidence

- A live bridge stayed process-healthy and relay-connected while clients appeared
  offline.
- `POST /session/create` held the single relay read loop for 305,654 ms.
- Client key exchanges completed immediately after that route settled.
- Root cause: `OrchestratorSession` awaits routed business work before reading the
  next relay frame.

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Initial verdict:** rejected with four actionable findings; all findings
  applied directly
- **Date:** 2026-08-02
- **Reviewed scope:** complete `.plan/active/relay-request-concurrency/`
- **Findings applied:** one shared relay/debug routing lifecycle barrier;
  synchronous two-phase route identity; epoch-bound final relay send/close;
  enforceable enqueue-before-restart wording
- **Delivery correction:** expanded the implementation split to preserve the
  1,500-line soft cap
- **Second review:** after considerable PR-feedback changes, rejected with four
  further valid findings; all applied directly and latest revision not
  re-reviewed
- **Second-review corrections:** sealed valid-only ordinary/restart outcomes;
  concrete restart dispatcher plus shutdown stream instead of a forwarded
  callback; sole execution-dispatcher lifecycle ownership and teardown order;
  unambiguous dispatcher ownership of deletion, tombstones, and deletion events
- **Third review after domain-ordering expansion:** rejected with four further valid
  findings; all applied directly and latest revision not re-reviewed
- **Third-review corrections:** repository-owned unpublished visibility across
  catalog/event reads; plugin-scoped pending-question keys including legacy
  OpenCode mapping; plugin-event producer quiescence before session-dispatcher
  closure; and staged lower-layer privacy audits across touched call graphs
- **Owner proportionality correction:** the visibility finding was superseded on
  2026-08-03 after its implementation grew to 2,080 lines for an unobserved,
  bounded state. PR #716 closed without merge; the plan now records that accepted
  risk and uses a simple project FIFO rather than canonical-path machinery.
- **Corrected-plan review:** initial pre-review gate rejected six vague ownership
  points. The clarified exact file/layer map, synchronous FIFO admission, legacy
  interaction behavior, no-timer diagnostics, and private incarnation/completion
  lifecycle passed the allowed second `aristotle-plan-review` with no findings.

## PR Review Feedback

- **Reviewer:** `chatgpt-codex-connector` (GitHub actor type `Bot`)
- **Date:** 2026-08-02
- **Nine valid findings applied:**
  1. closed external-method parsing;
  2. removal of raw route diagnostics;
  3. prompt-before-abort ordering;
  4. delete-lane reservation before cleanup;
  5. monotonic detached initial summaries;
  6. removal of raw relay-control diagnostics;
  7. conflicting pending-choice ordering;
  8. root/descendant mutation coordination; and
  9. archive/unarchive ordering against deletion.
- **Plausibility audit correction:** keep prompt/default and complete family
  mutation ordering because inversion can change durable/backend state. Accept
  transient creation visibility, remove redundant modern interaction lanes, and
  serialize low-volume project mutations coarsely; theoretical symlink aliases
  and unrelated-project throughput remain out of scope.
- **Series correction:** the ten-step total remains fixed; Step 7 is now the
  documentation/agent correction and Step 8 is the reduced domain-ordering change.

## Post-Merge Review Feedback

- **Source:** three `chatgpt-codex-connector` bot threads posted immediately
  after PR #687 merged
- **Valid corrections:** scope modern pending interactions by plugin plus stable
  owner session plus request ID; resolve legacy sessionless rejection to one
  family behind an OpenCode-scoped admission barrier or return an explicit
  compatibility error; and dispatch accepted restart handoff after terminal
  sent/stale/send-failure disposition rather than suppressing it with delivery
- **Delivery impact:** no fixed step title, denominator, branch, or line budget
  changes; documentation-only correction
  [#688](https://github.com/sesori-ai/sesori_apps_monorepo/pull/688) merged as
  `0e31324a9ec3cbd08d53394d7a1c6e9e3b133b0e`

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/10 | `plan/relay-request-concurrency` | `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/10]` | 1,400–1,600; explicitly cap-exempt | [PR #687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) merged as `c4d42a15`; correction [#688](https://github.com/sesori-ai/sesori_apps_monorepo/pull/688) merged as `0e31324a` |
| [x] | 2/10 | `plan-parallel-requests` | `🚧 [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/10]` | 900–1,300 | [PR #690](https://github.com/sesori-ai/sesori_apps_monorepo/pull/690) merged as `fdc8ad67` with 1,552 changed lines |
| [x] | 3/10 | `plan-parallel-requests` | `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/10]` | 600–1,000 | [PR #696](https://github.com/sesori-ai/sesori_apps_monorepo/pull/696) merged as `95178462` |
| [x] | 4/10 | `plan-parallel-requests` | `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/10]` | 550–950 | [PR #699](https://github.com/sesori-ai/sesori_apps_monorepo/pull/699) merged as `9ac855a3` with 1,326 changed lines |
| [x] | 5/10 | `plan-parallel-requests` | `🚧 [relay-request-concurrency] refactor(bridge): preserve session action order [step 5/10]` | 900–1,400 | [PR #700](https://github.com/sesori-ai/sesori_apps_monorepo/pull/700) merged as `5ba0d3a6` with 1,534 changed lines |
| [x] | 6/10 | `plan-parallel-requests` | `🚧 [relay-request-concurrency] refactor(bridge): scope session family mutations [step 6/10]` | 750–1,250 | [PR #703](https://github.com/sesori-ai/sesori_apps_monorepo/pull/703) merged as `e4605eb1` with 1,054 changed lines |
| [ ] | 7/10 | `plan-parallel-requests` | `🌱 [relay-request-concurrency] docs: simplify remaining concurrency plan [step 7/10]` | 350–550 | [PR #720](https://github.com/sesori-ai/sesori_apps_monorepo/pull/720) open; PR #716 closed without merge |
| [ ] | 8/10 | `plan-parallel-requests` | `⚙️ [relay-request-concurrency] refactor(bridge): simplify domain mutation ordering [step 8/10]` | 500–900 | Blocked on corrected Step 7 merge |
| [ ] | 9/10 | `relay-request-concurrency-dispatch` | `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 9/10]` | 950–1,450 | Blocked on Step 8 merge |
| [ ] | 10/10 | `relay-request-concurrency-retire-plan` | `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 10/10]` | 50–150 | Blocked on Step 9 merge |

## Exact PR Titles

1. `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/10]`
2. `🚧 [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/10]`
3. `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/10]`
4. `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/10]`
5. `🚧 [relay-request-concurrency] refactor(bridge): preserve session action order [step 5/10]`
6. `🚧 [relay-request-concurrency] refactor(bridge): scope session family mutations [step 6/10]`
7. `🌱 [relay-request-concurrency] docs: simplify remaining concurrency plan [step 7/10]`
8. `⚙️ [relay-request-concurrency] refactor(bridge): simplify domain mutation ordering [step 8/10]`
9. `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 9/10]`
10. `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 10/10]`

## Locked Decisions

- Relay frame decode/key exchange stays ordered; routed business requests do not.
- No global, per-connection, or per-plugin transport queue.
- Existing request IDs support out-of-order responses.
- Backend-specific concurrency restrictions stay in the owning plugin.
- No generic route timeout or global worker pool.
- Late responses require relay-epoch and client-incarnation fencing.
- Disconnect drops response delivery, not an accepted mutation.
- Restart handoff becomes a sealed valid-only outcome belonging to its exact
  route; only successful acceptance can construct the fixed restart response.
- Route identity is selected synchronously by `RequestRouter` before completion;
  external methods parse to a closed enum for decisions while local diagnostics
  retain useful request/control context, errors, stack traces, and identifiers.
- Relay and debug routing share one dispatcher acceptance/drain barrier before
  shared dependencies are disposed.
- Layer-0 relay reads/sends/closes use an opaque exact-connection handle; final
  client validation and synchronous send have no intervening await.
- Relay restart guarantees current-origin enqueue-before-handoff, not remote
  acknowledgement; stale/failing delivery does not suppress the accepted action.
- Accepted restart action survives stale origin or current send failure; enqueue
  remains before handoff whenever the origin is current.
- One concrete restart dispatcher is injected directly into relay/debug,
  suppresses duplicate handoffs, and emits the orchestrator shutdown request as
  a stream; no callback is forwarded through `BridgeRuntime`.
- Force restart and generation fencing retain their current semantics.
- Session actions synchronously receive ordered tickets; bounded root-family
  resolution precedes per-family execution. Modern pending choices and auto
  approval use that family owner without a second interaction lane; legacy
  sessionless rejection retains its OpenCode compatibility barrier or returns an
  explicit compatibility error. Force restart remains outside the family lane.
  `OrchestratorSession` cancels plugin-event producers and drains their tails plus
  routes before closing the dispatcher.
- Rename, archive/unarchive, and complete subtree deletion use the same root
  family; the mutation dispatcher retains title/deletion/tombstone/event
  ownership. A committed session may be briefly visible during initial work;
  that bounded recoverable state is accepted without a visibility gate.
- Project create/open/hide and Git setup use one simple FIFO; unrelated project
  mutation parallelism is intentionally not promised.
- Detached initial SSE summaries use the existing summary-ordering tail so an
  older snapshot cannot broadcast after a newer snapshot.
- Privacy audits cover ingress plus every touched lower-layer diagnostic that can
  receive routed/control paths or identifiers.
- No wire, database, client, UI, analytics, or plugin-interface change.

## Execution Rules

- Merge in numeric order. Each implementation branch starts from current `main`
  after its predecessor merges.
- Step 1 is plan-only and explicitly exempt from the user's 1,500-line soft cap.
- Implementation Steps 2–6 and 8–9 target no more than 1,500 changed lines,
  including tests. Reassess at
  roughly 1,300 projected lines and update the plan before any evidenced overage.
- Step 10 is documentation-only and moves the active plan to completed.
- Do not combine steps merely because one is smaller than estimated.
- Update this tracker in every step with base SHA, actual changed lines,
  verification, architecture review, cleanup, and PR/merge links.
- Run focused tests, strict app analysis, and `aristotle-impl-review` for
  architecture-bearing implementation Steps 2–6 and 8–9. Documentation Steps 1,
  7, and 10 use relevant plan/agent validation only.
- Re-audit overlap with open PR #686 before each implementation branch; do not
  fold concurrent-routing production changes into that feature PR.

## Cleanup Outcomes Planned

- **Step 2:** remove global restart-request flag, forwarded handoff callback,
  serial-routing comments, and diagnostics that discarded useful caught errors.
- **Step 3:** replace separate relay/debug route completion ownership with one
  shared lifecycle barrier.
- **Step 4:** replace mutable-current-channel relay operations with explicit
  exact-connection handles.
- **Step 5:** replace accidental relay-loop prompt/default/abort and pending-choice
  ordering with one explicit family owner; Step 8 removes redundant dedicated
  modern interaction lanes while preserving useful diagnostics.
- **Step 6:** remove global session mutation tails and individual-session scope;
  reserve complete family lifecycle workflows and retain useful diagnostics.
- **Step 7:** no production cleanup; remove rejected visibility requirements from
  the plan and add evidence/proportionality guidance to the plan-maker agent.
- **Step 8:** remove redundant interaction-lane state/tests and replace
  handler-level project workflow coordination with one FIFO service.
- **Step 9:** remove the single in-flight request label and completion-only,
  shutdown-mislabeled slow-route diagnostic.
- **No cleanup:** wire fields, database data, plugin leases/generations, request
  IDs, endpoint deadlines, and shutdown backstop remain required.

## Verification Log

- **Step 1/10 architecture review:** initial plan was rejected with four valid
  lifecycle/transport findings. All were applied directly; repository policy
  does not re-review direct corrections. A second review after considerable
  PR-feedback changes rejected four further valid ownership/modeling findings;
  a third review after the domain-ordering expansion rejected four visibility,
  isolation, lifecycle, and privacy findings. All were applied directly, and no
  approval of the latest revision is claimed.
- **Step 1/10 delivery:** plan PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) merged as
  `c4d42a152d52d6aa2e3479b8f445d622bbe4b9a5` with 1,490 documentation-only
  changed lines and 10/10 checks passing. Exact titles/branches/step totals and
  `git diff --check` passed; the user explicitly exempted this first
  plan-containing PR from the 1,500-line soft cap.
- **Step 2/10 base and overlap:** based on `main` at `0e31324a`; adjacent PR
  #686 was already merged at `3bbb1e8e`, so its orchestrator changes were part
  of the base and no open overlap remained. The session-provided dedicated
  `plan-parallel-requests` branch replaced the originally planned branch name.
- **Step 2/10 implementation:** synchronous typed route selection now exposes
  closed matched/unmatched/invalid identities and sealed asynchronous ordinary
  or valid-only restart outcomes. One shared restart dispatcher owns duplicate
  handoff suppression, service invocation, typed shutdown emission, and runtime
  disposal after relay/debug drains; the flag and callback wiring are removed.
- **Step 2/10 verification:** 87 focused router/restart/service/dispatcher,
  debug, encrypted relay ordering/graceful-close, runtime-composition, and
  diagnostic capture tests passed. `dart analyze --fatal-infos` from `bridge/app` and
  `git diff --check` passed. Actual change size: 1,552 lines; PR
  [#690](https://github.com/sesori-ai/sesori_apps_monorepo/pull/690) merged as
  `fdc8ad67eafe18edb774249329f707bc6394c187`.
- **Step 2/10 architecture review:** `aristotle-impl-review` rejected one valid
  service-to-routing dependency. Moving `BridgeRestartDispatcher` and its test
  beside the routing outcome applied the finding directly; per policy, the fix
  was not re-reviewed.
- **Step 2/10 PR review:** five bot threads produced two valid corrections:
  new routing APIs now use required named parameters, and route labels remain
  closed for stable categorization.
  Two duplicate send-failure threads were declined because accepted restart
  explicitly survives delivery failure; the dispatcher-disposal race was
  declined because runtime disposal starts only after relay/debug route drains.
- **Step 2/10 owner logging direction:** local logs now retain useful caught
  errors, stack traces, paths, and connection/session/control identifiers. The
  plan and root `AGENTS.md` require selective removal only for known user data
  without debugging value; the bridge logger now emits attached errors/stacks at
  its default info threshold rather than hiding them below debug verbosity.
- **Step 2/10 cap exception:** the owner's review-requested repo-wide logging
  rule and matching plan/code corrections raised the PR 52 lines above the soft
  cap; splitting them would leave this PR governed by contradictory diagnostics.
- **Step 3/10 base and scope:** based directly on merged Step 2 at `fdc8ad67` on
  the owner-provided `plan-parallel-requests` branch. The change is internal
  bridge routing lifecycle work only: no wire, database, client, UI, analytics,
  or plugin-interface impact, and relay request execution remains serial.
- **Step 3/10 implementation:** one concrete `RoutedRequestDispatcher` owns the
  sole `RequestRouter`, synchronously returns sealed accepted/shutdown-rejected
  results, registers every accepted relay/debug route completion, fixes shutdown
  rejection to 503, and memoizes one drain barrier. Composition constructs one
  instance for `OrchestratorSession` and `DebugServer`; both shutdown entries
  close acceptance and both drains await the same barrier before session route
  collaborators are disposed. Debug full-request tracking and the current serial
  relay lifecycle remain transport-owned.
- **Step 3/10 cleanup:** removed direct router injection from both transports and
  the debug-to-session mutation-drain callback. Shared route completion ownership
  now has one lifecycle owner; domain dispatcher disposal still drains its own
  detached backend tail through normal session teardown.
- **Step 3/10 verification:** 63 focused dispatcher, router, debug HTTP/SSE and
  cross-transport shutdown, runtime composition, orchestrator shutdown/restart,
  registration, and shutdown-coordinator tests pass. The integration gate overlaps
  one encrypted relay route with one debug route, observes a post-stop debug 503,
  and proves both drains wait for the same route barrier. Strict
  `dart analyze --fatal-infos` from `bridge/app` and `git diff --check` pass.
- **Step 3/10 architecture review:** `aristotle-impl-review` approved all tracked
  and untracked Step 3 changes from `fdc8ad67` with no blocking findings.
- **Step 3/10 delivery:** [PR #696](https://github.com/sesori-ai/sesori_apps_monorepo/pull/696)
  merged as `95178462b794cb485523a62740b80e8f0206d977` at 680 changed lines.
- **Step 4/10 base and scope:** based directly on merged Step 3 at `95178462` on
  the owner-provided clean `plan-parallel-requests` branch. Relay routing remains
  serial; there is no wire, database, client, UI, analytics, or plugin-interface impact.
- **Step 4/10 implementation:** successful connect/reconnect returns one final,
  opaque `RelayConnection` for the exact WebSocket. Reads, auth/close metadata,
  synchronous sent/stale writes, and closed/stale closes require that handle;
  current close claims it before awaiting, and stale operations cannot touch a successor.
  `OrchestratorSession` carries the handle through reconnect, re-auth, response,
  SSE, and shutdown paths, and closes a successor returned after cancellation.
- **Step 4/10 cleanup:** removed mutable-current channel reads/sends/metadata/close,
  the mutable global authed-token value, and all parameterless relay close paths.
  Tests and benchmarks use genuine returned handles rather than a test-only seam.
- **Step 4/10 verification:** 80 focused RelayClient, SSE, orchestrator,
  registration/reconnect, revoke/takeover, token re-auth, event-drain, and shutdown
  tests pass. Strict `dart analyze --fatal-infos`, `git diff --check`, and minimal
  event-projection/catalog-soak benchmark runs pass; the catalog smoke passed alone
  after an initial parallel macOS SQLite native-asset codesign collision.
- **Step 4/10 architecture review:** `aristotle-impl-review` rejected the initial
  one-implementation `RelayConnection` interface under A5. Replacing it with a
  final privately constructed opaque handle applied the valid finding directly;
  per policy, the correction was not re-reviewed.
- **Step 4/10 PR review:** two Qodo bot findings were valid. Auth setup now reaches
  a terminal disconnected state without first emitting connected, with regression
  coverage, and new private connection helpers use required named parameters. A
  valid Cubic finding added a post-registration cancellation gate so shutdown
  cannot start a successor connection, with a blocked-registration regression test.
  Three Codex bot findings were also valid: observed socket closure now detaches
  its epoch immediately; reconnect separates close from connect so cancellation
  can stop the close-to-connect transition; and stale SSE sends remain queued for
  replay, including listener turnover while delivery is in flight. Follow-up
  verification passes 50 focused app tests, all 42 shared `EventQueue` tests,
  strict app/shared analysis, and `git diff --check`. Subsequent Cubic/Codex
  feedback identified two consequences of stale retries: the stale callback now
  detaches its subscriber immediately so a burst cannot consume the poison-event
  budget, and bandwidth accounting occurs only after a successful relay send.
  Follow-up Kody/Cubic/Codex feedback then closed the remaining exact-ownership
  gaps: initial-connect cancellation closes its promoted handle, stale SSE
  callbacks detach only their exact subscription owner, and ordinary routed
  responses also count bytes only after a successful send. All 30 focused
  registration/routing/SSE tests and strict app analysis pass after these fixes.
  Owner review also replaced the startup handle's `late` declaration with
  single-assignment `final` and removed the shutdown future's bang assertion in
  favor of explicit null checking plus promotion.
- **Step 4/10 delivery:** [PR #699](https://github.com/sesori-ai/sesori_apps_monorepo/pull/699)
  merged as `9ac855a3f64930a118675fa93786476337a987c9` at 1,326 changed
  lines; the owner-provided branch/worktree are reused.
- **Step 5/10 base and scope:** based directly on merged Step 4 at `9ac855a3`
  on the owner-provided `plan-parallel-requests` branch. The change adds internal
  session-family and pending-interaction ordering only: no wire, database,
  client, UI, analytics, or plugin-interface change; relay routing remains serial.
- **Step 5/10 implementation:** one lifecycle-owned `SessionOperationDispatcher`
  assigns monotonic admission, resolves stable root/plugin scope in order, and
  atomically claims per-family plus permission/question lanes. Prompt/defaults,
  abort, all pending-choice handlers, and auto approval use it. Legacy sessionless
  question rejection resolves exactly one owner behind its plugin barrier and
  returns explicit missing/ambiguous errors. Teardown quiesces plugin-event
  producers and routes before closing and draining dispatcher acceptance.
- **Step 5/10 cleanup:** removed direct pending-choice handler repository writes
  and the repository's sessionless legacy rejection path. Prompt content remains
  excluded from diagnostics while useful session/request/error context remains.
- **Step 5/10 verification:** 2,396 full `bridge/app` tests pass, along with
  strict `dart analyze --fatal-infos` and `git diff --check`. Focused coverage
  includes family/interaction FIFO, unrelated-family/plugin concurrency,
  failure release, idle cleanup, repeated drain, prompt/default/abort order,
  auto-approval competition, and unique/missing/ambiguous legacy owners.
- **Step 5/10 architecture review:** `aristotle-impl-review` approved all tracked
  and untracked Step 5 changes from `9ac855a3` with no blocking findings.
- **Step 5/10 PR review:** three bot findings were applied: the legacy wire path
  retains its dated compatibility cleanup marker; the abort-pending signal is
  emitted synchronously after dispatcher acceptance while backend abort remains
  family-ordered; and the legacy owner callback uses a required named parameter.
  Three suggestions were declined: pending questions have no authoritative
  database index and adding one would violate this step's no-schema scope; the
  fixed legacy OpenCode plugin's root query explicitly includes descendant
  questions; and timing out its plugin barrier would not cancel owner discovery
  and would let later same-plugin work violate the required arrival order.
  Follow-up Cubic/Codex findings were valid: every accepted abort now emits one
  terminal failure even when family admission fails before backend execution,
  and legacy owner discovery waits for all earlier accepted work on that plugin
  while continuing to block only later same-plugin admissions. The redundant
  legacy-barrier bookkeeping was removed; the ticketed resolution and plugin
  admission lanes own the actual reservation. Cache and concurrent-scan
  suggestions were declined as speculative machinery for bounded local catalog
  walks and a compatibility-only path without demonstrated load evidence.
- **Step 5/10 delivery:** [PR #700](https://github.com/sesori-ai/sesori_apps_monorepo/pull/700)
  merged as `5ba0d3a6029cdb699120e6254bd248c806fa2f95` at 1,534 changed
  lines. The 34-line soft-cap overage was directly caused
  by review-required terminal abort signaling and prior-plugin settlement coverage;
  splitting it would leave the ordering fix incomplete.
- **Step 6/10 base and scope:** based directly on merged Step 5 at `5ba0d3a6`
  on the owner-provided `plan-parallel-requests` branch. The change scopes
  rename, archive/unarchive, cleanup, and complete deletion to stable root-family
  operations. There is no wire, database, client, UI, analytics, or plugin-interface change.
- **Step 6/10 implementation:** `SessionMutationDispatcher` owns family admission
  for rename and callback-scoped cleanup/deletion, repository subtree deletion,
  tombstones, and `deletedSessions`. `SessionDeletionService` composes lifecycle
  cleanup with that owner without nested dispatch. Archive/unarchive holds one
  family lane through stored-session lookup, cleanup/restore, persistence, and
  best-effort backend archive notification.
- **Step 6/10 cleanup:** removed the mutation dispatcher's bridge-wide mutation
  and backend tails plus their drain helpers. Already-reserved cleanup is explicit,
  settled family state is removed by `SessionOperationDispatcher`, and direct
  handler coordination was replaced with the deletion service.
- **Step 6/10 verification:** 2,408 full `bridge/app` tests pass. Focused family,
  lifecycle, mutation, deletion, rename, and archive tests pass, along with strict
  `dart analyze --fatal-infos` and `git diff --check`.
- **Step 6/10 architecture review:** `aristotle-impl-review` rejected the initial
  split deletion-admission ownership and detached backend archive notification.
  Both valid findings were applied directly: mutation dispatch now owns deletion
  admission with callback-scoped cleanup, and archive notification settles inside
  the family lane. Per policy, the corrected implementation was not re-reviewed.
- **Step 6/10 delivery:** [PR #703](https://github.com/sesori-ai/sesori_apps_monorepo/pull/703)
  merged as `e4605eb15b68f5433b5740981d03ff6e63f964cb` at 1,054 changed lines.
- **Rejected Step 7 implementation:** [PR #716](https://github.com/sesori-ai/sesori_apps_monorepo/pull/716)
  was closed without merge at the owner's direction. It grew to 2,080 changed
  lines across creation, catalog, interaction, unseen, activity, option, and event
  owners to prevent an unobserved transient; no production cleanup is needed
  because none of those commits reached `main`.
- **Merged-step proportionality audit:** keep Step 2's route-local restart outcome,
  Step 3's shared route drain, Step 4's exact relay handle, Step 5's root-family
  FIFO/abort/legacy fallback, and Step 6's complete lifecycle/deletion scope.
  Step 8 removes Step 5's redundant modern interaction lanes. Broader Step 2/4
  simplification and detached archive notification were not planned because they
  would churn sound merged ownership without removing comparable machinery.
- **Remaining-plan correction:** Step 8 uses one coarse project FIFO rather than
  canonical-path lanes or a separate lifecycle owner. Step 9 is limited to
  detaching relay route/SSE-summary work, existing incarnation/epoch/restart
  fences, and shutdown drain required by the demonstrated head-of-line incident.
- **Corrected Step 7 delivery:** [PR #720](https://github.com/sesori-ai/sesori_apps_monorepo/pull/720)
  is open from current `main`; its diff is documentation/agent guidance only.
