# OpenCode v2 Tracker

## Series

- Slug: `opencode-v2`
- Base: `main` at `fed841c2f9`
- Current step: 5.b (PR 6/12) — transcript mapping, in review on `sesori/opencode-v2-step-5b-transcript`.
- Merged: Step 1 [#1709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1709),
  Step 2 [#1711](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1711),
  Step 3 [#1716](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1716),
  Step 4 [#1720](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1720),
  Step 5.a [#1733](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1733).
- One-step-ahead successor: Step 5.c repository integration (PR 7/12); do not start before Step 5.b is in PR.
- Takeover: continue from `aqua-hummingbird`; preserve the existing published Step 2/3 history.
- Architecture review: first pass rejected 9 layering points; all applied (see PLAN.md Status)

## Steps

| Step | Complexity | Changed-line ceiling |
|---|---|---:|
| 1. Raise plan | 🌱 | 400 |
| 2. Detect v2 and refuse it honestly | 🌿 | 800 (557 authored + 170 generated at review) |
| 3. Generate v2 models | ⚙️ | 1,500 authored + generated |
| 4. v2 API and event stream | ⚙️ | 1,200 authored + generated |
| 5.a. v2 catalog normalization (PR 5/12) | ⚙️ | 1,000 total, including generated output |
| 5.b. v2 transcript mapping (PR 6/12) | 🚧 | 1,200 total, including generated output |
| 5.c. v2 repository integration (PR 7/12) | 🚧 | 1,200 |
| 6. v2 live events, activity and service (PR 8/12) | 🚧 | 1,400 |
| 7. v2 writes and activation (PR 9/12) | 🚧 | 1,500 |
| 8. Managed runtime on v2 (PR 10/12) | 🌿 | 500 |
| 9. Reconcile docs (PR 11/12) | 🌱 | 400 |
| 10. Run coverage and retire (PR 12/12) | 🌱 | 300 |

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

## Step 5 Checkpoint

- #1733 now contains catalog/session/form projection and an immutable agent-name lookup only.
  Display names are exposed in agent selections and session defaults; native-ID resolution stays in the plugin.
  Project IDs remain canonical directories. No runtime path uses these foundations yet.
- The official macOS ARM64 2.0.16 npm archive matches its published SHA-512 integrity and carries
  Anomaly Innovations' Developer ID signature. It is retained under `.pi/opencode-v2-live/runtime/`.
- Native fixture capture succeeded after the user approved narrow read-only sandbox allowances for OS
  timezone data, notification-center shared memory and exact ancestor-directory entries. Real profiles,
  unrelated source contents and external networking stayed blocked. Earlier failed attempts were preserved.
- The 2.0.16 server produced project, location, session, agent and model/provider catalog responses under
  a fresh profile and synthetic project. The owned process was terminated and reaped. This is native REST
  shape evidence, not authenticated provider execution or native transcript/tool lifecycle evidence.
- Native fixture provenance stays with the catalog slice; form examples are source-derived.
  Seven catalog/form/identity tests, full code generation and owning-package analysis pass.
  Second architecture pass approved `f830e46`: 727 authored + 88 generated changed lines (815 total), catalog-only scope.
- #1733 merged with accepted head `ea53cc4`; CI passed 21/21 and the current-head Codex review had no new findings.
- Step 5.b restored the transcript mapper, typed tool-display DTOs/generated parts and tests from published
  checkpoint `ef5015416a`, retaining the accepted shell-classification fix without rewriting history.
- Assistant retry metadata now uses stable `<messageID>:retry` parts; agent-switch records use system-authored
  `<messageID>:0` agent parts. All transcript agent fields use the explicit immutable `V2AgentNames` value.
  Thirteen transcript tests, full code generation and owning-package analysis pass.
  Architecture review approved `93b2ce2` with no findings (826 authored + 97 generated reviewed lines).
  A Dart 3.13.4 probe disproved the data-URL finding: `UriData.contentText` preserves Base64.
- Duplicate option-label machinery was declined without a concrete producer: the pinned question tool maps
  both native value and label from the same option label. Revisit if a real distinct-value collision is demonstrated.
- Step 7 must use synthetic-message descriptions for user-visible compaction arguments rather than expose
  bridge-authored model guidance. Form answers must reuse the visible field order and convert labels to
  native option values; external fields and conditional rendering remain the accepted D7 gap.

GitHub remains authoritative for live PR state. The checkpoint above records the series handoff; update it when
advancing to the next PR. Generated-model churn is reported separately from authored changes.
