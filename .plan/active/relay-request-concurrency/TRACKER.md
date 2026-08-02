# Concurrent Relay Request Routing: Tracker

## Current State

- **Plan slug:** `relay-request-concurrency`
- **Implementation base:** `main` at
  `f6ec9e9dc66782197a46261de3bcc002e261a5bd`
- **Series state:** Step 1/7 plan PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) open
- **Current step:** Step 1/7 — publish the durable plan
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
  enforceable enqueue-before-restart wording; implementation split expanded to
  preserve the 1,500-line soft cap

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [ ] | 1/7 | `plan/relay-request-concurrency` | `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/7]` | 900–1,100; explicitly cap-exempt | [PR #687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) open; architecture findings applied |
| [ ] | 2/7 | `relay-request-concurrency-route-outcomes` | `⚙️ [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/7]` | 700–1,100 | Blocked on Step 1 merge |
| [ ] | 3/7 | `relay-request-concurrency-route-lifecycle` | `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/7]` | 600–1,000 | Blocked on Step 2 merge |
| [ ] | 4/7 | `relay-request-concurrency-relay-epochs` | `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/7]` | 550–950 | Blocked on Step 3 merge |
| [ ] | 5/7 | `relay-request-concurrency-dispatch` | `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 5/7]` | 950–1,450 | Blocked on Step 4 merge |
| [ ] | 6/7 | `relay-request-concurrency-session-mutations` | `⚙️ [relay-request-concurrency] refactor(bridge): scope session mutation ordering [step 6/7]` | 450–850 | Blocked on Step 5 merge |
| [ ] | 7/7 | `relay-request-concurrency-retire-plan` | `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 7/7]` | 50–150 | Blocked on Step 6 merge |

## Exact PR Titles

1. `🌱 [relay-request-concurrency] docs: plan concurrent bridge requests [step 1/7]`
2. `⚙️ [relay-request-concurrency] refactor(bridge): scope restart handoffs [step 2/7]`
3. `🚧 [relay-request-concurrency] refactor(bridge): coordinate routed request shutdown [step 3/7]`
4. `⚙️ [relay-request-concurrency] refactor(bridge): bind relay connection epochs [step 4/7]`
5. `🚧 [relay-request-concurrency] fix(bridge): route client requests concurrently [step 5/7]`
6. `⚙️ [relay-request-concurrency] refactor(bridge): scope session mutation ordering [step 6/7]`
7. `🌱 [relay-request-concurrency] docs: retire concurrent routing plan [step 7/7]`

## Locked Decisions

- Relay frame decode/key exchange stays ordered; routed business requests do not.
- No global, per-connection, or per-plugin transport queue.
- Existing request IDs support out-of-order responses.
- Backend-specific concurrency restrictions stay in the owning plugin.
- No generic route timeout or global worker pool.
- Late responses require relay-epoch and client-incarnation fencing.
- Disconnect drops response delivery, not an accepted mutation.
- Restart handoff becomes a typed action belonging to its exact route result.
- Route identity is selected synchronously by `RequestRouter` before completion;
  unmatched/invalid identities never expose raw paths.
- Relay and debug routing share one dispatcher acceptance/drain barrier before
  shared dependencies are disposed.
- Layer-0 relay reads/sends/closes use an opaque exact-connection handle; final
  client validation and synchronous send have no intervening await.
- Relay restart guarantees enqueue-before-handoff, not remote acknowledgement.
- Force restart and generation fencing retain their current semantics.
- Session rename/delete ordering becomes per session, not bridge-global.
- No wire, database, client, UI, analytics, or plugin-interface change.

## Execution Rules

- Merge in numeric order. Each implementation branch starts from current `main`
  after its predecessor merges.
- Step 1 is plan-only and explicitly exempt from the user's 1,500-line soft cap.
- Steps 2–6 target no more than 1,500 changed lines, including tests. Reassess at
  roughly 1,300 projected lines and update the plan before any evidenced overage.
- Step 7 is documentation-only and moves the active plan to completed.
- Do not combine steps merely because one is smaller than estimated.
- Update this tracker in every step with base SHA, actual changed lines,
  verification, architecture review, cleanup, and PR/merge links.
- Run focused tests, strict app analysis, and `aristotle-impl-review` for Steps
  2–6. Documentation Steps 1 and 7 use relevant plan validation only.
- Re-audit overlap with open PR #686 before each implementation branch; do not
  fold concurrent-routing production changes into that feature PR.

## Cleanup Outcomes Planned

- **Step 2:** remove global restart-request flag and serial-routing comments.
- **Step 3:** replace separate relay/debug route completion ownership with one
  shared lifecycle barrier.
- **Step 4:** replace mutable-current-channel relay operations with explicit
  exact-connection handles.
- **Step 5:** remove the single in-flight request label and completion-only,
  shutdown-mislabeled slow-route diagnostic.
- **Step 6:** remove global session mutation tails and cross-session serialization
  expectations.
- **No cleanup:** wire fields, database data, plugin leases/generations, request
  IDs, endpoint deadlines, and shutdown backstop remain required.

## Verification Log

- **Step 1/7 architecture review:** initial plan was rejected with four valid
  lifecycle/transport findings. All were applied directly; repository policy
  does not re-review direct corrections and no approval of the revised plan is
  claimed.
- **Step 1/7 delivery:** opened plan PR
  [#687](https://github.com/sesori-ai/sesori_apps_monorepo/pull/687) with 979
  documentation-only changed lines. Exact titles/branches/step totals and
  `git diff --check` passed; the user explicitly exempted this first
  plan-containing PR from the 1,500-line soft cap.
