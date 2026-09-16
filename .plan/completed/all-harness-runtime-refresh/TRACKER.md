# All Harness Runtime Refresh — Tracker

## Final state

- **Series:** nine top-level steps; Steps 1–8 merged, final PR records acceptance and retirement.
- **Branch/base:** `all-harness-runtime-refresh-step-9` /
  `d46880ad76505782a93f3db200bf5dcc9b8c944a`.
- **Delivered scope:** all ten included targets and 41 managed asset/hash pairs;
  required Pi/Claude lifecycle follow-up and Antigravity's actual production
  validator; localized Hermes discovery cleanup; OMP Windows ARM64 mapping;
  and shared ACP array questions. No new wire/database fields, generated churn
  or product release. Verification is scoped and incomplete, not inferred from delivery.
- **Approved scope:** mechanical target refreshes, OMP Windows ARM64 mapping,
  and OMP-backed shared ACP multi-select questions. Floors and Antigravity's
  exact-pair policy are preserved; DeepSeek and unrelated changes remain excluded.
- **Preceding merge:** PR #1469 merged on 2026-09-13 at `14:11:02Z` as
  `d46880ad76505782a93f3db200bf5dcc9b8c944a`. Terminal CI passed 9/9; Cubic
  found no issues across seven files, Codex completed the accepted head, and no
  unresolved threads remained. No review waiver was needed for this PR.
- **Owner correction, 2026-09-13:** update every included harness. Missing tests,
  credentials or runners must become final-plan follow-ups, not old-version
  holds or repeated questions about whether to proceed. Only an exceptional
  concrete problem justifies a temporary hold with a specific resolution path;
  none is currently established for these updates.
- **Owner acceptance, 2026-09-13:** selected "Accept all documented limits" and
  "Separate follow-up issue" for the cache-policy question. The required L2
  target/feature matrices remain partial; failed, blocked and unrun checks are
  accepted limitations, never relabelled passes. PLAN.md records each limit.
- **Final branch:** documentation-only acceptance and retirement into
  `.plan/completed/all-harness-runtime-refresh/`. No further download, rehash,
  native execution, Dart test or analyzer run; no new credentials or retry authority.
- **Follow-up disposition:** [issue #1470](https://github.com/sesori-ai/sesori_apps_monorepo/issues/1470)
  separately tracks mixed-build cache behavior. No cache fix, harmlessness claim
  or optional feature adoption. The other named coverage limits are accepted
  without further execution; Codex/Hermes remain stopped. Full evidence and
  acceptance are in [final coverage and handoff](FINAL-COVERAGE-HANDOFF.md). See
  [Step 7 verification](STEP-7-VERIFICATION.md),
  [Step 6 verification](STEP-6-VERIFICATION.md),
  [Step 5 verification](STEP-5-VERIFICATION.md),
  [Step 4 verification](STEP-4-VERIFICATION.md),
  [Step 3 verification](STEP-3-VERIFICATION.md),
  [Step 2 verification](STEP-2-VERIFICATION.md), and its
  [lifecycle follow-up](STEP-2-LIFECYCLE-VERIFICATION.md).

## Delivery ledger

Rows retain each step's delivery-time evidence. The final row is completed by
this retirement PR, not a claim that its review/merge has already occurred.

| Done | Step | Exact PR title | Status |
|---|---|---|---|
| [x] | 1/9 | `🌱 [all-harness-runtime-refresh] docs: publish runtime refresh plan [step 1/9]` | PR #1453 merged as a644652e0c; no production changes |
| [x] | 2/9 | `🌿 [all-harness-runtime-refresh] runtime: refresh mechanical targets [step 2/9]` | PR #1455 merged as ba3264eab9; four targets verified including post-merge Pi/Claude follow-up; Codex/OMP deferred then, now updated in Step 5 |
| [x] | 3/9 | `🌿 [all-harness-runtime-refresh] runtime: validate Antigravity and Cursor exact builds [step 3/9]` | PR #1457 merged as d55b93c874; Antigravity verified/applied including actual production-validator gate; Cursor deferred then, now updated in Step 5 |
| [x] | 4/9 | `🌿 [all-harness-runtime-refresh] runtime(hermes): fix ephemeral catalog cleanup [step 4/9]` | PR #1460 merged as 600d94fb49; cleanup fix, 11 tests and analyzer pass; candidate native verification not accepted; target was unchanged at that merge |
| [x] | 5/9 | `🌿 [all-harness-runtime-refresh] runtime: finish remaining target updates [step 5/9]` | PR #1465 merged as 79932e1051; five targets, 17 mapped digests, 121 tests, five analyzers; native/configured limits remain final follow-ups |
| [x] | 6/9 | `🌿 [all-harness-runtime-refresh] runtime(omp): add Windows arm64 asset [step 6/9]` | PR #1467 merged as acc970cf84; eighth mapping/hash, 10 focused tests/analyzer and platform docs; native ARM64 remains final follow-up |
| [x] | 7/9 | `🌿 [all-harness-runtime-refresh] acp: support OMP multi-select questions [step 7/9]` | PR #1468 merged as fa0111b153; separate array/custom questions, 75 focused tests, four analyzers, architecture approved and feature docs; live roundtrip remains final follow-up |
| [x] | 8/9 | `🌱 [all-harness-runtime-refresh] docs: reconcile runtime regression coverage [step 8/9]` | PR #1469 merged as d46880ad76; scoped matrix, durable coverage and one grouped check/policy/help handoff; CI 9/9 and settled reviews |
| [x] | 9/9 | `🌱 [all-harness-runtime-refresh] docs: record accepted coverage and retire plan [step 9/9]` | Owner accepted all documented limits; separate cache issue #1470; final PR carries retirement without new native execution |

## Harness status matrix

| Harness | Branch target | Floor/exact policy | Candidate | Status |
|---|---:|---|---:|---|
| OpenCode | `1.18.30` | `1.14.0` unchanged | `1.18.30` | Pass: six hashes, install, REST/SSE, read-only catalog, focused tests/analyzer |
| Antigravity | package `1.1.1`; server `agy_acp_server_1.1.1` | Exact package/server/ACP 1; no semantic floor | package `1.1.1`; server `agy_acp_server_1.1.1` | Pass: five hashes, macOS ARM64 install/actual production validator/initialize/cleanup, focused tests/analyzer |
| Codex | `0.154.0` | `0.139.0` unchanged | `0.154.0` | Updated in Step 5; six digests and 38 tests/analyzer pass. Retained install/transports passed; probe teardown remains unresolved |
| GitHub Copilot | `1.0.83` | `1.0.78` unchanged | `1.0.83` | Pass: six hashes, install, ACP initialize, focused tests/analyzer |
| Cursor | `2026.09.10-fd3934a` | date floor `2026.07.16` unchanged | `2026.09.10-fd3934a` | Updated in Step 5; four hashes, retained native setup and 26 tests/analyzer pass. Configured load/replay/model/mode remain unverified |
| Claude Code | `2.1.269` | `2.1.221` unchanged | `2.1.269` | Pass: CLI launch, native controlled-provider approval/replay/interrupt/reuse/cleanup plus production parsing/history mapping; tests/analyzer |
| Hermes Agent | `0.21.2` | `0.20.0` unchanged | `0.21.2` | Updated in Step 5; 18 descriptor tests/analyzer pass. Failed load and unaccepted native procedure/evidence remain unverified, explicitly accepted limits |
| Pi | `0.85.1` | `0.84.1` unchanged | `0.85.1` | Pass: six hashes/install/RPC, native production-plugin settlement/manual-compaction abort/ordering/reuse/cleanup; tests/analyzer |
| Oh My Pi | `18.1.19` | `17.2.13` unchanged | `18.1.19` | Step 5 updated the target and seven mappings; Step 6 added the remaining Windows ARM64 mapping, completing eight verified asset/hash pairs, with 10 focused cases/analyzer passing. Earlier native observations were 18.1.18; current native/configured checks remain unrun and accepted as limits |
| Grok Build | `1.0.30` | `1.0.5` unchanged | stable channel `1.0.30` | Updated in Step 5; channel and 12 descriptor tests/analyzer pass. Native/authenticated coverage remains unverified and explicitly accepted as a limit |
| DeepSeek | Not assessed (excluded) | Outside this series | None | Explicitly excluded; historical baseline is not a current-target claim, and unrelated upstream changes are neither audited nor modified here |

## Approved and deferred decisions

- **Approved:** update every included stable target; preserve every floor and
  Antigravity exact-pair policy; add OMP Windows ARM64 and shared ACP array
  `items.anyOf` forms for OMP. Do not ask whether to hold routine updates.
- **Accepted final limits:** the owner accepted Codex teardown, Cursor
  load/replay/model/mode, OMP current-target source/native/configured lifecycle,
  Hermes faithful load/cleanup and rejected evidence, Grok native/authenticated
  flow, Windows ARM64 native smoke, live multi-select and the handoff's other
  coverage boundaries. Failed or unavailable checks remain so; no new execution.
- **Separate follow-up:** cache-policy investigation is issue #1470; no policy
  change or optional feature was approved.
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
- **Actual implementation shape:** Step 6 changed one mapping and its owning
  tests; Step 7 changed 435 Dart lines (77 production, 358 tests). Both were
  straightforward (`🌿`) without new wire/state machinery; original estimates
  remain historical audit context, not a reason to add code.
- **Declined/deferred:** upstream optional models/providers, auth/login beyond
  named required probes, sub-agents, plan UX, shell-command claims,
  cancellation redesign, floor changes, and broad cleanup/refactors.

## Accepted verification limits and separate follow-up

Check status is independent of target adoption and acceptance. The
[final handoff](FINAL-COVERAGE-HANDOFF.md) preserves each smallest future check,
potential harm and evidence to close. The owner explicitly accepted these limits
in Step 9 without further execution; only the cache question gets a separate issue.
This table is not an active execution queue or new authorization.

| Check | Evidence still needed | Current evidence limit / help |
|---|---|---|
| Codex teardown | No surviving owned process or listener after a permitted probe | Existing controller failure; no further cleanup retry authorized |
| Cursor configured lifecycle/options | Isolated load/replay/model/mode | Configured fixture or user-assisted check needed |
| OMP current-target lifecycle | Complete 18.1.19 source/native follow-up; authenticate(agent), list/new/load, persisted cleanup | Configured fixture needed; earlier native observations are 18.1.18 only |
| Hermes configured lifecycle | Faithful isolated launch, actual persisted load/deletion | Attempted load failed; procedure/evidence not accepted; review before any execution |
| Grok native/authenticated seam | Branded identity, exact launch/ACP, then new/prompt/replay/model-selection/close | Testing authorized in principle; secure test credential, endpoint/budget scope and procedure still needed |
| OMP Windows ARM64 | Native install/version/ACP smoke | Mapping/tests/docs implemented; native ARM64 runner or user assistance still needed |
| OMP ACP multi-select | Live OMP/client array roundtrip, including omission/cancel and single choice | Step 7 mapper/plugin/bridge/widget automation passes; arrange the missing live fixture at the final stage |
| Managed-cache policy | Bounded mixed-build reproduction and decision on newer cached versions when an older bridge starts | Separately tracked in issue #1470; not reproduced, fixed or declared harmless; no shared policy change |

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
- Step 5 merge: PR #1465 merged as `79932e1051` at `2026-09-13T11:25:53Z`;
  terminal CI 16/16, Cubic approval, current-head Codex review complete, all
  threads resolved. The shared managed-cache policy question stays in final
  follow-up; no production selection/cleanup behavior was changed by review.
- Step 6: the Windows ARM64 mapping reuses Step 5's verified artifact/hash.
  Ten cases across manifest and asset-repository/service suites pass; owning
  analyzer passes; three Dart files format unchanged. No download, binary
  parsing, candidate execution or native ARM64 verification was repeated or
  newly performed. Capability/regression docs distinguish implementation from
  native coverage. See [Step 6 verification](STEP-6-VERIFICATION.md).
- Step 6 merge: PR #1467 merged as `acc970cf84` at `2026-09-13T12:00:25Z`;
  terminal CI 16/16, Cubic approval, current-head Codex review complete. Its sole
  tracker-wording finding was corrected and resolved without rerunning code tests.
- Step 7: 23 ACP mapper/registry cases, 15 OMP plugin cases, 16 bridge question
  repository cases and 21 widget cases pass; all four owning analyzers pass.
  Cases include identical option/custom text in separate slots, independent
  omission/required rejection, malformed-array decline, immutable encoding,
  and unchanged scalar/reject/cancel paths. The OMP fake checks live form support
  and scratch omission; it is not native execution. The missing client workspace
  configuration was prepared once from cached dependencies with offline,
  lockfile-enforced pub get; no dependency/generated tracked files changed.
  See [Step 7 verification](STEP-7-VERIFICATION.md).
- Step 7 architecture implementation review approved `266babbf85` with no
  findings. It confirmed ACP-layer ownership, immutable choice encoding and
  unchanged cross-layer boundaries; no code fix or repeated test was needed.
- Step 7 merge: PR #1468 merged as `fa0111b153` at `2026-09-13T13:11:04Z`;
  terminal CI 19/19, Cubic approval, accepted-head Codex review complete. Its sole
  stale merged-PR-count finding was corrected in `49657930be` and resolved;
  documentation-only follow-ups did not repeat code or native checks.
- Step 8 reconciled the 11 registered / ten included inventory and 41 actual
  managed mappings from unchanged source, separately from extra member digests.
  Expanded durable setup coverage to all ten included targets and consolidated
  accepted, partial, failed, blocked and unrun evidence plus exact final help.
  No candidate was fetched, parsed, installed or executed; no unchanged native,
  Dart or analyzer check was repeated. Seven Markdown documents, 50 relative
  links/anchors, nine synchronized titles, all ten target/floor rows and skill
  YAML metadata passed the relevant checks; no production/generated file changed.
- Coverage remains limited to each report's actual boundary. In particular,
  Hermes' rejected procedure cannot substantiate absence of inherited inputs.
  No live-profile access is authorized. Configured, multi-select and Windows
  ARM64 checks remain in final follow-up; other platforms stay untested.

- Step 8 merge: PR #1469 merged as `d46880ad76` at `2026-09-13T14:11:02Z`;
  terminal CI 9/9, current-head Cubic approval with no findings and Codex review
  complete. No fix commit, repeated verification or review waiver was needed.
- Step 9 owner disposition: all documented coverage limits explicitly accepted
  on 2026-09-13, with no further native execution. Created separate cache-policy
  investigation issue #1470. PLAN.md and the final handoff record every accepted
  boundary while keeping actual results unchanged; this PR carries retirement.
  Validated 11 moved Markdown files, eight byte-unchanged historical reports,
  unchanged target/verification matrices, 54 relative links/anchors, nine exact
  titles, scope/privacy/whitespace and explicit acceptance. No native/Dart rerun.

## Completion disposition

All ten included targets and approved features are delivered, with real managed
hashes, preserved floors/exact-pair policy and scoped verification recorded.
Feature-owned documentation landed in Steps 6–7; Step 8 reconciled the matrix and
grouped help. The owner's 2026-09-13 explicit acceptance satisfies retirement
while keeping every `Partial`, `Fail`, `Blocked` and `Not run` result unchanged.

Step 9 records that acceptance and moves this plan to the completed directory.
Issue #1470 separately tracks the cache question; no further native checks or
stopped-probe retries are authorized. No exceptional target hold or DeepSeek
assessment is introduced. This closes the series by accepted limits, not by
claiming full L2/native coverage.
