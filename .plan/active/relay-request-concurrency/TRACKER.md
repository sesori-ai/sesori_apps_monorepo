# Concurrent Relay Request Routing: Tracker

## Current State

- **Plan slug:** `relay-request-concurrency`
- **Implementation base:** `main` at
  `f6ec9e9dc66782197a46261de3bcc002e261a5bd`
- **Series state:** Step 1/8 plan PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) open
- **Current step:** Step 1/8 — publish the durable plan
- **Plan PR:** [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687)
- **Next action:** monitor plan PR checks/review and address valid feedback

## Incident Evidence

- A live bridge stayed process-healthy and relay-connected while clients appeared
  offline.
- `POST /session/create` held the single relay read loop for 305,654 ms.
- Client key exchanges completed immediately after that route settled.
- Root cause: `OrchestratorSession` awaits routed business work before reading the
  next relay frame.

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Verdict:** rejected with four actionable findings; all findings applied
  directly; revised plan not re-reviewed
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

## PR Review Feedback

- **Reviewer:** `chatgpt-codex-connector` (GitHub actor type `Bot`)
- **Date:** 2026-08-02
- **Five valid findings applied:** closed method parsing and a complete raw-route
  diagnostic audit in Step 2; per-session prompt/command acceptance-before-abort
  ownership in new Step 5; whole-delete lane reservation before cleanup in Step
  6; and monotonic initial SSE summary construction on the existing ordering tail
  in Step 7
- **Series correction:** expanded from seven to eight total PRs so execution
  ordering lands independently before concurrent dispatch and remains below the
  1,500-line soft cap

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [ ] | 1/8 | `plan/relay-request-concurrency` | `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/8]` | 1,150–1,250; explicitly cap-exempt | [PR #687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) open; architecture and review findings applied |
| [ ] | 2/8 | `relay-request-concurrency-route-outcomes` | `🚧 [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/8]` | 900–1,300 | Blocked on Step 1 merge |
| [ ] | 3/8 | `relay-request-concurrency-route-lifecycle` | `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/8]` | 600–1,000 | Blocked on Step 2 merge |
| [ ] | 4/8 | `relay-request-concurrency-relay-epochs` | `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/8]` | 550–950 | Blocked on Step 3 merge |
| [ ] | 5/8 | `relay-request-concurrency-session-execution` | `⚙️ [relay-request-concurrency] refactor(bridge): preserve session execution order [step 5/8]` | 500–900 | Blocked on Step 4 merge |
| [ ] | 6/8 | `relay-request-concurrency-session-mutations` | `⚙️ [relay-request-concurrency] refactor(bridge): scope session mutation ordering [step 6/8]` | 450–850 | Blocked on Step 5 merge |
| [ ] | 7/8 | `relay-request-concurrency-dispatch` | `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 7/8]` | 950–1,450 | Blocked on Step 6 merge |
| [ ] | 8/8 | `relay-request-concurrency-retire-plan` | `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 8/8]` | 50–150 | Blocked on Step 7 merge |

## Exact PR Titles

1. `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/8]`
2. `🚧 [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/8]`
3. `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/8]`
4. `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/8]`
5. `⚙️ [relay-request-concurrency] refactor(bridge): preserve session execution order [step 5/8]`
6. `⚙️ [relay-request-concurrency] refactor(bridge): scope session mutation ordering [step 6/8]`
7. `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 7/8]`
8. `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 8/8]`

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
  external methods parse to a closed enum and no route diagnostic retains raw
  method/path text.
- Relay and debug routing share one dispatcher acceptance/drain barrier before
  shared dependencies are disposed.
- Layer-0 relay reads/sends/closes use an opaque exact-connection handle; final
  client validation and synchronous send have no intervening await.
- Relay restart guarantees enqueue-before-handoff, not remote acknowledgement.
- One concrete restart dispatcher is injected directly into relay/debug,
  suppresses duplicate handoffs, and emits the orchestrator shutdown request as
  a stream; no callback is forwarded through `BridgeRuntime`.
- Force restart and generation fencing retain their current semantics.
- Prompt/command acceptance and abort use one FIFO lane per stable session;
  force restart remains outside it. `OrchestratorSession` solely owns dispatcher
  shutdown after the shared route barrier and before service/repository disposal.
- Session rename/delete ordering becomes per session, not bridge-global; delete
  reserves its lane before lifecycle cleanup begins, while the mutation
  dispatcher retains deletion/tombstone/event ownership.
- Detached initial SSE summaries use the existing summary-ordering tail so an
  older snapshot cannot broadcast after a newer snapshot.
- No wire, database, client, UI, analytics, or plugin-interface change.

## Execution Rules

- Merge in numeric order. Each implementation branch starts from current `main`
  after its predecessor merges.
- Step 1 is plan-only and explicitly exempt from the user's 1,500-line soft cap.
- Steps 2–7 target no more than 1,500 changed lines, including tests. Reassess at
  roughly 1,300 projected lines and update the plan before any evidenced overage.
- Step 8 is documentation-only and moves the active plan to completed.
- Do not combine steps merely because one is smaller than estimated.
- Update this tracker in every step with base SHA, actual changed lines,
  verification, architecture review, cleanup, and PR/merge links.
- Run focused tests, strict app analysis, and `aristotle-impl-review` for Steps
  2–7. Documentation Steps 1 and 8 use relevant plan validation only.
- Re-audit overlap with open PR #686 before each implementation branch; do not
  fold concurrent-routing production changes into that feature PR.

## Cleanup Outcomes Planned

- **Step 2:** remove global restart-request flag, forwarded handoff callback,
  serial-routing comments, and every route diagnostic that formats raw transport
  method/path text.
- **Step 3:** replace separate relay/debug route completion ownership with one
  shared lifecycle barrier.
- **Step 4:** replace mutable-current-channel relay operations with explicit
  exact-connection handles.
- **Step 5:** replace accidental relay-loop prompt/command-before-abort ordering
  with one explicit per-session execution owner.
- **Step 6:** remove global session mutation tails and cross-session serialization
  expectations; move complete delete reservation before lifecycle cleanup.
- **Step 7:** remove the single in-flight request label and completion-only,
  shutdown-mislabeled slow-route diagnostic.
- **No cleanup:** wire fields, database data, plugin leases/generations, request
  IDs, endpoint deadlines, and shutdown backstop remain required.

## Verification Log

- **Step 1/8 architecture review:** initial plan was rejected with four valid
  lifecycle/transport findings. All were applied directly; repository policy
  does not re-review direct corrections. A second review after considerable
  PR-feedback changes rejected four further valid ownership/modeling findings;
  all were applied directly, and no approval of the latest revision is claimed.
- **Step 1/8 delivery:** opened plan PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) with 1,217
  documentation-only changed lines. Exact titles/branches/step totals and
  `git diff --check` passed; the user explicitly exempted this first
  plan-containing PR from the 1,500-line soft cap.
