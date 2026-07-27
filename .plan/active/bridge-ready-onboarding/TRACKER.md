# Bridge-Ready Mobile Onboarding: Tracker

## Plan State

- **Status:** Step 1 merged; Step 2 PR in review
- **Plan slug:** `bridge-ready-onboarding`
- **Implementation base:** `origin/main` at
  `235caf8e2cb73a5607ae8dcb662d7eb6e85dd3b1`
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/580
- **Implementation state:** Step 2 PR: https://github.com/sesori-ai/sesori_apps_monorepo/pull/587

## Plan Review

- **Verdict:** rejected with four actionable findings; all findings applied
  directly; revised plan not re-reviewed
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-26
- **Reviewed scope:** `.plan/active/bridge-ready-onboarding/`

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line budget | State |
|---|---|---|---|---:|---|
| [x] | 1/2 | `bridge-setup-ux-assessment` | `[bridge-ready-onboarding] refactor(bridge): separate session startup from serving [step 1/2]` | 650-950; reassess at 1,300; maximum 1,500 | [PR #585](https://github.com/sesori-ai/sesori_apps_monorepo/pull/585) merged |
| [ ] | 2/2 | `bridge-setup-ux-assessment` | `[bridge-ready-onboarding] fix(bridge): start relay before mobile onboarding [step 2/2]` | 450-750; reassess at 1,300; maximum 1,500 | [PR #587](https://github.com/sesori-ai/sesori_apps_monorepo/pull/587) in review |

## Execution Rules

- Step 1 is a standalone refactor PR that preserves user-visible startup
  behavior while making partial-start cleanup explicit. It must not contain
  onboarding ordering or copy changes.
- Step 2 starts from updated `origin/main` only after Step 1 merges. Do not open
  it as a stacked PR.
- Count additions plus deletions, including tests, against each PR base.
- Stop and update the plan before either PR exceeds 1,500 changed lines.
- Any newly discovered substantial refactor remains out of Step 2. Pause and
  revise the series rather than mixing it into the feature PR.
- Run the focused tests, strict app analyzer, and architecture implementation
  review declared for each step before merging.

## Current Pointer

- **Next action:** monitor Step 2 CI and review.

## Step 1 Verification

- Focused lifecycle, registration, reconnect, relay-client, event, and debug
  server tests pass.
- `dart test test/bridge/runtime/bridge_runtime_runner_test.dart` passes.
- `dart analyze --fatal-infos` passes from `bridge/app`.
- `aristotle-impl-review` approved the implementation on its second pass after
  the cancelled-startup path was fixed to preserve supervised exit sentinels.

## Step 2 Verification

- Focused onboarding service, status repository/API, runner guard, registration,
  and lifecycle tests pass.
- `dart analyze --fatal-infos` passes from `bridge/app`.
- `aristotle-impl-review` approved the relay-first onboarding data flow and
  composition-root lifecycle sequencing.

## Findings And Plan Deltas

- **2026-07-27 — Step 2 delivery:** Opened implementation PR
  [#587](https://github.com/sesori-ai/sesori_apps_monorepo/pull/587) and started
  CI/review monitoring.
- **2026-07-27 — Step 2 implementation:** Replaced the notification-registration
  gate with one finite, presentation-free immediate status decision; removed the
  long-poll `wait` contract; started preparation concurrently with relay startup;
  and moved ready-state QR/link presentation into the runner after session
  readiness. The existing user-directed worktree branch was reused.
- **2026-07-27 — Step 1 merge:** Implementation PR
  [#585](https://github.com/sesori-ai/sesori_apps_monorepo/pull/585) merged and
  became the Step 2 base.
- **2026-07-27 — Step 1 delivery:** Opened implementation PR
  [#585](https://github.com/sesori-ai/sesori_apps_monorepo/pull/585) and started
  CI/review monitoring.
- **2026-07-27 — Step 1 implementation:** Replaced the session `run` contract
  with one-shot startup/readiness and lifecycle-wait operations, added pending
  WebSocket handshake ownership/cancellation, armed a fresh relay iterator for
  every connection, migrated all in-repository callers, and added focused
  lifecycle/reconnect coverage. The user-directed existing worktree branch was
  used instead of creating the planned Step 1 branch.
- **2026-07-27 — Step 1 implementation review:** The first pass found that an
  early cancelled-startup return could bypass supervised restart sentinel
  finalization. The runner now finalizes typed exit state before returning; the
  second review approved the implementation.
- **2026-07-26 — Follow-up PR feedback:** Added `RelayClient` pending-handshake
  ownership/cancellation to Step 1 so shutdown cannot wait for the 15-second
  connect timeout or allow late channel promotion/auth; clarified that Step 2
  removes polling/retry timers but retains the request-local 35-second deadline
  timer that bounds and aborts the immediate status request.
- **2026-07-26 — PR feedback corrections:** Qualified the external auth-server
  source reference; distinguished presentation-silent compatibility recovery
  from warning-level diagnostics; required one fresh relay read iterator per
  connection/reconnect; exposed the lifecycle future to the shutdown coordinator
  immediately after `start` invocation; and made the bounded app-status
  preparation concurrent with session startup so its 35-second deadline cannot
  gate relay readiness.
- **2026-07-26 — Plan delivery:** Opened plan PR
  [#580](https://github.com/sesori-ai/sesori_apps_monorepo/pull/580) from the
  dedicated `bridge-setup-ux-assessment` branch.
- **2026-07-26 — Architecture review corrections:** Applied all four
  `aristotle-plan-review` findings without claiming approval of the revised
  plan: moved prompt rendering from `AppClientOnboardingService` to a private
  runner method; made one internally observed lifecycle future own startup,
  serving, partial-start cleanup, and teardown; fixed readiness at the
  non-awaited first `StreamIterator.moveNext()` invocation; and added removal of
  the now-unused status `wait` parameter/query branch to Step 2.
- **2026-07-26 — Initial split:** Chose a two-PR sequence so the required
  `OrchestratorSession` start/wait lifecycle refactor is independently
  reviewable and the second PR contains only the user-visible relay-first
  onboarding change.
- **2026-07-26 — Line budget:** Fixed a 1,500 changed-line maximum per
  implementation PR, with mandatory reassessment at a 1,300-line projection.
