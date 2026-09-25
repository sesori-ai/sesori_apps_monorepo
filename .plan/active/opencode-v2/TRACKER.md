# OpenCode v2 Tracker

## Series

- Slug: `opencode-v2`
- Base: `main` at `fed841c2f9`
- Current step: 4/10 — v2 API and event transport implemented on `sesori/opencode-v2-step-4`.
- Merged: Step 1 [#1709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1709),
  Step 2 [#1711](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1711),
  Step 3 [#1716](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1716).
- One-step-ahead successor: Step 5 read mapping and repository; keep local until Step 4 merges.
- Takeover: continue from `aqua-hummingbird`; preserve the existing published Step 2/3 history.
- Architecture review: first pass rejected 9 layering points; all applied (see PLAN.md Status)

## Steps

| Step | Complexity | Changed-line ceiling |
|---|---|---:|
| 1. Raise plan | 🌱 | 400 |
| 2. Detect v2 and refuse it honestly | 🌿 | 800 (557 authored + 170 generated at review) |
| 3. Generate v2 models | ⚙️ | 1,500 authored + generated |
| 4. v2 API and event stream | ⚙️ | 1,200 authored + generated |
| 5. v2 read mapping and repository | 🚧 | 1,400 |
| 6. v2 live events, activity and service | 🚧 | 1,400 |
| 7. v2 writes and activation | 🚧 | 1,500 |
| 8. Managed runtime on v2 | 🌿 | 500 |
| 9. Reconcile docs | 🌱 | 400 |
| 10. Run coverage and retire | 🌱 | 300 |

## Step 3 Evidence And Handoff

- Generated from OpenCode `v2.0.16` (`3a103fe0aff726a4edc7492f03f7b88195d9e4c9`):
  29 selected REST operations, 106 model files and 35 event variants. No v2 adapter is active yet.
- Eleven v2 and twenty v1 model decode/round-trip tests pass; owning-package analyzer is clean.
  Architecture implementation review approved. REST and SSE outputs are generated from their pinned sources.
- Review corrections preserve free-form compaction object payloads and unknown permission-source variants,
  and keep required server/installation versions non-nullable. Legacy v1 session version omission remains
  supported; regeneration changes only the three non-session v1 version fields alongside the v2 fixes.
- Churn is approximately 1,100 authored plus 10,700 generated lines. The generated output remains with its
  source as one coherent code-generation change; there is no runtime behavior or database change.
- Step 6 must add live user-message events (`session.inbox.*` / `session.synthetic`) when mapping needs them.
  Interrupt/compaction reasons are not yet in the event manifest. Number/integer form bounds currently retain
  OpenCode's number-or-special-string union as `Object?`; Step 7 must validate these at its boundary rather than
  assuming all values are finite numbers. These are implementation handoffs, not unsupported product claims.

## Step 4 Evidence And Handoff

- `OpenCodeV2Api` implements all 29 selected operations through the existing raw HTTP client: typed request
  bodies, typed data envelopes and keyed active sessions, location queries, and complete cursor pagination.
- Event envelopes are generated from the v2 event manifest. The parser preserves identity/time/location,
  dispatches nested data, and logs/drops malformed or unsupported frames without presenting transcript data.
- SSE transport accepts an explicit path. The active v1 plugin still supplies `/global/event`; v2 `/api/event`
  is exercised only by fixtures until Step 7 activation. Authentication and lifecycle ownership are unchanged.
- Architecture implementation review approved `167e627` with no findings.
- Focused v1/v2 model, HTTP and SSE suites pass (80 cases across seven suites); analyzer is clean.
  Two fixture corrections (required project active time and unbuffered HTTP streaming) were verified by
  rerunning the affected API/connection suites. Unchanged passing suites were not rerun.
- Full owning-package build_runner and v1/v2 REST/SSE generators ran. v1 generated output remains unchanged.
  About half the diff is generated boilerplate: 1,044 authored + 1,003 generated changed lines at review.
  The 1,003 generated lines stay with their source; the authored change is within the planned ceiling.
- Includes the valid post-merge #1716 finding: unconstrained compaction arrays now retain null elements,
  fixed in the generator and exercised both directly and through an API acknowledgement.
- No active v2 adapter, runtime target, database, shared wire contract, or user-visible behavior change.

GitHub remains authoritative for live PR state. The checkpoint above records the series handoff; update it when
advancing to the next PR. Generated-model churn is reported separately from authored changes.
