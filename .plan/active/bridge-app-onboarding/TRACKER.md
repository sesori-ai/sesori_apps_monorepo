# Bridge App Onboarding: Tracker

## Plan State

- **Status:** Reduced W02 plan approved; production implementation not started
- **Implementation base:** `main`
- **Plan slug:** `bridge-app-onboarding`
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/490
- **Repositories:** `sesori-ai/sesori_apps_monorepo`, `sesori-ai/sesori_auth_server`

## Current Pointer

- **Stage:** S01 — App Registration Checkpoint
- **Wave:** W02
- **Next action:** Await user confirmation before implementing the approved reduced W02 plan.

## Plan Review

- **Verdict:** Approved for the reduced plan after one suffix correction
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-17
- **Reviewed commit:** current uncommitted reduced-plan documents over pinned base `4a156a78b3bf8572c280ce859b3b1370300a8105`

## Wave Baselines

| Stage | Wave | Repository | Base | Pinned SHA | Drift Decision |
|---|---|---|---|---|---|
| S01 | W01 | `sesori-ai/sesori_auth_server` | `master` | `b17a6e760b0c70c3dc3d1cd456ff93d814c75453` | No drift: current `master` matches the latest audited tip. |
| S01 | W02 | `sesori-ai/sesori_apps_monorepo` | `main` | `4a156a78b3bf8572c280ce859b3b1370300a8105` | Proceed after reducing scope: current `main` remains the pinned implementation baseline. |

Workers add one authoritative row for each started stage/wave/repository/base
pair after drift assessment and before branch creation.

## PR Steps

| Done | ID | Stage | Wave | PR | Branch | Notes |
|---|---|---|---|---|---|---|
| [x] | S01-W01-P01 | S01 | W01 | https://github.com/sesori-ai/sesori_auth_server/pull/44 | `plan/bridge-app-onboarding/s01-w01-p01-app-client-presence-endpoint` | Delivers the auth-server immediate/long-poll current app-registration endpoint and durable post-upsert wake. Format, lint, build, 422 tests (1 skipped), circular-dependency check, and implementation review passed. |
| [ ] | S01-W02-P01 | S01 | W02 | — | existing `bridge-onboarding-plan` worktree branch | Add a bounded one-time-per-account checkpoint with no auth/token/terminal refactor. |

## Manual Checkpoints

| User | Worker | ID | Check | Evidence |
|---|---|---|---|---|
| [ ] | [ ] | S01-W02-M01 | Scan QR/URL output and exercise immediate/30-second same-account registration | — |

## Blockers and Staleness

- No implementation blocker is known.
- The auth-server endpoint must merge and deploy before bridge release. The user
  explicitly authorized W02 planning and implementation to overlap the still-open
  auth PR because the repositories are separate; release ordering remains auth
  server first.
- Latest audited tips: monorepo `main`
  `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0`
  (2026-07-17T06:57:01Z); auth-server `master`
  `b17a6e760b0c70c3dc3d1cd456ff93d814c75453`
  (2026-07-16T14:14:09Z). Each worker assesses and pins current drift.
- The independent active `session-pull-request-monitoring` plan may proceed; a
  worker stops and requests stale-plan re-review only if drift changes this
  plan's touched paths, contracts, architecture, or product intent.

## Findings and Plan Deltas

- **2026-07-17 — W02 implementation discarded for excessive scope:** The first
  W02 implementation followed an over-broad plan that combined onboarding with
  auth-provider consolidation, token-persistence layering, a token-owner rename,
  and global terminal migration. The user rejected that scope. All uncommitted
  W02 production and test changes were discarded; redesign must keep existing
  auth, token, persistence, and unrelated prompt architecture intact unless the
  onboarding behavior strictly requires a local change.
- **2026-07-17 — User-authorized wave overlap:** The user explicitly directed
  S01-W02-P01 to begin before S01-W01-P01 merges because the implementations are
  in separate repositories. This overrides only the implementation-start merge
  barrier; auth-server merge/deploy still precedes bridge release. Current
  monorepo `main` at `4a156a78b3bf8572c280ce859b3b1370300a8105`
  remains the pinned W02 baseline.
- **2026-07-17 — Reduced behavior selected:** The user selected one immediate
  check plus at most one 30-second server-held wait. The reduced design has no
  skip input, retry loop, token refresh, or asynchronous terminal ownership.
- **2026-07-17 — One-time account marker:** Once registration is confirmed, W02
  stores the existing JWT `userId` and skips every future check for that account.
  A different account checks normally; accepted CLI logout clears the marker.
- **2026-07-17 — Reduced-plan review correction:** Renamed the marker's dumb
  Layer-1 file boundary from `AppOnboardingStateApi` to
  `AppOnboardingStateStorage`; no broader design change was required.
- **2026-07-17 — Reduced-plan approval:** `aristotle-plan-review` approved the
  corrected bounded design with no auth/token/terminal refactor and no remaining
  architecture violations.
- **2026-07-17 — Plan delivery:** Opened plan-only PR
  https://github.com/sesori-ai/sesori_apps_monorepo/pull/490 against selected
  implementation base `main`; tracker state is optimistically post-merge on the
  plan branch. Its original W02 design is superseded by the reduced plan in this
  worktree; the auth-server W01 endpoint remains valid and unchanged.
- **2026-07-17 — Baseline audit:** Selected monorepo `main` rather than invocation
  branch `bridge-onboarding-optimization`; independently audited auth-server
  `master`. Current code has durable app tokens and OAuth waiter precedents but
  no current-registration endpoint or bridge checkpoint.
