# All Harness Runtime Refresh — Tracker

## Current state

- **Series:** nine top-level steps; Steps 1–4 merged, Step 5 updates the five remaining targets.
- **Branch/base:** `all-harness-runtime-refresh-step-5` /
  `600d94fb49ed0889b53b73ce21273d18fdb52c5d`.
- **Delivered scope:** four Step 2 targets, 18 managed digests and focused
  fixtures; required Pi/Claude lifecycle evidence accepted after merge;
  Antigravity's exact `1.1.1` pair and actual production-validator verification;
  and localized Hermes discovery cleanup. No new capabilities, generated files,
  wire/database changes or product release were introduced.
- **Approved scope:** mechanical target refreshes, OMP Windows ARM64 mapping,
  and OMP-backed shared ACP multi-select questions. Floors remain unchanged;
  DeepSeek and unrelated upstream changes remain outside this series.
- **Latest merge:** PR #1460 shipped the Hermes cleanup fix on 2026-09-13 at
  `09:50:04Z` as `600d94fb49ed0889b53b73ce21273d18fdb52c5d`, with 16/16 checks,
  Cubic approval and both feedback threads resolved. The owner explicitly
  authorized proceeding without the pending Codex review for that PR only.
  That review waiver did not waive native checks; the merge left Hermes at
  `0.20.4`. The subsequent update-first direction below changes delivery timing.
- **Owner correction, 2026-09-13:** update every included harness. Missing tests,
  credentials or runners must become final-plan follow-ups, not old-version
  holds or repeated questions about whether to proceed. Only an exceptional
  concrete problem justifies a temporary hold with a specific resolution path;
  none is currently established for these updates.
- **Current branch:** Step 5 applies Codex `0.154.0`, Cursor
  `2026.09.10-fd3934a`, Hermes `0.21.2`, OMP `18.1.19` and Grok `1.0.30`.
  OMP's newer stable release superseded the audited `18.1.18`; eight fresh
  binary hashes match both publisher sources, with seven mapped in this step.
  All 121 focused cases and five owning analyzers pass; 12 Dart files format
  unchanged. The skill/reference and plan adopt the corrected delivery policy.
- **Next:** publish/review Step 5, then deliver the approved features. Group unresolved tests, feature
  questions and exact user help in Steps 8–9. Grok testing is authorized in
  principle, but credential provisioning need not precede its target update.
  No live credentials may be borrowed, and stopped Codex/Hermes probes are not
  reauthorized by this timing change. See [Step 5 verification](STEP-5-VERIFICATION.md),
  [Step 4 verification](STEP-4-VERIFICATION.md),
  [Step 3 verification](STEP-3-VERIFICATION.md),
  [Step 2 verification](STEP-2-VERIFICATION.md), and its
  [lifecycle follow-up](STEP-2-LIFECYCLE-VERIFICATION.md).

## Delivery ledger

| Done | Step | Exact PR title | Status |
|---|---|---|---|
| [x] | 1/9 | `🌱 [all-harness-runtime-refresh] docs: publish runtime refresh plan [step 1/9]` | PR #1453 merged as a644652e0c; no production changes |
| [x] | 2/9 | `🌿 [all-harness-runtime-refresh] runtime: refresh mechanical targets [step 2/9]` | PR #1455 merged as ba3264eab9; four targets verified including post-merge Pi/Claude follow-up; Codex/OMP deferred then, now updated in Step 5 |
| [x] | 3/9 | `🌿 [all-harness-runtime-refresh] runtime: validate Antigravity and Cursor exact builds [step 3/9]` | PR #1457 merged as d55b93c874; Antigravity verified/applied including actual production-validator gate; Cursor deferred then, now updated in Step 5 |
| [x] | 4/9 | `🌿 [all-harness-runtime-refresh] runtime(hermes): fix ephemeral catalog cleanup [step 4/9]` | PR #1460 merged as 600d94fb49; cleanup fix, 11 tests and analyzer pass; candidate native verification not accepted; target was unchanged at that merge |
| [ ] | 5/9 | `🌿 [all-harness-runtime-refresh] runtime: finish remaining target updates [step 5/9]` | Implemented: five targets, 17 mapped digests, 121 tests, five analyzers; publication/review pending; native/configured limits remain final follow-ups |
| [ ] | 6/9 | `⚙️ [all-harness-runtime-refresh] runtime(omp): add Windows arm64 asset [step 6/9]` | Approved eighth asset/hash/mapping/tests/docs; missing native runner becomes final follow-up |
| [ ] | 7/9 | `⚙️ [all-harness-runtime-refresh] acp: support OMP multi-select questions [step 7/9]` | Separate option/custom questions and owning tests/docs; missing live roundtrip becomes final follow-up |
| [ ] | 8/9 | `🌱 [all-harness-runtime-refresh] docs: reconcile runtime regression coverage [step 8/9]` | Reconcile evidence/docs and prepare one grouped test/question/user-help handoff |
| [ ] | 9/9 | `🌿 [all-harness-runtime-refresh] verify: record matrix and retire plan [step 9/9]` | Final matrix, remaining tests/issues and user-assisted checks; explicit acceptance before retirement |

## Harness status matrix

| Harness | Branch target | Floor/exact policy | Candidate | Status |
|---|---:|---|---:|---|
| OpenCode | `1.18.30` | `1.14.0` unchanged | `1.18.30` | Pass: six hashes, install, REST/SSE, read-only catalog, focused tests/analyzer |
| Antigravity | package `1.1.1`; server `agy_acp_server_1.1.1` | Exact package/server/ACP 1; no semantic floor | package `1.1.1`; server `agy_acp_server_1.1.1` | Pass: five hashes, macOS ARM64 install/actual production validator/initialize/cleanup, focused tests/analyzer |
| Codex | `0.154.0` | `0.139.0` unchanged | `0.154.0` | Updated in Step 5; six digests and 38 tests/analyzer pass. Retained install/transports passed; probe teardown remains unresolved |
| GitHub Copilot | `1.0.83` | `1.0.78` unchanged | `1.0.83` | Pass: six hashes, install, ACP initialize, focused tests/analyzer |
| Cursor | `2026.09.10-fd3934a` | date floor `2026.07.16` unchanged | `2026.09.10-fd3934a` | Updated in Step 5; four hashes, retained native setup and 26 tests/analyzer pass. Configured load/replay/model/mode remain unverified |
| Claude Code | `2.1.269` | `2.1.221` unchanged | `2.1.269` | Pass: CLI/SDK launch, native controlled-provider approval/replay/interrupt/reuse/cleanup plus production parsing/history mapping; tests/analyzer |
| Hermes Agent | `0.21.2` | `0.20.0` unchanged | `0.21.2` | Updated in Step 5; 18 descriptor tests/analyzer pass. Failed load and unaccepted native procedure/evidence remain final investigation items |
| Pi | `0.85.1` | `0.84.1` unchanged | `0.85.1` | Pass: six hashes/install/RPC, native production-plugin settlement/manual-compaction abort/ordering/reuse/cleanup; tests/analyzer |
| Oh My Pi | `18.1.19` | `17.2.13` unchanged | `18.1.19` | Updated in Step 5; seven mapped hashes plus reserved Windows ARM64 hash, 27 tests/analyzer pass. Earlier native observations were 18.1.18; current native/configured checks remain |
| Grok Build | `1.0.30` | `1.0.5` unchanged | stable channel `1.0.30` | Updated in Step 5; channel and 12 descriptor tests/analyzer pass. Native/authenticated coverage remains separate final follow-up |
| DeepSeek | Not assessed (excluded) | Outside this series | None | Explicitly excluded; historical baseline is not a current-target claim, and unrelated upstream changes are neither audited nor modified here |

## Approved and deferred decisions

- **Approved:** update every included stable target; preserve every floor and
  Antigravity exact-pair policy; add OMP Windows ARM64 and shared ACP array
  `items.anyOf` forms for OMP. Do not ask whether to hold routine updates.
- **Final follow-ups:** Cursor load/replay/model/mode, OMP configured lifecycle
  and cleanup, Hermes faithful load/cleanup and reported failure, Grok
  authenticated flow, Windows ARM64 native smoke and live multi-select proof.
  Missing access does not delay target adoption. Optional unapproved features
  remain separate; failed or unavailable checks are never counted as passing.
- **Temporary exceptions:** none established. A real severe regression must be
  fixed as update work or have a concrete temporary exception with evidence,
  responsible follow-up and exit condition; lack of a fixture alone cannot qualify.
- **Resolved policy:** Cursor official installer content may be self-hashed;
  no publisher checksum, signature, immutable release, or source-binary
  attestation gate is required. Grok `x.ai/...` source spelling normalizes to
  `_x.ai/...` wire names; no namespace blocker remains. Pi npm comparison uses
  `@earendil-works/pi-coding-agent`.
- **Analytics:** reuse existing authoritative question-answer instrumentation.
  Add no new event; add zero new persistent or in-memory coordination parts; no generated churn is expected.
- **Estimates:** approximately 200-450 authored lines for multi-select and
  40-100 for OMP Windows ARM64 mapping; refine against local implementation
  without widening scope.
- **Declined/deferred:** upstream optional models/providers, auth/login beyond
  named required probes, sub-agents, plan UX, shell-command claims,
  cancellation redesign, floor changes, and broad cleanup/refactors.

## Final verification follow-ups

Check status is independent of target adoption. Group these in Steps 8–9,
with the smallest reproduction, expected result and specific needed help.

| Check | Evidence still needed | Current evidence limit / help |
|---|---|---|
| Codex teardown | No surviving owned process or listener after a permitted probe | Existing controller failure; no further cleanup retry authorized |
| Cursor configured lifecycle/options | Isolated load/replay/model/mode | Configured fixture or user-assisted check needed |
| OMP current-target lifecycle | Complete 18.1.19 source/native follow-up; authenticate(agent), list/new/load, persisted cleanup | Configured fixture needed; earlier native observations are 18.1.18 only |
| Hermes configured lifecycle | Faithful isolated launch, actual persisted load/deletion | Attempted load failed; procedure/evidence not accepted; review before any execution |
| Grok authenticated seam | New/prompt/replay/model-selection/close | Testing authorized in principle; secure test credential and endpoint scope still needed |
| OMP Windows ARM64 | Native install/version/ACP smoke | Native ARM64 runner or user assistance; other hosts do not prove it |
| OMP ACP multi-select | Widget automation and live OMP/client array roundtrip, including omission/cancel and single choice | Implement/test locally first; arrange missing live fixture at the final stage |
| Managed-cache policy | Bounded mixed-build reproduction and decision on newer cached versions when an older bridge starts | Pre-existing pinned-first selection/non-pinned cleanup; shared policy change is outside these target updates |

## Verification log

Entries follow the series' evidence order. The later owner correction changes
verification timing, not the results recorded before it.

- Registry reconciled: 11 total, ten included, DeepSeek excluded.
- Architecture plan review on 2026-09-12 rejected four ownership gaps. Applied
  the ownership clarifications for plugin/shared reply flow, immutable field
  encoding, OMP live-versus-scratch form policy, and plugin-local Windows assets.
  PR review simplified grouping to one property/question so option/custom
  provenance stays unambiguous without wire changes; feature docs now land in
  their feature PRs, and the OMP asset reference uses durable discovery guidance.
  No scope expansion or new coordination state was needed; no re-review is claimed.
- Step 1 recovered the source audit and validated documentation only. Its
  metadata snapshot remains in `AUDIT.md`; it is not runtime execution evidence.
- Step 2 independently verified 18 adopted managed archives and current-host
  installer/identity/protocol checks for OpenCode/Copilot/Pi, plus Claude's
  direct-CLI/SDK checks. At that merge, Codex and OMP were left unpinned under
  the earlier policy despite accepted asset/install evidence. Step 5 now
  completes those updates; the failed cleanup observation remains in follow-up.
- A Copilot macOS ARM64 report transcription error was reconciled against raw
  metadata and a targeted byte rehash before applying its verified digest.
- Post-pin focused tests: OpenCode 160, Copilot 17, Pi 162, Claude 10; total 349
  passed. All four owning analyzers and formatting for nine Dart files passed
  with pinned Dart 3.13.3. Older compatible PATH fixtures and historical protocol
  observations remain unchanged.
- Review caught missing named Pi/Claude lifecycle evidence. The owner chose to
  complete it, not relax the plan. PR #1455 merged with those threads still
  open; the subsequent accepted checks verify Pi settlement/compaction abort
  through the production plugin, and Claude native approval/replay/interrupt
  with production parsing/history mapping. Controlled loopback providers only;
  real-provider behavior and deadline-expiry fault injection are not claimed.
- Step 3 recovered both completed native-lane reports after an independent
  parent-runner failure, without re-execution or an execution-mode fallback.
  Antigravity's five hashes/member sizes and Cursor's four hashes were reconciled
  against machine-readable records. Only Antigravity's verified exact pair was
  applied after the actual production-validator native follow-up passed.
  Other platforms remain natively untested; no authenticated or
  broader capability claim is added. See [Step 3 verification](STEP-3-VERIFICATION.md).
- The production-validator helper first failed before Dart `main()` due to cwd
  access. One same-protocol retry used an allowed cwd and an unchanged wrapper
  copy inside existing grants; it reached the production validator but returned
  `false` through `AntigravityRuntimeStorageFailed` during symbolic-link
  resolution. No candidate or ACP process started in either attempt. Both
  controllers reaped their helpers with no survivors; no sandbox permissions
  changed in those attempts. After owner approval, three exact metadata/existence
  literals repaired path resolution without additional file-content, write,
  execution, signal or network permissions. The actual production validator then
  returned `true` for the real `agy_acp_server_1.1.1` candidate; native exit `-15`,
  controller exit 0 in 1.434 seconds, no timeout and no surviving owned processes
  were observed. Original profiles/reports and dirty diffs remain preserved.
- Antigravity post-pin checks cover 68 distinct cases across nine files. Two
  initial descriptor failures identified historical `1.0.0` data reused as a
  current-runtime fake; separate synthetic current data fixed descriptor and
  authentication-composer fixtures without rewriting the historical capture.
  The affected 19 cases and owning analyzer passed; unchanged passing suites
  and native probes were not repeated.
- Step 4: six new API cases and five existing repository cases pass; owning
  analyzer passes. Two native attempts observed catalog cleanup/new/prompt/list
  but failed fresh load. Parent review rejected the claimed isolated pass because
  the wrapper bypassed CLI dispatch, inherited environment remained, permissions
  were broader than agreed, and setup was outside the deadline. Original profile
  DB/logs were reset before stop; latest JSON/report survive. A same-session
  cleanup-only follow-up verified the extra fixture exited and its listener was
  gone, without rerunning Hermes. See Step 4 verification for precise limits.
- Step 4 merge: PR #1460 merged on 2026-09-13 as `600d94fb49`; final CI 16/16,
  Cubic approval, no unresolved threads. The owner waived waiting for that PR's
  pending Codex review, not any native candidate or feature verification gate.
- Step 5 metadata: official `https://x.ai/cli/stable` returned HTTP 200 and
  `1.0.30` at `2026-09-13T09:57:32Z`. Raw body/headers/time are retained locally
  under `.dart_tool/runtime-refresh-validation/grok/step-5/`. This was public
  metadata retrieval only, not candidate download, execution or authentication.
- Owner policy correction on 2026-09-13 supersedes the historical pin-blocking
  decisions: deliver all included updates, fix real incompatibilities, and move
  unavailable tests/questions to final follow-up. No observed failure is erased
  and no sandbox, credential or evidence-integrity rule is relaxed.
- Step 5 implementation: 121 cases across 10 suites pass, all five owning
  analyzers pass and 12 changed Dart files format unchanged. Seventeen mapped
  hashes reconcile to independent records; OMP 18.1.19 required eight new binary
  downloads, including the reserved Windows ARM64 asset. No candidate was run
  in Step 5. Detailed provenance and coverage: [STEP-5-VERIFICATION.md](STEP-5-VERIFICATION.md).
- Step 5 review: CI passed 15/15 at `c67bfaf`; the follow-up clarifies probe-only
  environment controls, distinguishes Grok's earlier metadata timestamp, orders
  this log by series evidence, and adds durable target/coverage notes to
  `docs/regression/plugin-setup-and-lifecycle.md`. Production code is unchanged
  by the follow-up, so passing unit/analyzer/native commands are not repeated.
- Coverage remains limited to each report's actual boundary. In particular,
  Hermes' rejected procedure cannot substantiate absence of inherited inputs.
  No live-profile access is authorized. Configured, multi-select and Windows
  ARM64 checks remain in final follow-up; other platforms stay untested.

## Completion rule

Record each target as updated when its actual source/assets/fixtures are updated;
record verification separately, never as an inferred pass. All ten included
harnesses must move forward, except an explicitly justified temporary severe
exception with a concrete resolution path. Real managed hashes and unchanged
floor/package policies remain mandatory.

Steps 6–7 include feature-owned docs with honest coverage notes. Step 8 reconciles
all evidence and prepares one grouped follow-up/user-help handoff. Step 9 runs
available final checks, resolves reported issues, records `Pass`, `Partial`,
`Fail`, `Blocked` or `Not run`, and obtains explicit acceptance of remaining
coverage limits before retirement. A missing fixture is not a pass and not an
old-version policy. Keep the plan active until that final acceptance; DeepSeek
remains excluded.
