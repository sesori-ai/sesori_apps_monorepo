# OpenCode v2 Tracker

## Series

- Slug: `opencode-v2`
- Base: `main` at `fed841c2f9`
- Current step: 3/10 — generated v2 models verified for review on `opencode-v2-step-3`.
- Merged: Step 1 [#1709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1709),
  Step 2 [#1711](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1711).
- One-step-ahead successor: Step 4 API and event stream; keep local until Step 3 merges.
- Takeover: continue from `aqua-hummingbird`; preserve the existing published Step 2/3 history.
- Architecture review: first pass rejected 9 layering points; all applied (see PLAN.md Status)

## Steps

| Step | Complexity | Changed-line ceiling |
|---|---|---:|
| 1. Raise plan | 🌱 | 400 |
| 2. Detect v2 and refuse it honestly | 🌿 | 800 (557 authored + 170 generated at review) |
| 3. Generate v2 models | ⚙️ | 1,500 authored + generated |
| 4. v2 API and event stream | ⚙️ | 1,200 |
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
- Step 4 must decode response envelopes and the active-session keyed map through typed boundary models;
  the allowlist currently names payload DTOs rather than every inline response envelope.
- Step 6 must add live user-message events (`session.inbox.*` / `session.synthetic`) when mapping needs them.
  Interrupt/compaction reasons are not yet in the event manifest. Number/integer form bounds currently retain
  OpenCode's number-or-special-string union as `Object?`; Step 7 must validate these at its boundary rather than
  assuming all values are finite numbers. These are implementation handoffs, not unsupported product claims.

GitHub remains authoritative for live PR state. The checkpoint above records the series handoff; update it when
advancing to the next PR. Generated-model churn is reported separately from authored changes.
