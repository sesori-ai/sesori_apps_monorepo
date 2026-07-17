# Bridge App Onboarding: Tracker

## Plan State

- **Status:** Finalized by user-authorized one-review/fix process — plan PR merged (branch-relative optimistic state)
- **Implementation base:** `main`
- **Plan slug:** `bridge-app-onboarding`
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/490
- **Repositories:** `sesori-ai/sesori_apps_monorepo`, `sesori-ai/sesori_auth_server`

## Current Pointer

- **Stage:** S01 — App Registration Checkpoint
- **Wave:** W02
- **Next action:** After S01-W01-P01 merges and deploys, reconcile its Git/PR facts, pin the current monorepo `main` baseline for S01/W02, and implement S01-W02-P01.

## Plan Review

- **Verdict:** Final by explicit user waiver — one full review completed and its two findings corrected; no further plan re-review
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-17
- **Reviewed commit:** review covered the uncommitted draft after `2d2e07adcf2e4d03ee46404ec268e0d1d3e5ebfd`; its formatter-contract and logout-graph findings are corrected in the final working tree without re-review by explicit user direction; external auth baseline `b17a6e760b0c70c3dc3d1cd456ff93d814c75453`

## Wave Baselines

| Stage | Wave | Repository | Base | Pinned SHA | Drift Decision |
|---|---|---|---|---|---|
| S01 | W01 | `sesori-ai/sesori_auth_server` | `master` | `b17a6e760b0c70c3dc3d1cd456ff93d814c75453` | No drift: current `master` matches the latest audited tip. |
| S01 | W02 | `sesori-ai/sesori_apps_monorepo` | `main` | `4a156a78b3bf8572c280ce859b3b1370300a8105` | Proceed: catalog-import and database-backed catalog changes overlap runtime composition but preserve the planned runner/session ownership; adapt W02 to current APIs. |

Workers add one authoritative row for each started stage/wave/repository/base
pair after drift assessment and before branch creation.

## PR Steps

| Done | ID | Stage | Wave | PR | Branch | Notes |
|---|---|---|---|---|---|---|
| [x] | S01-W01-P01 | S01 | W01 | https://github.com/sesori-ai/sesori_auth_server/pull/44 | `plan/bridge-app-onboarding/s01-w01-p01-app-client-presence-endpoint` | Delivers the auth-server immediate/long-poll current app-registration endpoint and durable post-upsert wake. Format, lint, build, 422 tests (1 skipped), circular-dependency check, and implementation review passed. |
| [ ] | S01-W02-P01 | S01 | W02 | — | `plan/bridge-app-onboarding/s01-w02-p01-interactive-app-onboarding` | Add standalone bridge checkpoint, async terminal ownership, retry/cancellation, and bounded QR output. |

## Manual Checkpoints

| User | Worker | ID | Check | Evidence |
|---|---|---|---|---|
| [ ] | [ ] | S01-W02-M01 | Scan and exercise terminal app onboarding across representative terminal capabilities | — |

## Blockers and Staleness

- No implementation blocker is known.
- The auth-server endpoint must merge and deploy before bridge release. The user
  explicitly authorized W02 implementation to overlap the still-open auth PR
  because the implementations are in separate repositories; release ordering
  remains auth server first.
- Latest audited tips: monorepo `main`
  `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0`
  (2026-07-17T06:57:01Z); auth-server `master`
  `b17a6e760b0c70c3dc3d1cd456ff93d814c75453`
  (2026-07-16T14:14:09Z). Each worker assesses and pins current drift.
- The independent active `session-pull-request-monitoring` plan may proceed; a
  worker stops and requests stale-plan re-review only if drift changes this
  plan's touched paths, contracts, architecture, or product intent.

## Findings and Plan Deltas

- **2026-07-17 — User-authorized wave overlap:** The user explicitly directed
  S01-W02-P01 to begin before S01-W01-P01 merges because the implementations are
  in separate repositories. This overrides only the implementation-start merge
  barrier; auth-server merge/deploy still precedes bridge release. Current
  monorepo `main` at `4a156a78b3bf8572c280ce859b3b1370300a8105`
  includes database-backed plugin catalog work that touches runtime composition
  without changing the planned process-startup/session ownership boundary.
- **2026-07-17 — Review-loop waiver and final corrections:** The user directed
  exactly one full plan review plus one finite fix pass, with no further plan
  re-review. Corrected the formatter contract to accept only repository-produced
  `TerminalRenderingCapabilities`, and made logout executable end to end:
  composition performs one typed token-repository read, conditionally constructs
  token/registration services, injects migration/repository/optional registration
  into the runner, and owns exact disposal.
- **2026-07-17 — Fourth plan-PR architecture correction:** Mapped the server's
  initial-read deadline through a service-local failure to route-owned 500;
  inserted `TokenRepository`/`BridgeIdRepository` so services no longer consume
  persistence APIs; moved terminal mode/capability mapping wholly into
  `TerminalPromptRepository`; and added shared Freezed email-login/refresh
  request DTOs so consolidated auth contains no inline request maps. At the
  user's direction, composition now aligns with the active desktop and parallel-
  plugin plans: `BridgeRuntimeRunner` remains process-startup composer and the
  existing `Orchestrator` remains post-start session composer under an exact
  B-B5 waiver; the proposed `BridgeStartupOrchestrator` is removed.
- **2026-07-17 — Locked architecture exception:** The user explicitly retained
  long polling and approved both it and existing authentication request/response
  as narrow exceptions to the push-based default; SSE and generic polling
  abstractions remain out of scope.
- **2026-07-17 — Third plan-PR review hardening:** Prevented unconfirmed absence
  when the server's initial read misses its deadline, required detachable auth
  cancellation listeners, preserved initial-silent-check input, and defined the
  cross-repository tracker handoff through the remote tracking branch.
- **2026-07-17 — Second plan-PR review hardening:** Preserved the shipped
  post-refresh token-file corruption repair while retaining cleared-file logout
  safety, and made secret reads discard/re-request any line queued before echo
  is disabled.
- **2026-07-17 — Plan-PR review hardening:** Made the auth wait deadline absolute
  from before its initial read, required explicit `forceRefresh` at every token
  caller, replaced lossy stdin broadcast handoff with FIFO pending-line
  preservation, and restricted QR rendering to polarity-safe ANSI+Unicode with
  URL-only fallback.
- **2026-07-17 — Plan delivery:** Opened plan-only PR
  https://github.com/sesori-ai/sesori_apps_monorepo/pull/490 against selected
  implementation base `main`; tracker state is optimistically post-merge on the
  plan branch.
- **2026-07-17 — Full-plan approval:** `aristotle-plan-review` approved the
  complete two-repository plan after all architecture, lifecycle, compatibility,
  command, wave, and tracker corrections; no violations remain.
- **2026-07-17 — Review hardening (later revised):** Consolidated Sesori auth
  HTTP under one provider API, renamed the standalone owner to `TokenService`,
  defined typed cancellable token access across both authorities, moved terminal/
  auth/onboarding classes to root layers, kept auth token deletion out of the
  waiter service, and injected logout registration directly. The later fourth-
  round delta supersedes this draft's direct-storage and startup-composer shape.
- **2026-07-17 — Approved design:** The user approved standalone-interactive-only
  onboarding; current token existence across all app platforms; silent existing
  registration; success feedback; `s`/`skip` + Enter; no persisted skip; exact
  app URL; bounded terminal QR; server long polling; fixed 60-second transient
  retry; indefinite interactive waiting; permanent fail-open compatibility;
  unified asynchronous terminal input; and no analytics.
- **2026-07-17 — Baseline audit:** Selected monorepo `main` rather than invocation
  branch `bridge-onboarding-optimization`; independently audited auth-server
  `master`. Current code has durable app tokens and OAuth waiter precedents but
  no current-registration endpoint or bridge checkpoint.
