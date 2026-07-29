# Multi-Plugin Release Preparation: Tracker

## Current State

- **Implementation base:** `origin/main` at `9da014e2`
- **Series state:** Step 1/6 plan PR is being raised from
  `multi-plugin-release-prep`
- **Current step:** Step 1/6 — durable plan and tracker
- **Next action:** review and merge the plan PR, then start Step 2/6 from updated
  `origin/main`

## Delivery

| Done | Step | Branch | PR state |
|---|---|---|---|
| [ ] | Step 1/6 — plan multi-plugin release preparation | `multi-plugin-release-prep` | Plan PR pending |
| [ ] | Step 2/6 — type Codex session-option discovery | `multi-plugin-release-prep-codex-options` | Blocked on Step 1 merge |
| [ ] | Step 3/6 — aggregate scoped plugin options | `multi-plugin-release-prep-plugin-options` | Blocked on Step 2 merge |
| [ ] | Step 4/6 — durable bridge cache and aggregate route | `multi-plugin-release-prep-bridge-cache` | Blocked on Step 3 merge |
| [ ] | Step 5/6 — cached New Session client flow | `multi-plugin-release-prep-client-options` | Blocked on Step 4 merge |
| [ ] | Step 6/6 — consolidated Harnesses settings | `multi-plugin-release-prep-harness-settings` | Blocked on Step 5 merge |

## Locked Decisions

- One endpoint: `POST /session/options`; `refresh=true` is the only activating
  aggregate read.
- OpenCode and Codex cache per project. Cursor caches once per plugin. Codex
  stays project-aware because defaults and skills depend on project context.
- Cache-only miss is explicit unavailable, not an empty successful catalog.
- Legacy option routes stay unchanged. New-client/old-bridge live loading occurs
  only after explicit Refresh.
- The bridge is the durable cache authority; no new client persistence/cache is
  introduced.
- Plugin facades delegate aggregate behavior to plugin services. Codex transport
  parsing is typed; ACP model/provider state belongs to a tracker, not a mapper.
- `SessionOptionsService` owns scope, retention, completeness, coalescing, and
  CAS retry policy. The repository owns mechanical capture/persistence and
  runtime generation fencing.
- Harnesses settings ends as one screen and one screen-owned management cubit,
  using Prego sheets and setup/capability-aware visibility.

## Exact PR Titles

1. `[multi-plugin-release-prep] docs: plan multi-plugin release preparation [step 1/6]`
2. `[multi-plugin-release-prep] refactor(codex): type session option discovery [step 2/6]`
3. `[multi-plugin-release-prep] feat(bridge): aggregate scoped plugin options [step 3/6]`
4. `[multi-plugin-release-prep] feat(bridge): cache scoped session options [step 4/6]`
5. `[multi-plugin-release-prep] feat(client): consume cached session options [step 5/6]`
6. `[multi-plugin-release-prep] refactor(app): consolidate Harness settings [step 6/6]`

## Verification Log

- Step 1/6: pending documentation validation and PR creation.
