# All Harness Runtime Refresh

## Status and constraints

- **Plan slug:** `all-harness-runtime-refresh`.
- **Status:** [plan PR #1453](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1453),
  [Step 2 PR #1455](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1455),
  [Step 3 PR #1457](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1457),
  [Step 4 PR #1460](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1460), and
  [Step 5 PR #1465](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1465)
  merged. Five targets are verified, including the required Pi/Claude lifecycle
  follow-up and Antigravity's actual production-validator native gate. Step 4
  shipped localized Hermes cleanup, with 11 focused tests and analyzer passing.
  The owner corrected the delivery policy on 2026-09-13: missing verification
  must not keep harnesses on old targets. Step 5 delivered the five remaining
  targets—Codex, Cursor, Hermes, OMP and Grok—with 121 focused cases and five
  owning analyzers passing. Step 6 implements OMP's eighth mapping, Windows
  ARM64, with 10 focused cases/analyzer passing. Native Windows ARM64 remains
  unverified and in final follow-up. See [Step 2](STEP-2-VERIFICATION.md),
  [Step 3](STEP-3-VERIFICATION.md), [Step 4](STEP-4-VERIFICATION.md),
  [Step 5](STEP-5-VERIFICATION.md), and [Step 6](STEP-6-VERIFICATION.md) evidence.
- **Planning baseline:** branch `update-target-runtime-all-harnesses`, commit
  `8879ea1a62cc52104509c4483fe611c7eb0287bf`.
- **Scope:** ten registered harnesses. DeepSeek remains registered for
  inventory reconciliation only and is explicitly excluded from this series' audit and changes.
- **Implementation branch:** `all-harness-runtime-refresh-step-6`, based on
  Step 5 merge `79932e1051cf46267dac8f3937546473ea56cf19`. This series preserves
  floors, existing layout/selection policy, launch behavior, and Sesori database/wire
  contracts; unrelated upstream changes are not part of this refresh.
- **Evidence:** [AUDIT.md](AUDIT.md) and Steps 2–4 preserve historical observations
  and decisions. Their former pin-blocking language is superseded by the owner
  direction below; actual failed/unexecuted checks remain failed/unexecuted.

### Owner direction — 2026-09-13

Update every included harness to its current stable target. Missing credentials,
fixtures, native runners or incomplete tests are not reasons to keep old pins or
ask repeatedly whether to proceed. Run safely available checks and group the
remaining tests, uncertain feature behavior and needed user help in Steps 8–9.
The Grok test authorization does not supply credentials or change this order.

Resolve real incompatibilities as update work. Only an exceptional concrete risk
such as data loss, a security regression or a demonstrated unusable core flow
justifies a temporary hold, with evidence, a smallest fix, responsible follow-up
and an exit condition. None is presently established for the five Step 5
updates: missing fixtures and probe-controller/isolation failures are not proof
of such a production regression.

Keep real release identities/digests, package and floor policies, credential
isolation and OS sandbox protections. Do not rerun stopped probes or broaden
permissions merely to obtain a pass. Update status and verification status are
separate; plan retirement still needs final coverage or explicit acceptance of
remaining limits. The parent owns tracked changes, commits and publication.

## Goal and non-goals

Bring every in-scope runtime target up to date while preserving compatibility
floors, exact pair policy, launch policy and protocol seams. Resolve release,
byte/layout and adapter issues without guessing identities or weakening
validators. Deliver updates without waiting for unavailable verification; keep
those checks and any required fixes explicit in the final follow-up work.

Non-goals:

- no floor/minimum increase, PATH precedence change, or explicit-binary change;
- no DeepSeek producer, consumer, candidate, or opportunity work;
- no new authentication, provider, model, sub-agent, cancellation, history,
  analytics, or unrelated client/catalog feature beyond approved ACP
  multi-select presentation;
- no managed pipeline for direct CLIs and no replacement of DB-first OpenCode,
  Pi RPC, Codex dual transports, ACP, or Claude/Grok proprietary seams;
- no broad Hermes cleanup, compatibility shim, considerable refactor, new
  persistence, wire contract, or generated-file hand edit;
- no claim of full UI, provider, authenticated, or alternate-platform coverage.

Approved additions are limited to OMP Windows ARM64 packaging and the shared
ACP multi-select question path described below. They are separate from
mechanical target pins.

## Registered inventory reconciliation

Registry authority is `bridge/app/lib/src/runtime/plugin_registry.dart`; it
contains 11 entries. This pre-series baseline reconciles all 11, including the
excluded row; [TRACKER.md](TRACKER.md) records current targets separately from
verification status. Release links alone are not native verification.

| Harness | Pre-series target / floor or exact policy | Candidate and evidence | Distribution / status |
|---|---|---|---|
| OpenCode | `1.18.19` / `1.14.0` | [`v1.18.30`](https://github.com/anomalyco/opencode/releases/tag/v1.18.30) | Six managed single-binary archives; adopted in Step 2 |
| Antigravity | Registry package `1.0.0`; exact server `agy_acp_server_20260818_01_RC01`, ACP 1; no semantic floor | Registry [`v2026.09.12-d30bc9a`](https://github.com/agentclientprotocol/registry/releases/tag/v2026.09.12-d30bc9a), package `1.1.1`; observed server `agy_acp_server_1.1.1` | Five ZIP hashes and macOS ARM64 install/initialize/cleanup accepted in Step 3 |
| Codex | `0.153.4` / `0.139.0` | [`rust-v0.154.0`](https://github.com/openai/codex/releases/tag/rust-v0.154.0) | Six canonical package tarballs; Step 5 update, teardown follow-up |
| GitHub Copilot | `1.0.80` / `1.0.78` | [`v1.0.83`](https://github.com/github/copilot-cli/releases/tag/v1.0.83) | Six single-binary archives; adopted in Step 2 |
| Cursor | `2026.08.11-e8db854` / date floor `2026.07.16` | [official installer](https://cursor.com/install), exact `2026.09.10-fd3934a` | Four package tarballs; Step 5 update, configured checks in final follow-up |
| Claude Code | `2.1.237` / `2.1.221` | [`v2.1.269`](https://github.com/anthropics/claude-code/releases/tag/v2.1.269); npm `latest` agrees | Direct configured/PATH CLI, zero managed assets; adopted with lifecycle follow-up |
| Hermes Agent | `0.20.4` / `0.20.0` | [`v2026.9.11`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.11), CLI `0.21.2` | Direct `hermes acp`; cleanup fix merged; Step 5 target update with load/isolation follow-up |
| Pi | `0.84.4` / `0.84.1` | [`v0.85.1`](https://github.com/earendil-works/pi/releases/tag/v0.85.1); npm package `@earendil-works/pi-coding-agent` | Six package archives; adopted with settlement/compaction follow-up |
| Oh My Pi (OMP) | `17.3.8` / `17.2.13` | [`v18.1.19`](https://github.com/can1357/oh-my-pi/releases/tag/v18.1.19), published 2026-09-12 | Seven existing assets updated in Step 5; Step 6 maps the independently hashed eighth Windows ARM64 binary |
| Grok Build | `1.0.5` / `1.0.5` | [xAI stable channel](https://x.ai/cli/stable), channel `1.0.30` | Direct official CLI; Step 5 update, authenticated checks in final follow-up |
| DeepSeek (excluded) | `0.1.5` / `0.1.5` | None assessed | Historical six-asset snapshot; current implementation not assessed |

### Compatibility policy

Keep independent floors exactly: OpenCode `1.14.0`, Codex `0.139.0`, Copilot
`1.0.78`, Cursor date floor `2026.07.16`, Claude `2.1.221`, Hermes `0.20.0`,
Pi `0.84.1`, OMP `17.2.13`, and Grok `1.0.5`. Antigravity keeps its exact
package/server/protocol identity contract and receives no invented semantic
floor. OMP Windows ARM64 is an approved platform mapping, not a floor change.

## Harness findings and boundaries

- **OpenCode:** `1.18.30` and six assets landed in Step 2. Preserve DB-first
  import, attach/port policy and PATH precedence. Provider/model, retry and
  reasoning opportunities remain track-only.
- **Antigravity:** Step 3 adopted package/server `1.1.1` through release facts
  after five-asset integrity and actual production-validator evidence. Preserve
  sibling server/harness placement and exact ACP 1/pair policy. No OAuth,
  session, model or delegation coverage is claimed.
- **Codex:** Step 5 updates `codex_runtime_manifest.dart` to `0.154.0` with six
  canonical packages. Reuse accepted byte/install and both-transport observations.
  The probe's failed automatic teardown remains a final follow-up, not proof of
  a production regression. Do not repeat the prohibited cleanup retry. Preserve
  helpers/resources, opt-outs, rollout history, approvals and queue ownership.
- **Copilot:** `1.0.83` and six assets landed in Step 2. Preserve
  `--no-auto-update --acp`, out-of-band auth and model/mode/command limits;
  prerelease and login/AHP/cloud/plugin features remain excluded.
- **Cursor:** Step 5 adopts `2026.09.10-fd3934a` and four previously hashed
  packages. Preserve the date floor, full `dist-package/` tree and no Windows
  mapping. Configured load/replay/model/mode checks move to final follow-up;
  no publisher checksum, immutable release or source attestation is invented.
- **Claude Code:** `2.1.269` landed with subsequent accepted native controlled-
  provider approval/replay/interrupt evidence. The npm stable/latest distinction
  is not prerelease evidence; SDK `0.3.269` is separate, not a bridge dependency.
- **Hermes:** Step 4 merged exact requested-ID not-found cleanup, preserving real
  errors and settlement-before-delete. Step 5 updates the target to `0.21.2`.
  Failed fresh load and unaccepted isolation/launch/evidence remain explicit
  final investigation items; they are not converted into passing observations.
  See [Step 4 verification](STEP-4-VERIFICATION.md). No broad compatibility layer
  or new native execution without the required procedure review.
- **Pi:** `0.85.1` and six packages landed with accepted settlement and compaction-
  abort follow-up. Preserve package layout, no-handshake behavior and settlement
  ownership. The npm authority is `@earendil-works/pi-coding-agent`.
- **OMP:** Step 5 delivered `18.1.19`; Step 6 adds the eighth direct-binary
  mapping, `omp-windows-arm64.exe`, using the hash already verified in Step 5.
  Manifest and production asset-service selection tests pass, with platform docs
  recording native Windows ARM64 coverage as unverified. Earlier native
  observations belong to `18.1.18`. Native `18.1.19`, configured
  `authenticate(agent)`, list/new/load and persisted cleanup remain final checks. Preserve glibc/musl selection and direct layout; no unrelated
  sub-agent, plan or shell-command feature is adopted.
- **Grok Build:** Step 5 updates the direct CLI target to stable `1.0.30`.
  Available public metadata is sufficient to select the target; native identity,
  exact launch and authenticated new/prompt/replay/model-selection/close remain
  separately reported checks, not reasons to retain `1.0.5`. Preserve
  `--no-auto-update agent --no-leader stdio` and scoped-stop policy. Source
  `x.ai/...` methods normalize to `_x.ai/...`; see
  [ACP 0.10.4](https://docs.rs/agent-client-protocol/0.10.4/src/agent_client_protocol/lib.rs.html#221-234).
  Source-to-binary association is optional evidence.
- **DeepSeek:** excluded. Its pre-series `0.1.5` and six assets are historical
  observations, not a freeze/restore requirement. Do not audit, modify or revert
  unrelated DeepSeek changes; its current target is not assessed here.

No additional safe simplification was established. Preserve existing bridge
queue, replay, catalog, history, approval and cancellation ownership.

## Reference and completeness

- Registry, runtime reference, plan, and tracker reconcile all 11 registered
  entries; ten are in scope and DeepSeek is explicitly excluded.
- Reference maintenance includes Pi's corrected npm package, OMP asset-map
  enumeration, Grok's normalized namespace and optional attestation policy.
  The 2026-09-13 owner correction additionally makes runtime refreshes update-
  first, groups missing checks at the end, and removes repeated hold/fixture
  questions. Probe lessons strengthen isolation, ownership and evidence truth.
- Historical observations remain historical. No excluded harness or optional
  feature is added merely to apply the corrected delivery policy.

## Approved design additions

### OMP Windows ARM64

Treat `omp-windows-arm64.exe` as a separate packaging change after the
mechanical OMP pin. Verify candidate bytes and SHA-256 against release metadata
and `SHA256SUMS.txt`, preserve the direct executable layout, add the
`PlatformOs.windows`/`PlatformArch.arm64` entry in `OmpRuntimeManifest._assets`
(`bridge/sesori_plugin_omp/lib/src/runtime/omp_runtime_manifest.dart`). Keep
selection in the existing plugin-local `OmpRuntimeAssetService` and
`OmpRuntimeAssetRepository`; add no shared-runtime or client platform branches.
Update focused manifest/asset-repository tests and platform docs, distinguishing
implemented mapping from native verification. Current macOS arm64 is the ordinary
existing-platform check scope. Native Windows ARM64 install/version/ACP smoke
remains in the final matrix; if no runner is available, record the exact needed
user-assisted check rather than withholding the update or claiming it passed.

### Shared ACP multi-select questions

Implement the approved generic mapping in
`bridge/sesori_plugin_acp/lib/src/repositories/mappers/acp_elicitation_mapper.dart`:

- accept supported ACP form object properties whose array items use the approved
  `anyOf` string-choice shape; map labels and underlying values without exposing
  raw schema details;
- preserve one schema property per visible `PluginQuestionInfo` and immutable
  field encoder. An array becomes a checkbox question (`multiple: true`,
  `custom: false`); a separate string property remains its own custom-text
  question. For OMP's `qN` and `qN__other`, retain two questions in the same form,
  preserving their original keys, order, and independent required flags. The
  generic mapper must not interpret OMP key-naming conventions;
- do not merge option and custom answers into one flat list: identical text
  would lose its originating property. Existing question indexes keep them
  distinct, even when custom text equals an option label. In the multi-question
  OMP forms described above, the existing per-question decline returns an empty
  answer for optional-custom omission. Single-question decline retains its
  existing whole-request rejection. Reuse immutable per-property encoders and
  add the array variant only; scalar
  behavior stays unchanged, with no new public or shared wire fields;
- decline malformed/unsupported arrays without leaking defaults or labels in
  diagnostics; preserve scalar enum/boolean/custom behavior and single-choice
  semantics exactly;
- retain `OmpPlugin.supportsFormElicitation` in
  `bridge/sesori_plugin_omp/lib/src/omp_plugin_impl.dart` as the live-session
  capability owner. `OmpAcpApi.open()` in `lib/src/api/omp_acp_api.dart` continues
  advertising `formElicitation: false` for catalog/cleanup scratch processes.
  Do not enable base ACP defaults, scratch connections, or other plugins merely
  because the generic mapper understands arrays.

Preserve the existing layer flow without shared/client types in the ACP mapper:

1. ACP schema → `AcpElicitationMapper` → plugin-interface `PluginQuestionInfo`.
2. Bridge app's `PluginQuestionInfoMapping.toSharedQuestionInfo()` in
   `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`
   maps to shared `QuestionInfo` for the existing REST/SSE paths.
3. Existing client API/service flow → `QuestionModal` → shared `ReplyAnswer`.
4. Existing reply API → bridge app `QuestionRepository.replyToQuestion()` in
   `bridge/app/lib/src/repositories/question_repository.dart` → ordered
   `List<List<String>>` via `ReplyAnswer.values` → plugin reply operation →
   `AcpSupportedElicitationForm.buildResponse()` and its immutable descriptors.

Reuse `shared/sesori_shared/lib/src/models/sesori/question.dart`,
`reply_to_question_request.dart`, and the existing checkbox/custom behavior in
`client/module_app_ui/lib/src/features/session_detail/widgets/question_modal.dart`.
Add focused mapper tests in
`bridge/sesori_plugin_acp/test/acp_elicitation_test.dart`, OMP policy/fixture
coverage, and widget cases in
`client/module_app_ui/test/features/session_detail/widgets/question_modal_test.dart`.
No generated files or new mutable state are planned. In the same Step 7 PR,
update `docs/regression/questions-and-permissions.md` and the relevant
`docs/HARNESS_CAPABILITIES.md` entry after behavior passes. Record the separate
checkbox/custom questions, supported behavior, failure signals, and coverage;
do not defer these feature-owned docs to Step 8.

#### Multi-select feature matrix (independent of target-only L2)

Use the minimum sufficient scope from the regression README: **L2 Routine**
scoped to the OMP ACP form-question path, not full unrelated L3 catalog or
provider coverage. Completion requires both existing-widget automation and an
authoritative live OMP `askDialog`/ACP array roundtrip observed on at least one
supported client. Use the existing native fixture or an explicitly authorized
isolated configured fixture; never use ambient credentials. Exercise two
choices plus a separate custom-text question, selected values under original
keys (including custom text identical to an option label), optional-custom
omission, required-field omission/cancel, and unchanged single-choice behavior.
If the live fixture is unavailable, deliver the approved implementation with
honest coverage notes and schedule the roundtrip in final follow-up. Do not
reinterpret widget-only coverage as a live pass.

### Architecture plan review

The 2026-09-12 sub-agent review rejected the draft with four concrete ownership
clarifications: plugin/shared reply-layer separation, grouped-field descriptor
ownership, OMP live-versus-scratch capability scope, and plugin-local Windows
asset selection. The ownership boundaries are explicit above. PR review then
simplified grouping to the existing one-property/one-question alignment, so no
grouped descriptor or answer-provenance wire extension is needed. There is no
scope expansion or new coordination state. The corrected plan was not
re-reviewed; this records applied findings, not approval of the revised text.

### Cross-cutting implementation decisions

Reuse existing authoritative question-answer instrumentation; add no new
analytics event. Multi-select estimate is approximately **200-450 authored
lines**, and OMP Windows ARM64 mapping approximately **40-100 authored lines**;
refine estimates against the local implementation without widening scope. The
approved work adds zero new persistent or in-memory coordination parts, and no generated churn is expected.

## Verification contract

Update status and verification status are independent. Execute useful available
checks without a verification spiral; missing resources and inconclusive probes
move to Steps 8–9. The owner authorized this delivery order, not invented passes
or weaker credential/sandbox controls.

1. **Release/source:** confirm official stable metadata, identities and selected
   asset names. Record Codex tag objects separately from peeled commits. Resolve
   ambiguous identities without guessing. Cursor's official installer is release
   evidence; optional signatures/source attestations are not new requirements.
2. **Integrity:** use independently downloaded hashes for every selected managed
   asset and compare publisher lists when present. Reconcile existing machine-
   readable records; do not repeat accepted downloads for this policy change or
   copy digests from prose. Counts: OpenCode 6, Antigravity 5, Codex 6, Copilot 6,
   Cursor 4, Pi 6, OMP 7 in the target update and 8 after Step 6. Direct CLIs have
   zero managed assets. DeepSeek is excluded. Never mix new URLs with old hashes.
3. **Install/protocol:** use the actual production installer/validator/CLI seam
   when safely runnable, preserving package siblings, digest sentinels, launch
   flags and approval policy. Record native macOS arm64 evidence separately from
   unit or source evidence. Unavailable native checks become final follow-ups.
   Windows ARM64 needs its own native check; another host does not prove it.
4. **Isolation/ownership:** inspect the launcher, environment, OS profile and
   controller before any execution. Inputs are read-only; writes are confined to
   owned state/temp/project roots. Disable inheritance at native spawn. No live
   profiles, ambient secrets, credential helpers, SSH agents or MCP config.
   Credential-free networking is denied except an owned needed loopback endpoint;
   authenticated networking requires an explicit endpoint scope. The trusted
   deadline/cleanup owner covers fixture setup and compilation too. Preserve
   per-attempt evidence and verify current process ownership before signals.
   Do not rerun stopped Codex/Hermes probes under this policy correction.
5. **Configured checks:** keep Cursor load/replay/model/mode, OMP authentication/
   list/new/load/cleanup, Hermes faithful persisted load/cleanup and Grok
   authenticated new/prompt/replay/model-selection/close in the final queue when
   access is unavailable. Grok testing was authorized in principle, but secure
   credentials and endpoint details remain to arrange at that stage. Do not
   repeatedly ask whether to update or use a dummy fixture as real-auth proof.
6. **Focused checks:** update owning target/assets/target-specific fixtures in
   lockstep, run relevant tests and `dart analyze --fatal-infos`, and address real
   code failures. Preserve historical captures and minimum-version cases; use
   explicitly synthetic data for current-target fixtures. Do not edit generated
   files or rerun unchanged passing commands. Record any unavailable check.

The retained verification checklist is:

| Harness | Current-host evidence | Configured/final follow-up when unavailable | Optional boundary not claimed |
|---|---|---|---|
| OpenCode | Install/version/sentinel, serve/health/SSE, typed reads, shutdown, DB untouched | None outstanding from adopted update | Provider/account behavior |
| Antigravity | Five hashes, exact pair/ACP 1 production validator, auth methods, teardown | None outstanding from adopted update | OAuth/session/model/delegation |
| Codex | Package/helpers and independent WebSocket/stdio initialize/list/correlation | Reconcile failed probe teardown; no unauthorized retry | Account prompt/history/approval |
| Copilot | Install/version, exact ACP launch, initialize and copilot-login | None outstanding from adopted update | Entitlement/session/options/tool E2E |
| Cursor | Four hashes, native package/build/initialize/teardown | Configured load/replay/model/mode | Broad provider/model/cancel exploration |
| Claude | CLI flags, native controlled-provider approval/replay/interrupt, production parsing/history | None outstanding from adopted update | Real-provider/auth/queue/child terminal fixture |
| Hermes | Tagged CLI/initialize/list and scratch-cleanup observations, with recorded limits | Faithful isolated configured load and persisted cleanup; investigate reported failure | Broad provider/catalog/replay exploration |
| Pi | Package/RPC, settlement and compaction-abort/ordering/reuse | None outstanding from adopted update | Real-provider prompt/catalog/history |
| OMP | Eight 18.1.19 binary hashes; earlier native evidence was 18.1.18 only | Current 18.1.19 native/production seam, configured authenticate(agent), list/new/load, cleanup | Unrelated turn/plan/MCP/sub-agent behavior |
| Grok | Stable channel; native version/exact launch/ACP when safely available | Authenticated new/prompt/replay/model-selection/close | Broad provider/model/child exploration |

Focused package checks cover each owning manifest/descriptor, runtime policy,
transport, catalog, session, approval, cleanup, and adapter tests identified in
the runtime reference. Shared ACP multi-select additionally runs bridge mapper,
OMP policy, shared-model serialization (unchanged models), and client widget
coverage. Documentation-only commits run Markdown, link, inventory, title and
diff checks, not Dart/Flutter suites. Actual Step 9 runtime/feature checks use
their recorded boundaries rather than repeating unchanged passing work.

## Regression, matrix, and retirement

Feature-owned documentation lands with its implementation: Step 6 updates the
Windows platform coverage in `docs/regression/plugin-runtime-installation.md`
and `docs/HARNESS_CAPABILITIES.md`; Step 7 updates
`docs/regression/questions-and-permissions.md` and its capability entry.
Step 8 reconciles cross-harness evidence and prepares one grouped final follow-up
batch, not the first documentation of features already merged:

- `docs/regression/plugin-runtime-installation.md` for target assets/layouts,
  exact Antigravity pair, OMP seven/eight-platform policy, and install failures;
- `docs/regression/plugin-setup-and-lifecycle.md` for target/floor selection,
  PATH/explicit precedence, direct-versus-managed status, and exact validation;
- `docs/regression/questions-and-permissions.md` for ACP multi-select values,
  custom answers, required/optional omission, cancellation, and OMP-only scope;
- `docs/HARNESS_CAPABILITIES.md` for implemented behavior with explicit native
  coverage limits. Preserve historical observations; do not label deferred
  Windows or question checks as verified.

### Feature verification matrix (independent of target-only L2)

| Feature | Minimum sufficient scope/boundary | Evidence still needed | Delivery handling |
|---|---|---|---|
| OMP Windows ARM64 | L2 Routine on native Windows ARM64 | Native install/version/ACP smoke | Mapping/tests/docs implemented in Step 6; native runner check remains final follow-up |
| OMP ACP multi-select | L2 Routine scoped only to OMP ACP forms | Widget automation plus live askDialog/ACP roundtrip: two choices, separate custom text, required/optional omission, unchanged single choice | Implement approved flow; missing live fixture goes to final follow-up |

Recorded coverage is **L2 Routine** plus the named current-host macOS arm64
managed/direct target gate. The multi-select feature has an independent **L2
Routine** matrix scoped only to the OMP ACP form-question path: existing-widget
automation plus an authoritative live OMP `askDialog`/ACP array roundtrip on at
least one supported client. This does not claim full client L3, broad
authenticated-provider, full catalog, or unrelated alternate-platform
coverage. Current macOS arm64 remains sufficient for ordinary old-platform
target updates. OMP Windows ARM64 still needs its native install/version/ACP
check to claim that verification. A missing runner is a blocked **check**, not
an automatic implementation hold. Other non-macOS native paths remain
`Untested`. Evidence results use `Pass`, `Partial`, `Fail`, `Blocked` or `Not run`;
track target adoption independently.

### Final follow-up batch — Steps 8–9

Do available work first, then ask for concrete help in one grouped handoff. Do
not re-ask whether to update or silently discard any of these checks.

| Item | Smallest remaining check / expected result | Needed resource or help |
|---|---|---|
| Codex | Reconcile existing teardown evidence; a permitted future check must leave no owned process/listener | Review the controller failure first; no further cleanup retry is currently authorized |
| Cursor | Persist/load/replay a synthetic session and change model/mode through the real adapter | Isolated authorized configured fixture or user-assisted execution |
| Hermes | Use faithful CLI dispatch and reviewed isolation; reproduce fresh load, then prove real persisted deletion | Review retained evidence and corrected procedure; original deleted state must not be reconstructed as evidence |
| OMP lifecycle | Complete 18.1.19 source/native follow-up; authenticate(agent), create/list/fresh-load a synthetic session, then delete it | Isolated configured fixture; no ambient credentials; 18.1.18 observations do not prove 18.1.19 |
| Grok | At most bounded synthetic new/prompt/replay/model-selection/close checks on the official endpoint | Secure separate test credential and precise endpoint scope, or user-assisted execution |
| Windows ARM64 | Install the selected native asset and prove version plus ACP initialize | Native ARM64 runner or user-assisted check; x64/macOS do not count |
| Multi-select | Live OMP/client roundtrip including same-text option/custom answers, omission/cancel and single choice | Supported client plus an authorized live OMP fixture |

Include unresolved feature questions and any actual defect with a minimal
reproduction, harm, smallest fix and evidence required to close it. Fix ordinary
in-scope problems; do not invent large fallback/coordination machinery.

A review also raised the pre-existing managed-cache policy when an older bridge
runs after a newer one populated the same state: selection prefers the pinned
version, and install cleanup may reclaim non-pinned versions when no local
runtime is in use. The inventory/selection/cleanup code is unchanged by this
refresh. Preserving newer cached versions would change shared target/rollback
policy across managed harnesses, beyond these pins. Include that policy question
and a bounded mixed-build reproduction in the final handoff rather than silently
changing shared behavior or holding these version increases.

Retire after all ten included targets are updated with real assets, relevant
focused checks and the final matrix are recorded, feature/regression docs are
reconciled, and remaining coverage is completed or explicitly accepted by the
owner. An exceptional temporary version hold must have a concrete separately
tracked resolution, not disappear into a completed refresh. Until final
acceptance, keep this directory active. DeepSeek remains excluded.

## Nine-step delivery sequence

The series retains nine top-level steps and the five merged PRs. Step 5
finished all five remaining targets under the corrected update-first policy;
Steps 6–7 deliver the already-approved features. Steps 8–9 collect unresolved
questions, perform available follow-ups, request specific user help together,
and record final coverage/retirement. This changes delivery timing, not scope.

| Step | Exact PR title | Boundary |
|---|---|---|
| 1/9 | `🌱 [all-harness-runtime-refresh] docs: publish runtime refresh plan [step 1/9]` | Publish this plan, tracker, audit, and verified reference corrections; no production changes |
| 2/9 | `🌿 [all-harness-runtime-refresh] runtime: refresh mechanical targets [step 2/9]` | Merged OpenCode/Copilot/Claude/Pi targets; remaining Codex/OMP updates now belong to Step 5 |
| 3/9 | `🌿 [all-harness-runtime-refresh] runtime: validate Antigravity and Cursor exact builds [step 3/9]` | Merged Antigravity exact pair; retained Cursor integrity/native evidence for Step 5 |
| 4/9 | `🌿 [all-harness-runtime-refresh] runtime(hermes): fix ephemeral catalog cleanup [step 4/9]` | Merged narrow cleanup fix and honest native-evidence limits; target update now belongs to Step 5 |
| 5/9 | `🌿 [all-harness-runtime-refresh] runtime: finish remaining target updates [step 5/9]` | Codex, Cursor, Hermes, OMP and Grok targets; reconcile real existing asset hashes, owning fixtures/checks, corrected skill and final follow-up queue |
| 6/9 | `🌿 [all-harness-runtime-refresh] runtime(omp): add Windows arm64 asset [step 6/9]` | Implemented eighth mapping through existing ownership, manifest/asset-service tests and docs; native Windows evidence separately recorded |
| 7/9 | `⚙️ [all-harness-runtime-refresh] acp: support OMP multi-select questions [step 7/9]` | Shared array mapper, OMP-only live capability, separate option/custom questions, bridge/client tests, and question regression/capability docs; no generated/new state |
| 8/9 | `🌱 [all-harness-runtime-refresh] docs: reconcile runtime regression coverage [step 8/9]` | Penultimate evidence/docs reconciliation and one grouped follow-up/user-help handoff |
| 9/9 | `🌿 [all-harness-runtime-refresh] verify: record matrix and retire plan [step 9/9]` | Final L2 and feature checks, remaining issues/help, explicit coverage acceptance and conditional retirement |

Every implementation PR body uses real multiline Markdown with `## Complexity`,
`## What`, `## Why`, `## Risk and test focus`, and `## Expected result`, naming
no database/wire change for mechanical pins, updated targets, separately
unverified fixtures/platforms, and actual focused tests/analyzer results.
