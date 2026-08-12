# Mobile Codex Login: Tracker

## Current State

- **Plan slug:** `codex-mobile-login`
- **Series state:** Steps 1-2 merged; Step 3 PR open
- **Current step:** 3/8
- **Implementation base:** Step 2 merge commit `67310433`
- **Plan PR:** [#824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824)
- **Current PR:** [#833](https://github.com/sesori-ai/sesori_apps_monorepo/pull/833)
- **Next action:** Monitor Step 3 review/CI and begin Step 4 locally

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
| [x] | 1/8 | `🌱 [codex-mobile-login] docs: plan mobile Codex login [step 1/8]` | 450-850 | [PR #824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824) merged |
| [x] | 2/8 | `⚙️ [codex-mobile-login] refactor(codex): prepare authentication primitives [step 2/8]` | 850-1,400 | [PR #827](https://github.com/sesori-ai/sesori_apps_monorepo/pull/827) merged |
| [ ] | 3/8 | `🚧 [codex-mobile-login] feat(codex): implement device authentication [step 3/8]` | 850-1,450 | [PR #833](https://github.com/sesori-ai/sesori_apps_monorepo/pull/833) open |
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

- Step 1: `git diff --check origin/main...HEAD` passes, and
  `git diff --numstat origin/main...HEAD` reports 739 additions and 0 deletions
  across the two plan documents, within the 450-850 target. No Dart/Flutter
  suites were run because this step changes documentation only. Committed as
  `e4213ff2`, pushed, and opened as
  [PR #824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824).
- Step 2: `dart test` passes all 348 Codex plugin tests. Focused runtime,
  setup, stdio transport, and typed account API tests pass, and
  `dart analyze --fatal-infos` reports no issues.
  `git diff --check origin/main...HEAD` passes, and
  `git diff --numstat origin/main...HEAD` reports 2,478 additions and 169 deletions.
  The required architecture implementation review could not run because the
  review sub-agent failed twice before reading code with an internal task-store
  schema error (`no such column: replacement_seq`). Committed as `3d71e4cf`,
  rebased onto `origin/main`, pushed, and opened as
  [PR #827](https://github.com/sesori-ai/sesori_apps_monorepo/pull/827).
- Step 3: `dart test` passes all 152 plugin-interface tests and all 357 Codex
  plugin tests. `dart analyze --fatal-infos` reports no issues in both packages,
  and `git diff --check` passes. The required architecture implementation
  review could not run because the review sub-agent failed before reading code
  with the internal task-store schema error `no such column: replacement_seq`.
  Committed as `36ec1eca`, pushed, and opened as
  [PR #833](https://github.com/sesori-ai/sesori_apps_monorepo/pull/833).

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
- **2026-08-11 - Cleanup:** Reuse one Codex runtime selection service and replace
  local-terminal-only setup guidance; retain login-status inspection and
  compatibility behavior.
- **2026-08-11 - Step 2 started:** Created local branch
  `codex-mobile-login-primitives` from the Step 1 branch. Confirmed the runtime
  selection service must preserve explicit/PATH/desktop/managed precedence and
  setup failure classifications; the new stdio client will be a second
  transport behind the typed Codex App Server API rather than changing the
  normal WebSocket runtime.
- **2026-08-11 - Step 2 implementation:** Added one shared executable selection
  decision for setup/startup/authentication, a secret-safe stdio JSONL App
  Server transport with bounded child cleanup, and typed account start/cancel/
  completion API models. Existing WebSocket generation behavior remains
  unchanged and no bridge or client capability is exposed yet.
- **2026-08-11 - Step 3 started:** Created local branch
  `codex-mobile-login-device-authentication` from the Step 2 PR branch. It
  remains local until Step 2 merges.
- **2026-08-12 - Step 3 implementation:** Added the optional descriptor
  capability and safe sealed events, then composed Codex Client/API/Repository/
  Service ownership with private login-ID correlation, HTTPS validation,
  abort-driven upstream cancellation, sanitized remote failures, and awaited
  child cleanup. No route or client capability is exposed yet.
