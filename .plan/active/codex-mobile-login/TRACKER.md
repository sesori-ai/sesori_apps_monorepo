# Mobile Codex Login: Tracker

## Current State

- **Plan slug:** `codex-mobile-login`
- **Series state:** Step 1 PR open
- **Current step:** 1/8
- **Implementation base:** `origin/main` at `3708d348`
- **Plan PR:** [#824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824)
- **Current PR:** [#824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824)
- **Next action:** Monitor Step 1 review/CI and begin Step 2 locally

## Plan Review

- **Verdict:** Initial draft rejected with two actionable findings; both applied
  directly; corrected draft intentionally not re-reviewed merely for approval
- **Reviewer:** `architecture-plan-review`
- **Reviewed scope:** Proposed mobile Codex login architecture across plugin
  interface, Codex plugin, bridge app, shared contracts, client core, and mobile
  presentation
- **Applied findings:** Codex authentication now has explicit Client, API,
  Repository, and Service ownership; terminal shared progress is a sealed model
  with failure-only message data

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [ ] | 1/8 | `🌱 [codex-mobile-login] docs: plan mobile Codex login [step 1/8]` | 450-850 | [PR #824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824) open |
| [ ] | 2/8 | `⚙️ [codex-mobile-login] refactor(codex): prepare authentication primitives [step 2/8]` | 850-1,400 | Pending |
| [ ] | 3/8 | `🚧 [codex-mobile-login] feat(codex): implement device authentication [step 3/8]` | 850-1,450 | Pending |
| [ ] | 4/8 | `⚙️ [codex-mobile-login] feat(protocol): describe harness authentication [step 4/8]` | 650-1,200 | Pending |
| [ ] | 5/8 | `🚧 [codex-mobile-login] feat(bridge): expose harness authentication [step 5/8]` | 950-1,500 | Pending |
| [ ] | 6/8 | `🚧 [codex-mobile-login] feat(client): orchestrate harness authentication [step 6/8]` | 900-1,500 | Pending |
| [ ] | 7/8 | `⚙️ [codex-mobile-login] feat(app): add mobile Codex login [step 7/8]` | 750-1,350 | Pending |
| [ ] | 8/8 | `🌱 [codex-mobile-login] docs: retire mobile Codex login plan [step 8/8]` | 50-200 | Pending |

## Locked Decisions

- V1 supports login only for authentication-required Codex setup.
- Device authorization is owned and completed by Codex on the bridge machine.
- Sesori transports only the verification URL, user code, and sanitized state.
- Backend-specific authentication remains inside each concrete plugin.
- One optional backend-neutral descriptor capability is the only shared plugin
  seam; no generic OAuth framework is introduced.
- One active operation per plugin is start-or-join across retries and surfaces.
- Setup reinspection, not browser or App Server completion alone, determines
  success and routability.
- The system browser opens only after explicit user action; sheet dismissal does
  not cancel.
- No tokens, credential files, account identifiers, challenge data in logs, or
  authentication analytics are allowed.
- Logout, account switching, API-key/token entry, mobile callbacks, and other
  harness implementations are excluded.

## Verification Log

- Step 1: `git diff --check` passes. The two plan documents add 736 lines,
  within the 450-850 target. No Dart/Flutter suites were run because this step
  changes documentation only. Committed as `e4213ff2`, pushed, and opened as
  [PR #824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824).

## Findings And Plan Deltas

- **2026-08-11 - Product scope:** The user selected login-only Codex v1 and
  explicitly deferred logout and account switching.
- **2026-08-11 - Upstream protocol:** Codex App Server device authentication
  exists from `0.118.0`; current Sesori minimum `0.139.0` and managed `0.146.0`
  require no version change.
- **2026-08-11 - Cross-device flow:** Normal Codex browser login is excluded
  because its callback targets localhost on the bridge machine; device code is
  the supported headless/cross-device path.
- **2026-08-11 - Plugin boundary:** Plugin implementations remain concrete and
  independent; the shared contract carries capability, challenge, and progress
  only.
- **2026-08-11 - Architecture review:** Added explicit Codex Client/API/
  Repository/Service layers and changed terminal progress to sealed variants.
- **2026-08-11 - Cleanup:** Reuse one Codex runtime resolver and replace
  local-terminal-only setup guidance; retain login-status inspection and
  compatibility behavior.
