# Concurrent Relay Request Routing: Tracker

## Current State

- **Plan slug:** `relay-request-concurrency`
- **Implementation base:** merged Step 2 at
  `fdc8ad67eafe18edb774249329f707bc6394c187`
- **Series state:** Step 1/10 plan PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) and correction
  [#688](https://github.com/sesori-ai/sesori_apps_monorepo/pull/688), plus Step 2/10
  [#690](https://github.com/sesori-ai/sesori_apps_monorepo/pull/690), merged
- **Current step:** Step 3/10 implemented and ready for review on
  `plan-parallel-requests`; PR link pending
- **Plan PR:** [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) merged
- **Next action:** commit, push, and open the Step 3 PR; Step 4 remains blocked
  until Step 3 is delivered and merged

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
- **Plausibility audit:** included prompt-default FIFO, delayed creation
  publication, and project open/create/hide/Git ordering because ordinary
  multi-surface flows can produce wrong persisted state or filesystem effects;
  theoretical symlink aliasing and unrelated read ordering remain out of scope
- **Series correction:** expanded from eight to ten total PRs so creation
  visibility and project-path ordering land independently before dispatch and every
  implementation PR remains below the 1,500-line soft cap

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
| [ ] | 3/10 | `plan-parallel-requests` | `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/10]` | 600–1,000 | Implemented and verified from `fdc8ad67`; PR link pending |
| [ ] | 4/10 | `relay-request-concurrency-relay-epochs` | `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/10]` | 550–950 | Blocked on Step 3 merge |
| [ ] | 5/10 | `relay-request-concurrency-session-actions` | `🚧 [relay-request-concurrency] refactor(bridge): preserve session action order [step 5/10]` | 900–1,400 | Blocked on Step 4 merge |
| [ ] | 6/10 | `relay-request-concurrency-session-lifecycle` | `🚧 [relay-request-concurrency] refactor(bridge): scope session family mutations [step 6/10]` | 750–1,250 | Blocked on Step 5 merge |
| [ ] | 7/10 | `relay-request-concurrency-session-visibility` | `🚧 [relay-request-concurrency] refactor(bridge): gate new session visibility [step 7/10]` | 600–1,100 | Blocked on Step 6 merge |
| [ ] | 8/10 | `relay-request-concurrency-project-mutations` | `🚧 [relay-request-concurrency] refactor(bridge): order project path mutations [step 8/10]` | 650–1,100 | Blocked on Step 7 merge |
| [ ] | 9/10 | `relay-request-concurrency-dispatch` | `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 9/10]` | 950–1,450 | Blocked on Step 8 merge |
| [ ] | 10/10 | `relay-request-concurrency-retire-plan` | `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 10/10]` | 50–150 | Blocked on Step 9 merge |

## Exact PR Titles

1. `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/10]`
2. `🚧 [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/10]`
3. `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/10]`
4. `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/10]`
5. `🚧 [relay-request-concurrency] refactor(bridge): preserve session action order [step 5/10]`
6. `🚧 [relay-request-concurrency] refactor(bridge): scope session family mutations [step 6/10]`
7. `🚧 [relay-request-concurrency] refactor(bridge): gate new session visibility [step 7/10]`
8. `🚧 [relay-request-concurrency] refactor(bridge): order project path mutations [step 8/10]`
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
  resolution precedes per-family execution, and pending choices atomically claim
  a plugin + stable owner session + sealed interaction lane. Auto approval shares
  that owner; legacy sessionless rejection resolves one OpenCode family behind a
  plugin-scoped barrier or returns an explicit compatibility error; force restart
  does not.
  `OrchestratorSession` cancels plugin-event producers and drains their tails plus
  routes before closing the dispatcher.
- Rename, archive/unarchive, and complete subtree deletion use the same root
  family; the mutation dispatcher retains title/deletion/tombstone/event
  ownership. The repository hides unpublished bindings from all catalog/event
  reads until initial command/title work settles; only the opaque unpublished
  token authorizes those initialization operations, then reveals exactly once.
- Project create/open/hide and Git setup use ordered canonical-path lanes;
  unrelated paths remain independent.
- Detached initial SSE summaries use the existing summary-ordering tail so an
  older snapshot cannot broadcast after a newer snapshot.
- Privacy audits cover ingress plus every touched lower-layer diagnostic that can
  receive routed/control paths or identifiers.
- No wire, database, client, UI, analytics, or plugin-interface change.

## Execution Rules

- Merge in numeric order. Each implementation branch starts from current `main`
  after its predecessor merges.
- Step 1 is plan-only and explicitly exempt from the user's 1,500-line soft cap.
- Steps 2–9 target no more than 1,500 changed lines, including tests. Reassess at
  roughly 1,300 projected lines and update the plan before any evidenced overage.
- Step 10 is documentation-only and moves the active plan to completed.
- Do not combine steps merely because one is smaller than estimated.
- Update this tracker in every step with base SHA, actual changed lines,
  verification, architecture review, cleanup, and PR/merge links.
- Run focused tests, strict app analysis, and `aristotle-impl-review` for Steps
  2–9. Documentation Steps 1 and 10 use relevant plan validation only.
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
  ordering with one explicit plugin-scoped family/interaction owner; omit prompt
  content selectively while preserving useful diagnostics.
- **Step 6:** remove global session mutation tails and individual-session scope;
  reserve complete family lifecycle workflows and retain useful diagnostics.
- **Step 7:** replace eager visibility with a repository-owned unpublished token
  and atomic reveal; retain useful creation diagnostics.
- **Step 8:** replace handler-level project workflow coordination and direct hide
  persistence with one canonical-path service/dispatcher; retain useful diagnostics.
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
- **Step 3/10 local delivery:** actual change size is 681 lines before recording
  the PR link; the owner-provided branch/worktree are reused as required.
