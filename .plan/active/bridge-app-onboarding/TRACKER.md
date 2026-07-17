# Bridge App Onboarding: Tracker

## Plan State

- **Status:** Approved — ready for delivery
- **Implementation base:** `main`
- **Plan slug:** `bridge-app-onboarding`
- **Plan PR:** —
- **Repositories:** `sesori-ai/sesori_apps_monorepo`, `sesori-ai/sesori_auth_server`

## Current Pointer

- **Stage:** S01 — App Registration Checkpoint
- **Wave:** W01
- **Next action:** Choose plan delivery. After delivery, use `sesori-plan-worker` with slug `bridge-app-onboarding` to pin the current auth-server `master` baseline for S01/W01 and implement S01-W01-P01.

## Plan Review

- **Verdict:** Approved — no architectural violations
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-17
- **Reviewed commit:** `c75b597ddb965f02031b42a6f6d27feb11827aba` plus the complete uncommitted final architecture corrections in `.plan/active/bridge-app-onboarding/`; external auth baseline `b17a6e760b0c70c3dc3d1cd456ff93d814c75453`

## Wave Baselines

| Stage | Wave | Repository | Base | Pinned SHA | Drift Decision |
|---|---|---|---|---|---|

No implementation wave has started. Workers add one authoritative row for each
started stage/wave/repository/base pair after drift assessment and before branch
creation.

## PR Steps

| Done | ID | Stage | Wave | PR | Branch | Notes |
|---|---|---|---|---|---|---|
| [ ] | S01-W01-P01 | S01 | W01 | — | `plan/bridge-app-onboarding/s01-w01-p01-app-client-presence-endpoint` | Add auth-server immediate/long-poll current app-registration endpoint and durable post-upsert wake. |
| [ ] | S01-W02-P01 | S01 | W02 | — | `plan/bridge-app-onboarding/s01-w02-p01-interactive-app-onboarding` | Add standalone bridge checkpoint, async terminal ownership, retry/cancellation, and bounded QR output. |

## Manual Checkpoints

| User | Worker | ID | Check | Evidence |
|---|---|---|---|---|
| [ ] | [ ] | S01-W02-M01 | Scan and exercise terminal app onboarding across representative terminal capabilities | — |

## Blockers and Staleness

- No implementation blocker is known.
- The auth-server endpoint must merge and deploy before bridge release. Wave W02
  does not start until S01-W01-P01 merges.
- Latest audited tips: monorepo `main`
  `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0`
  (2026-07-17T06:57:01Z); auth-server `master`
  `b17a6e760b0c70c3dc3d1cd456ff93d814c75453`
  (2026-07-16T14:14:09Z). Each worker assesses and pins current drift.
- The independent active `session-pull-request-monitoring` plan may proceed; a
  worker stops and requests stale-plan re-review only if drift changes this
  plan's touched paths, contracts, architecture, or product intent.

## Findings and Plan Deltas

- **2026-07-17 — Full-plan approval:** `aristotle-plan-review` approved the
  complete two-repository plan after all architecture, lifecycle, compatibility,
  command, wave, and tracker corrections; no violations remain.
- **2026-07-17 — Review hardening:** Consolidated Sesori auth HTTP under one
  provider API; added direct `TokenStorage`, renamed the standalone owner to
  `TokenService`, defined typed cancellable token access across both authorities,
  moved terminal/auth/onboarding classes to correct root layers, kept auth token
  deletion out of the waiter service, injected logout registration directly,
  and made root `BridgeStartupOrchestrator` the sole startup/session composer
  while runner consumes only direct already-built collaborators.
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
