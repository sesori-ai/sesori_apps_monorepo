# OpenCode v2 Tracker

## Series

- Slug: `opencode-v2`
- Base: `main` at `fed841c2f9`
- Current step: 6.a (PR 8/13) — event projection, local on `sesori/opencode-v2-step-6a-event-projection`.
- Merged: Step 1 [#1709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1709),
  Step 2 [#1711](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1711),
  Step 3 [#1716](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1716),
  Step 4 [#1720](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1720),
  Step 5.a [#1733](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1733),
  Step 5.b [#1743](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1743),
  Step 5.c [#1748](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1748).
- One-step-ahead successor: Step 6.b activity/service (PR 9/13); do not start before Step 6.a is in PR.
- Takeover: continue from `aqua-hummingbird`; preserve the existing published Step 2/3 history.
- Architecture review: first pass rejected 9 layering points; all applied (see PLAN.md Status)

## Steps

| Step | Complexity | Changed-line ceiling |
|---|---|---:|
| 1. Raise plan | 🌱 | 400 |
| 2. Detect v2 and refuse it honestly | 🌿 | 800 (557 authored + 170 generated at review) |
| 3. Generate v2 models | ⚙️ | 1,500 authored + generated |
| 4. v2 API and event stream | ⚙️ | 1,200 authored + generated |
| 5.a. v2 catalog normalization (PR 5/13) | ⚙️ | 1,000 total, including generated output |
| 5.b. v2 transcript mapping (PR 6/13) | 🚧 | 1,200 total, including generated output |
| 5.c. v2 repository integration (PR 7/13) | 🚧 | 1,200 |
| 6.a. v2 live-event projection (PR 8/13) | 🚧 | 1,400 including generated output |
| 6.b. v2 activity and service integration (PR 9/13) | 🚧 | 1,200 |
| 7. v2 writes and activation (PR 10/13) | 🚧 | 1,500 |
| 8. Managed runtime on v2 (PR 11/13) | 🌿 | 500 |
| 9. Reconcile docs (PR 12/13) | 🌱 | 400 |
| 10. Run coverage and retire (PR 13/13) | 🌱 | 300 |

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
  Fourteen transcript tests, full code generation and owning-package analysis pass.
  Architecture review approved `93b2ce2` with no findings (826 authored + 97 generated reviewed lines).
- #1743 review fixes preserve the 500-Unicode-scalar output limit and aggregate budget-overflow diagnostics
  once per attachment collection. Existing budget fixtures now emit four warnings instead of six.
  Empty-title/command, empty-output and empty-image fallbacks were declined under the repository's
  low-damage/producer-evidence policy; no internal missing-data sentinel is introduced by these projections.
  A Dart 3.13.4 probe disproved the data-URL finding: `UriData.contentText` preserves Base64.
- Duplicate option-label machinery was declined without a concrete producer: the pinned question tool maps
  both native value and label from the same option label. Revisit if a real distinct-value collision is demonstrated.
- Step 7 must use synthetic-message descriptions for user-visible compaction arguments rather than expose
  bridge-authored model guidance. Form answers must reuse the visible field order and convert labels to
  native option values; external fields and conditional rendering remain the accepted D7 gap.

## Step 5.c Evidence And Handoff

- #1743 merged with accepted head `b9fa631`; CI passed 21/21 and the current-head Codex review had no new findings.
  Its final scope was 860 authored + 97 generated lines. Step 5.c starts from updated `main` at `99dbc2aa98`.
- `OpenCodeV2Repository` composes the existing API/catalog/transcript mappers with three final dependencies and
  no runtime cache, tracker, timer, transport or persistence owner. V1 and the v2 startup refusal are unchanged.
- Native root paging uses `parentID=null` plus optional native `project` ID; directory and project scope are not
  mixed. Project IDs remain canonical paths while opened worktree directories and session locations remain distinct.
- The repository preserves native defaults, resolves explicit display-name selections before writes, exposes global
  active IDs and retains directory-scoped native input constraints. History failures propagate without empty fallback.
- Twenty-eight focused repository/API cases and owning-package analysis pass.
  Architecture review approved `7f4977e` with no findings (866 authored lines; no generated churn).
  No generated source changed, so generation was not rerun. Evidence is fixture/fake/HTTP-boundary only.
- Step 7 must verify parent-linked creation: plain native creation has no parent field, while fork/import routes
  exist. Inspect their semantics before satisfying `parentSessionId`; never silently create an unrelated root.

## Step 6 Evidence And Handoff

- #1748 merged at accepted head `065171a`, with CI 21/21 and 867 authored changed lines. The request to combine
  the repository with its later consumer was declined against the explicitly approved inactive, review-sized sequence.
- Step 6.a starts from `main` at `4008c597dc`. Step 6 is split before implementation to keep stateless event projection
  and the stateful activity/refresh owner independently reviewable; the series now has 13 PRs.
- Native durable projections commit before SSE publication. Use single-message reads for tool/assistant snapshots and
  native newest-first, type-filtered reads for compaction and terminal assistant state. This avoids a transcript cache.
- Native cursor requests now omit `order` after the first page, retaining directory/parent/project filters.
  Inbox delivery, not enqueue, projects the user/synthetic transcript row. Native message lookup distinguishes
  genuinely absent control projections from transport failures; ordinary history failures still propagate.
- The 2.0.11 source also supports single-message reads, newest-by-type filtering and all four interrupt reasons.
  Shutdown preserves the native execution claim, so it does not emit a false idle transition.
- Initial verification passed 61 focused API/repository/event-mapper/parser/model cases and package analysis.
  V2 REST/SSE regeneration completed (30 selected operations, 41 event variants); unfiltered build_runner wrote
  no changed output. Evidence remains source/fixture/fake-HTTP, not native turns.
- First architecture review rejected `42db015` only for repository access to the raw transport error.
  Single-message 404 translation now belongs to the API; the repository consumes a nullable native DTO.
  Other errors propagate unchanged. All 36 affected API/repository cases pass, including two new HTTP-boundary
  cases, and package analysis passes. Unchanged mapper/parser/model suites and generation were not repeated.
  Second architecture review is pending.
- Event projection contains no mutable state. Native readback supplies tool context and compaction identity;
  targeted tool/assistant updates never replay unrelated snapshot text ahead of queued deltas.
- The event slice ceiling is revised from 1,200 to 1,400 after measuring approximately 1,100 authored plus 202
  generated lines. Keep generated output with the six new event definitions; activity/service remains a separate PR.

GitHub remains authoritative for live PR state. The checkpoint above records the series handoff; update it when
advancing to the next PR. Generated-model churn is reported separately from authored changes.
