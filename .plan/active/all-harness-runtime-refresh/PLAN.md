# All Harness Runtime Refresh

## Status and constraints

- **Plan slug:** `all-harness-runtime-refresh`.
- **Status:** [plan PR #1453](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1453),
  [Step 2 PR #1455](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1455), and
  [Step 3 PR #1457](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1457)
  merged. Five targets are verified, including the required Pi/Claude lifecycle
  follow-up and Antigravity's actual production-validator native gate. Step 4's
  localized Hermes cleanup fix passes 11 focused tests and the owning analyzer.
  Candidate `0.21.2` remains blocked: attempted load failed and the native run
  did not meet the agreed isolation/evidence boundary. The pin stays `0.20.4`.
  Cursor, Codex and OMP retain their blocked pins. See
  [Step 2 verification](STEP-2-VERIFICATION.md),
  [Step 3 verification](STEP-3-VERIFICATION.md), and
  [Step 4 verification](STEP-4-VERIFICATION.md).
- **Planning baseline:** branch `update-target-runtime-all-harnesses`, commit
  `8879ea1a62cc52104509c4483fe611c7eb0287bf`.
- **Scope:** ten registered harnesses. DeepSeek remains registered for
  inventory reconciliation only and is explicitly excluded from this series' audit and changes.
- **Implementation branch:** `all-harness-runtime-refresh-step-4`, based on
  Step 3 merge `d55b93c874e0f8f95f9e2aab6941f1f942697991`. This series preserves
  floors, layout/platform policy, launch behavior, and Sesori database/wire
  contracts; unrelated upstream changes are not part of this refresh.
- **Evidence:** [AUDIT.md](AUDIT.md) preserves the pre-implementation source
  snapshot. Step reports distinguish completed runtime gates from outstanding
  verification; unexecuted candidates remain provisional.

The parent publishes, commits, and pushes the plan. The first plan PR precedes
production work, but one local successor may begin while that plan PR is open.
A target changes only after its own release, integrity, install, identity,
protocol, and focused-test gates pass. A blocked target does not block an
independent peer; the series cannot retire with an unresolved required gate
unless an explicit exception is recorded.

## Goal and non-goals

Refresh validated runtime targets for every in-scope harness while preserving
existing compatibility floors, exact pair policy, launch policy, and protocol
seams. Preserve complete managed packages and fail closed on ambiguous release
identity, bytes, layout, or protocol behavior.

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
excluded row; [TRACKER.md](TRACKER.md) records current branch targets and gate
status. Release links alone are not completed implementation gates.

| Harness | Pre-series target / floor or exact policy | Candidate and evidence | Distribution / status |
|---|---|---|---|
| OpenCode | `1.18.19` / `1.14.0` | [`v1.18.30`](https://github.com/anomalyco/opencode/releases/tag/v1.18.30) | Six managed single-binary archives; recommended after gates |
| Antigravity | Registry package `1.0.0`; exact server `agy_acp_server_20260818_01_RC01`, ACP 1; no semantic floor | Registry [`v2026.09.12-d30bc9a`](https://github.com/agentclientprotocol/registry/releases/tag/v2026.09.12-d30bc9a), package `1.1.1`; observed server `agy_acp_server_1.1.1` | Five ZIP hashes and macOS ARM64 install/initialize/cleanup accepted in Step 3 |
| Codex | `0.153.4` / `0.139.0` | [`rust-v0.154.0`](https://github.com/openai/codex/releases/tag/rust-v0.154.0) | Six canonical package tarballs; recommended after both transports pass |
| GitHub Copilot | `1.0.80` / `1.0.78` | [`v1.0.83`](https://github.com/github/copilot-cli/releases/tag/v1.0.83) | Six single-binary archives; recommended after ACP/install gates |
| Cursor | `2026.08.11-e8db854` / date floor `2026.07.16` | [official installer](https://cursor.com/install), exact `2026.09.10-fd3934a` | Four package tarballs; probe-first content/hash/install gate |
| Claude Code | `2.1.237` / `2.1.221` | [`v2.1.269`](https://github.com/anthropics/claude-code/releases/tag/v2.1.269); npm `latest` agrees | Direct configured/PATH CLI, zero managed assets; recommended after stream/approval/replay/interrupt gates |
| Hermes Agent | `0.20.4` / `0.20.0` | [`v2026.9.11`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.11), CLI `0.21.2` | Direct `hermes acp`; cleanup fix implemented; candidate load/isolation gates blocked |
| Pi | `0.84.4` / `0.84.1` | [`v0.85.1`](https://github.com/earendil-works/pi/releases/tag/v0.85.1); npm package `@earendil-works/pi-coding-agent` | Six package archives; recommended after RPC, settlement, and manual-compaction abort/ordering gates |
| Oh My Pi (OMP) | `17.3.8` / `17.2.13` | [`v18.1.18`](https://github.com/can1357/oh-my-pi/releases/tag/v18.1.18), published 2026-09-11 | Seven assets in current Sesori manifest; official candidate has eight including Windows ARM64; approved separate platform step |
| Grok Build | `1.0.5` / `1.0.5` | [xAI stable channel](https://x.ai/cli/stable), channel `1.0.30` | Direct official CLI; recommended after channel/ACP gate |
| DeepSeek (excluded) | `0.1.5` / `0.1.5` | None assessed | Existing six managed assets remain untouched; excluded/unchanged |

### Compatibility policy

Keep independent floors exactly: OpenCode `1.14.0`, Codex `0.139.0`, Copilot
`1.0.78`, Cursor date floor `2026.07.16`, Claude `2.1.221`, Hermes `0.20.0`,
Pi `0.84.1`, OMP `17.2.13`, and Grok `1.0.5`. Antigravity keeps its exact
package/server/protocol identity contract and receives no invented semantic
floor. OMP Windows ARM64 is an approved platform mapping, not a floor change.

## Harness findings and boundaries

- **OpenCode:** update `open_code_runtime_manifest.dart` to `1.18.30` and six
  independently verified assets only after managed install plus REST/SSE health,
  event, typed-read, shutdown, and read-only DB checks. Preserve DB-first import,
  attach mode, port policy, PATH precedence, and floor `1.14.0`. Retries,
  provider/model, GPT-6/Astra, Bedrock, and reasoning notes remain track-only.
- **Antigravity:** update `antigravity_release.dart` and
  `antigravity_runtime_manifest.dart` only after all five candidate archives,
  sibling `agy_acp_server`/`localharness_external` members, exact initialize
  identity, ACP 1, auth methods, and teardown pass. No OAuth/session probe or
  native delegation matrix lift; package version is not server identity.
  Step 3 observed `agy_acp_server_1.1.1` from the candidate and applied only
  release facts; the manifest already derives its package target from them.
- **Codex:** update `codex_runtime_manifest.dart` and six canonical package
  assets after independent WebSocket and stdio app-server checks. Keep helpers,
  resources, capability opt-outs, rollout tailer, approvals, queue, history,
  and floor `0.139.0`. Worktrees, additive fields, async TUI questions, unload
  delay, and model additions remain track-only.
- **Copilot:** update target and six assets to stable `1.0.83` only after
  managed install and `--no-auto-update --acp` initialize/auth-method checks.
  Keep floor `1.0.78`, out-of-band auth, and current model/mode/command limits;
  hold prerelease `1.0.84-5` and all login/AHP/cloud/plugin features.
- **Cursor:** update exact raw build only after complete four-URL content capture,
  local hashes, package-tree placement, exact build, ACP initialize/model/mode,
  and configured load/replay checks. The required configured fixture is
  pin-blocking; an unavailable fixture blocks the Cursor pin. Self-hashed
  official installer bytes are acceptable pin evidence; no publisher checksum
  or immutable release is required. Preserve date floor `2026.07.16`,
  `dist-package/`, and no Windows.
- **Claude Code:** update direct CLI target to stable `2.1.269` only after
  isolated `--version`/help and every `claude_launch_spec.dart` flag, stream-json,
  approval, replay, interrupt, and teardown checks. npm `latest=2.1.269` while
  stable dist-tag remains `2.1.236` is a channel distinction, not prerelease
  evidence. SDK `0.3.269` is separate and not a bridge dependency.
- **Hermes:** Step 4 implements narrow idempotent cleanup for unpersisted empty
  discovery sessions, as confirmed in tagged source. Only exit 1 with the exact
  requested-ID not-found stdout and empty stderr is accepted; real errors and
  floor `0.20.0` remain intact. The target stays `0.20.4`: candidate `0.21.2`
  fresh-process load failed, and native isolation/launch/evidence was not
  accepted. Required configured-load and cleanup verification still block the
  pin; see [Step 4 verification](STEP-4-VERIFICATION.md). No broad compatibility
  layer or further native execution without procedure review.
- **Pi:** update target and six package assets to `0.85.1` after RPC startup,
  framing, `get_state`, settlement, package-tree, and manual-compaction abort
  checks. The correct npm comparison is `@earendil-works/pi-coding-agent`;
  earlier `@earendil-works/pi` 404 evidence was the wrong package. Keep floor
  `0.84.1`, no-handshake behavior, and existing settlement ownership.
- **OMP:** update target and seven existing direct-binary assets to `18.1.18`
  in the mechanical wave. Its pin also requires configured
  `authenticate(agent)`, list/new/load, and persisted-cleanup probes; missing
  required fixture evidence blocks the OMP pin. Step 6 separately adds approved
  `omp-windows-arm64.exe`, its mapping/test/hash, and platform documentation.
  Preserve glibc/musl selection, direct layout, unsupported behavior not covered
  by the new mapping, and no ACP sub-agent/plan/shell-command claims.
- **Grok Build:** update direct CLI target to stable channel `1.0.30` after
  channel identity, branded version, exact launch, ACP identity/list/load/
  resume/close, namespace, teardown, and reference-required authenticated
  new/prompt/replay/model-selection/close probes. Missing required fixture
  evidence blocks the Grok pin; optional broad provider/model/child exploration
  remains non-gating. Source may spell methods `x.ai/...`; SDK normalization
  emits `_x.ai/...`, so compare normalized wire names. Versioned normalization
  evidence is [ACP 0.10.4 source](https://docs.rs/agent-client-protocol/0.10.4/src/agent_client_protocol/lib.rs.html#221-234).
  Source-to-binary association is optional evidence, not a signed or
  source-attestation gate. Preserve `--no-auto-update agent --no-leader stdio`,
  floor `1.0.5`, and current scoped-stop policy.
- **DeepSeek:** no candidate audit or producer work. The `0.1.5` target/minimum
  and six assets in the inventory and `AUDIT.md` are historical pre-series
  observations, not a requirement to freeze or restore the current upstream
  target. Do not audit, modify, or revert unrelated DeepSeek changes; its current
  target is intentionally not assessed by this series.

No safe simplification was found. OMP native settlement and Hermes empty-shell
behavior affect cleanup/ordering but do not authorize removing bridge queue,
replay, catalog, history, approval, or cancellation ownership.

## Reference and completeness

- Registry, runtime reference, plan, and tracker reconcile all 11 registered
  entries; ten are in scope and DeepSeek is explicitly excluded.
- Evidence-backed reference maintenance is limited to the corrected Pi npm
  package name, OMP `v18.1.18` Windows ARM64 versus current seven assets, Grok
  normalized `_x.ai/...` wire namespace, and removal of unsupported signature or
  source-to-binary gate implications.
- No missing harness, stale release-channel rule, or additional safe reference
  correction was found. Historical capability/regression observations remain
  unchanged until a future verified behavior update.

## Approved design additions

### OMP Windows ARM64

Treat `omp-windows-arm64.exe` as a separate packaging change after the
mechanical OMP pin. Verify candidate bytes and SHA-256 against release metadata
and `SHA256SUMS.txt`, preserve the direct executable layout, add the
`PlatformOs.windows`/`PlatformArch.arm64` entry in `OmpRuntimeManifest._assets`
(`bridge/sesori_plugin_omp/lib/src/runtime/omp_runtime_manifest.dart`). Keep
selection in the existing plugin-local `OmpRuntimeAssetService` and
`OmpRuntimeAssetRepository`; add no shared-runtime or client platform branches.
Update focused manifest/asset-repository tests and verified platform docs. Current
macOS arm64 install/version/ACP smoke remains sufficient for ordinary old-
platform target bumps. Before claiming or retiring the approved Windows ARM64
platform, require native Windows ARM64 install/version/ACP smoke; a missing Windows
runner leaves this feature **Blocked**, never implicitly accepted.

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
omission, required-field omission/cancel, and unchanged single-choice behavior. A missing required
fixture or live roundtrip blocks this feature gate with no implied waiver.

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

Planned checks are distinct from this run's completed documentation checks.

1. **Release/source:** immediately before each target PR, re-fetch official
   stable metadata, flags, dates, asset names, and source/tag identities. For
   Codex record tag-object and peeled-commit IDs separately; do not call a tag
   object a commit. Stop that harness on moved or ambiguous refs. Cursor's
   official installer/content capture is the release identity; no signature or
   source-binary attestation gate is added.
2. **Integrity:** download opaque bytes for every managed candidate asset and
   independently SHA-256 each one. Compare publisher digests/checksum lists;
   retain the complete set. Counts are OpenCode 6, Antigravity 5, Codex 6,
   Copilot 6, Cursor 4, Pi 6, OMP 7 in Step 2 and 8 in Step 6. Direct Hermes,
   Claude, and Grok distributions have zero managed assets. DeepSeek is not
   rehashed or changed in this scope.
3. **Install:** on sandboxed macOS arm64, use the production installer,
   extractor, resolver, candidate manifest, isolated managed state, and empty
   project. Inspect complete package siblings/resources and
   `.sesori-runtime-sha256`. Direct CLIs run only in a disposable restricted
   boundary; no remote installer is executed for discovery. Current macOS arm64
   remains sufficient for ordinary old-platform target bumps. The approved OMP
   Windows ARM64 mapping separately requires native Windows ARM64
   install/version/ACP smoke before its platform claim or retirement; a missing Windows
   runner is a **Blocked** feature, never implicit acceptance.
4. **Protocol:** use isolated HOME/profile/config/cache roots, filtered
   allowlisted environment, loopback-only networking, bounded reads/process
   groups/cleanup, and no ambient token, profile, credential helper, SSH agent,
   MCP config, prompt, or transcript. Verify only each production seam:
   OpenCode REST/SSE; Codex WebSocket and stdio independently; ACP exact
   identity for Antigravity/Cursor/Copilot/OMP/Hermes/Grok; Claude stream-json;
   Pi RPC. Preserve launch flags and approval policy.
5. **Fixtures:** account-backed/configured feature probes require explicitly
   authorized credentials, network scope, and disposable profiles. None is
   available in this planning run. Pin-blocking required fixtures are Cursor
   configured load/replay; OMP configured `authenticate(agent)`, list/new/load,
   and persisted cleanup; Hermes configured new/load; and Grok authenticated
   new/prompt/replay/model-selection/close. Missing required fixtures block
   respective pins; no implied waiver. The OMP live `askDialog`/ACP array
   roundtrip is a separate multi-select feature gate. Optional broad
   provider/model/catalog/child exploration remains Blocked but non-gating. A
   no-credential target pin does not claim unrequired provider turns, auth,
   child lifecycle, or rich model behavior.
6. **Focused checks:** after a candidate passes, update only its owning target,
   exact pair, assets, or approved fixture and run the owning package tests plus
   `dart analyze --fatal-infos`. Never hand-edit generated files.

Required target and configured gates are:

| Harness | Required no-credential gate | Additional pin-blocking configured/authenticated gate | Optional boundary not claimed |
|---|---|---|---|
| OpenCode | Install, version/sentinel, `serve`, health/SSE, typed reads, clean shutdown, DB untouched | None | Provider/account behavior |
| Antigravity | Five archive hashes; current-host install and initialize-only exact pair/ACP 1/auth methods, teardown | None | OAuth/session/model/delegation |
| Codex | Package/helpers plus independent WebSocket and stdio initialize/list/correlation/teardown | None | Account prompt/history/approval |
| Copilot | Install/version, exact ACP launch, initialize and `copilot-login` method without prompting | None | Entitlement/session/options/tool E2E |
| Cursor | Four archive hashes; current-host package layout, exact build, ACP initialize/model/mode, teardown | Configured load/replay fixture; missing fixture blocks pin | Broad provider/model/cancel exploration |
| Claude | Isolated version/help, all launch flags, stream-json startup, approval/replay/interrupt/teardown with a controlled provider | None | Real-provider/auth/queue/child terminal fixture |
| Hermes | Tagged isolated `hermes acp` version/initialize/list/session-list plus scratch cleanup | Configured new/load fixture; missing fixture blocks pin | Provider/catalog/replay exploration |
| Pi | Package/version, RPC launch/get_state/correlation/teardown, settlement and manual-compaction abort/ordering with a controlled provider | None | Real-provider prompt/catalog/history |
| OMP | Managed direct placement, `omp/<version>`, ACP initialize and bounded queue/cancel smoke | Configured `authenticate(agent)`, list/new/load, persisted cleanup; missing fixture blocks pin | Authenticated turn, plan UX, MCP, sub-agents |
| Grok | Direct version/exact launch, ACP identity/list/resume/namespace/teardown | Reference-required authenticated new/prompt/replay/model-selection/close probes; missing fixture blocks pin | Optional broad provider/model/child exploration |

Focused package checks cover each owning manifest/descriptor, runtime policy,
transport, catalog, session, approval, cleanup, and adapter tests identified in
the runtime reference. Shared ACP multi-select additionally runs bridge mapper,
OMP policy, shared-model serialization (unchanged models), and client widget
coverage. Documentation-only Steps 1 and 8/9 run Markdown, link, inventory,
title, and diff checks only; no Dart/Flutter suite runs for this planning slice.

## Regression, matrix, and retirement

Feature-owned documentation lands with its implementation: Step 6 updates the
Windows platform coverage in `docs/regression/plugin-runtime-installation.md`
and `docs/HARNESS_CAPABILITIES.md`; Step 7 updates
`docs/regression/questions-and-permissions.md` and its capability entry.
Step 8 performs the broader cross-harness reconciliation of verified behavior,
not the first documentation of features already merged:

- `docs/regression/plugin-runtime-installation.md` for target assets/layouts,
  exact Antigravity pair, OMP seven/eight-platform policy, and install failures;
- `docs/regression/plugin-setup-and-lifecycle.md` for target/floor selection,
  PATH/explicit precedence, direct-versus-managed status, and exact validation;
- `docs/regression/questions-and-permissions.md` for ACP multi-select values,
  custom answers, required/optional omission, cancellation, and OMP-only scope;
- `docs/HARNESS_CAPABILITIES.md` only for verified OMP Windows ARM64 support or
  verified question behavior. Preserve historical versions and limitations.

### Feature-gate matrix (independent of target-only L2)

| Feature | Minimum sufficient scope/boundary | Required evidence | Status |
|---|---|---|---|
| OMP Windows ARM64 | L2 Routine platform-specific gate before platform claim | Native Windows ARM64 install/version/ACP smoke; missing Windows runner blocks feature, never implicit acceptance | Blocked |
| OMP ACP multi-select | L2 Routine scoped only to OMP ACP form questions | Existing-widget automation plus authoritative live OMP `askDialog`/ACP array roundtrip on at least one supported client: two choices+custom, selected values, required omission/cancel, single-choice unchanged | Blocked |

Recorded coverage is **L2 Routine** plus the named current-host macOS arm64
managed/direct target gate. The multi-select feature has an independent **L2
Routine** matrix scoped only to the OMP ACP form-question path: existing-widget
automation plus an authoritative live OMP `askDialog`/ACP array roundtrip on at
least one supported client. This does not claim full client L3, broad
authenticated-provider, full catalog, or unrelated alternate-platform
coverage. Current macOS arm64 remains sufficient for ordinary old-platform
target bumps. OMP Windows ARM64 is a separate feature gate requiring native
Windows ARM64 install/version/ACP smoke before its platform claim or
retirement; without a Windows runner its status is **Blocked**, not accepted.
Other non-macOS native paths remain `Untested`. Results use `Pass`, `Partial`,
`Fail`, `Blocked`, or `Not run` per the regression README.

Retire only when all ten rows have passed required target gates or have an
explicit accepted exception; pin-blocking configured/authenticated fixtures
have passed; selected managed assets independently hash; macOS arm64
identity/protocol checks pass; focused tests/analyzers pass; the independent
multi-select matrix and OMP Windows ARM64 gate are passed, or an explicit
accepted exception records their blocked status and no platform claim; the
related docs are reconciled; and final statuses are recorded. Then move this directory to
`.plan/completed/all-harness-runtime-refresh/`. DeepSeek remains excluded and
unchanged throughout.

## Nine-step delivery sequence

The series has nine top-level steps. Step 2 is a mechanical wave; each listed
harness is independently gated and a failed candidate leaves only that
harness's current pin unchanged. Steps 3–7 are separate boundaries. The
penultimate step is regression documentation and the final step records the
matrix/retirement decision.

| Step | Exact PR title | Boundary |
|---|---|---|
| 1/9 | `🌱 [all-harness-runtime-refresh] docs: publish runtime refresh plan [step 1/9]` | Publish this plan, tracker, audit, and verified reference corrections; no production changes |
| 2/9 | `🌿 [all-harness-runtime-refresh] runtime: refresh mechanical targets [step 2/9]` | OpenCode, Codex, Copilot, Claude, Pi, and OMP target/assets refreshes with independent release/install/protocol/tests; OMP uses seven existing assets |
| 3/9 | `🌿 [all-harness-runtime-refresh] runtime: validate Antigravity and Cursor exact builds [step 3/9]` | Antigravity exact package/server pair and Cursor exact installer build, content, hashes, layout, and ACP gates |
| 4/9 | `🌿 [all-harness-runtime-refresh] runtime(hermes): fix ephemeral catalog cleanup [step 4/9]` | Deliver narrow cleanup fix; hold `0.20.4` because candidate load and accepted isolated verification remain blocked |
| 5/9 | `🌿 [all-harness-runtime-refresh] runtime(grok): refresh target [step 5/9]` | Stable-channel `1.0.30`, normalized ACP namespace, exact launch/protocol gates; no source-binary gate |
| 6/9 | `⚙️ [all-harness-runtime-refresh] runtime(omp): add Windows arm64 asset [step 6/9]` | Approved eighth executable, manifest/platform tests, native Windows gate, and platform regression/capability docs |
| 7/9 | `⚙️ [all-harness-runtime-refresh] acp: support OMP multi-select questions [step 7/9]` | Shared array mapper, OMP-only live capability, separate option/custom questions, bridge/client tests, and question regression/capability docs; no generated/new state |
| 8/9 | `🌱 [all-harness-runtime-refresh] docs: reconcile runtime regression coverage [step 8/9]` | Penultimate verified regression/capability documentation and historical-status reconciliation |
| 9/9 | `🌿 [all-harness-runtime-refresh] verify: record matrix and retire plan [step 9/9]` | Final L2 target-only matrix, blocked/untested statuses, acceptance exceptions, and conditional retirement |

Every implementation PR body uses real multiline Markdown with `## Complexity`,
`## What`, `## Why`, `## Risk and test focus`, and `## Expected result`, naming
no database/wire/user-visible change for mechanical pins, target-specific
blocked fixtures, untested platforms, and focused tests/analyzer.
