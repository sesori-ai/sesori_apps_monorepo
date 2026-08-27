# DeepSeek Harness: Tracker

## Current State

- **Plan slug:** `deepseek-harness`
- **Plan status:** Steps 1-14 merged; Step 15/16 open for review
- **Current repository:** `sesori-ai/sesori_apps_monorepo`
- **Current branch:** `deepseek-harness/step-15-regression-docs`
- **Current open PR:** [PR #1129](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1129)
- **Next action:** review and merge Step 15, then run the Step 16 verification matrix
- **Implementation started:** yes
- **Retirement:** blocked until every required row in `PLAN.md` passes

## Fixed Delivery Sequence

| Done | Step | Repository | Exact PR title | Complexity | Soft line target | State |
|---|---|---|---|---|---:|---|
| [x] | 1/15 | apps monorepo | `🌱 [deepseek-harness] docs: plan DeepSeek Harness support [step 1/15]` | Trivial documentation, but architecture-bearing review | 1,500 | [PR #1036](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1036) merged |
| [x] | 2/15 | deepseek adapter | `⚙️ [deepseek-harness] feat(runtime): scaffold the DeepSeek ACP adapter [step 2/15]` | Moderate new transport/repository foundation | 1,000 | [PR #1](https://github.com/sesori-ai/sesori-deepseek-acp/pull/1) merged |
| [x] | 3/15 | deepseek adapter | `🚧 [deepseek-harness] feat(runtime): compose the DeepSeek coding runtime [step 3/15]` | Complex configuration, security, and lifecycle composition | 1,300 | [PR #2](https://github.com/sesori-ai/sesori-deepseek-acp/pull/2) merged |
| [x] | 4/15 | deepseek adapter | `🚧 [deepseek-harness] feat(runtime): add durable ACP sessions and replay [step 4/15]` | Complex persistence and live ownership | 1,450 | [PR #3](https://github.com/sesori-ai/sesori-deepseek-acp/pull/3) merged |
| [x] | 5/15 | deepseek adapter | `🚧 [deepseek-harness] feat(runtime): stream DeepSeek turns and interactions [step 5/15]` | Complex concurrent event and interaction flow | 1,450 | [PR #4](https://github.com/sesori-ai/sesori-deepseek-acp/pull/4) merged |
| [x] | 6/15 | deepseek adapter | `⚙️ [deepseek-harness] feat(runtime): expose DeepSeek catalogs and commands [step 6/15]` | Moderate option/command boundary | 1,200 | [PR #5](https://github.com/sesori-ai/sesori-deepseek-acp/pull/5) merged |
| [x] | 7/16 | apps monorepo | `🌿 [deepseek-harness] test(deepseek): vendor the DeepSeek extension protocol [step 7/16]` | Straightforward test-only protocol fixture foundation | 1,100 | [PR #1077](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1077) merged |
| [x] | 8/16 | apps monorepo | `⚙️ [deepseek-harness] feat(deepseek): scaffold the DeepSeek bridge plugin [step 8/16]` | Moderate new package and narrow ACP hooks | 1,450 | [PR #1088](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1088) merged |
| [x] | 9/16 | apps monorepo | `🚧 [deepseek-harness] feat(deepseek): map DeepSeek sessions and history [step 9/16]` | Complex replay and identity flow | 1,450 | [PR #1094](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1094) merged |
| [x] | 10/16 | apps monorepo | `🚧 [deepseek-harness] feat(deepseek): map DeepSeek turns and interactions [step 10/16]` | Complex events, questions, and permissions | 1,450 | [PR #1097](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1097) merged |
| [x] | 11/16 | apps monorepo | `⚙️ [deepseek-harness] feat(deepseek): expose options and lifecycle [step 11/16]` | Moderate plugin API and lifecycle composition | 1,350 | [PR #1100](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1100) merged |
| [x] | 12/16 | deepseek adapter | `🚧 [deepseek-harness] build(runtime): release the managed DeepSeek adapter [step 12/16]` | Complex supply chain and six-platform release | 1,300 | [runtime PR #9](https://github.com/sesori-ai/sesori-deepseek-acp/pull/9) merged; extractor-safe [v0.1.1 release](https://github.com/sesori-ai/sesori-deepseek-acp/releases/tag/v0.1.1) published after [PR #10](https://github.com/sesori-ai/sesori-deepseek-acp/pull/10) |
| [x] | 13/16 | apps monorepo | `⚙️ [deepseek-harness] feat(deepseek): install the managed DeepSeek runtime [step 13/16]` | Moderate managed-runtime integration | 1,250 | [PR #1109](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1109) merged |
| [x] | 14/16 | apps monorepo | `⚙️ [deepseek-harness] feat(app): activate DeepSeek Harness [step 14/16]` | Moderate registry/client activation | 1,000 | [PR #1110](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1110) merged |
| [ ] | 15/16 | apps monorepo | `🌱 [deepseek-harness] docs: document DeepSeek regression coverage [step 15/16]` | Straight documentation reconciliation | 600 | [PR #1129](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1129) open for review |
| [ ] | 16/16 | apps monorepo | `🌱 [deepseek-harness] docs: verify DeepSeek and retire the plan [step 16/16]` | Trivial evidence/retirement changes after a complex external verification run | 700 | Pending Step 15 |

On 2026-08-24, user approved this 15-to-16 split because combined staged
implementation measured 5,120 additions against the 1,500-line cap. Merged
Existing Steps 1-6 retain historical exact `/15` titles; every unopened former Step 7-15
was renumbered to Step 8-16 with `/16`.

The total and titles are fixed for the series. If implementation evidence
requires a split before a PR opens, update both plan and tracker first and
renumber every unopened title consistently. Do not silently exceed 1,500 lines.

## Locked Decisions

- One enhanced ACP runtime and one stdio connection; no parallel Web runtime.
- Runtime source/releases live in `sesori-ai/sesori-deepseek-acp`.
- Full `dsh-base` composition, not the limited stock ACP demo.
- Normal `DSH_HOME` is read for settings/credentials/skills; all Sesori session
  mutations live under plugin state.
- DeepSeek telemetry is forced off; sandbox defaults to workspace-write and
  approval defaults to ask.
- V1 supports only Sesori-owned DeepSeek sessions, not normal DeepSeek session
  import or attach.
- ACP carries common lifecycle/events; versioned DeepSeek extensions stay
  narrow and on the same connection.
- Provider/model selection ids are opaque. One primary DeepSeek agent is exposed.
- Persisted deletion remains unsupported upstream; Sesori purge/tombstone is
  authoritative for the product.
- Local provider setup only. No phone credential editor or backend-specific
  analytics.
- OpenCode remains preferred default; DeepSeek uses the generic icon in v1.

## Step 1 Checklist

- [x] Refresh Sesori `origin/main` and record exact base commit.
- [x] Refresh DeepSeek source/releases/npm package facts.
- [x] Inspect current ACP, managed runtime, registry, identity, client fallback,
  analytics, and regression seams.
- [x] Decide one-process runtime, state/config ownership, protocol extensions,
  packaging repository, feature degradation, and verification matrix.
- [x] Write `PLAN.md`, `TRACKER.md`, and `PROTOCOL.md`.
- [x] Run architecture plan review and apply valid findings.
- [x] Run Markdown/reference and `git diff --check` validation.
- [x] Inspect final Git status/diff/log; commit only the three plan files.
- [x] Push and open the exact Step 1 PR.

## Review Log

| Date | Review | Result | Changes |
|---|---|---|---|
| 2026-08-22 | Architecture plan review | Rejected draft with seven concrete findings | Clarified class composition/layers, moved DTO mapping to repositories, removed two unjustified Services, assigned the ACP live-client hook, fixed interaction ownership, made JSON Schema/corpus authoritative, and made the final step verification-only (then Step 15, now Step 16 after the approved split). Per repository rules, valid findings were applied without a second approval review. |
| 2026-08-23 | Step 4 architecture implementation review | Pass | Durable session ownership, persistence, and replay matched the planned one-process boundary. |
| 2026-08-23 | Step 5 architecture implementation review | Rejected first pass; passed second pass | Consolidated duplicate live/replay mappings into one event projector with thin delivery and collection sinks. |
| 2026-08-23 | Step 6 architecture implementation review | Rejected first pass; passed second pass | Changed cold rename from retained ACP ownership to one coordinated resume/rename/flush/notify/dispose transition. |
| 2026-08-24 | Step 8 architecture implementation review | Pass on both scoped reviews | Kept generic prompt metadata/client hooks in ACP while sealed generated extension variants and backend behavior remain DeepSeek-owned. |
| 2026-08-24 | Step 10 architecture implementation review | Pass on both scoped reviews | Kept common turn projection in ACP while DeepSeek owns question composition, replay identity override, metadata normalization, and representable status mapping. |
| 2026-08-24 | Step 11 architecture implementation review | Rejected first pass; passed second pass | Moved rename transport and DTO mapping behind the DeepSeek repository/service boundary so the plugin remains a consumer. |
| 2026-08-24 | Step 12 architecture implementation review | Rejected first pass; passed second pass | Added checked-in official Node archive digests as independent trust anchors for all six managed-runtime targets. |
| 2026-08-25 | Step 14 architecture implementation review | Pass | Registration remains at the bridge composition point, clients stay backend-neutral and forward-compatible, and DeepSeek intentionally uses known naming with generic artwork. |

## Verification Log

### Step 1/15

- [x] `git diff --check`
- [x] Plan file/reference validation: 15 ordered steps/titles, 10 regression
  documents, current implementation base, balanced fences, and no stale
  catalog/history Service references
- [x] Architecture plan review; seven valid findings applied without re-review
- [x] Final PR changed-line count, including this tracker: 1,466 of the 1,500-line target
- [x] Commit `c40fbc4ad` pushed; PR #1036 opened against `main`

### Step 4/15

- [x] `npm run check`: 51 tests at final reviewed head
- [x] `npm ls --depth=0`; exact direct dependency closure
- [x] `npm audit --omit=dev`: 0 vulnerabilities
- [x] Architecture implementation review passed
- [x] PR #3 merged

### Step 5/15

- [x] `npm run check`: lint, typecheck, 69 tests, and build pass
- [x] `npm ls --depth=0`; exact direct dependency closure
- [x] `npm audit --omit=dev`: 0 vulnerabilities
- [x] Architecture implementation review passed after consolidating event projection
- [x] Changed-line count: 1,459, nine above the soft target and within the 1,500-line cap
- [x] PR #4 merged after review fixes and passing CI

### Step 6/15

- [x] `npm run check`: lint, typecheck, 105 tests, and build pass
- [x] `npm ls --depth=0`; exact direct dependency closure
- [x] `npm audit --omit=dev`: 0 vulnerabilities
- [x] Architecture implementation review passed after making cold rename temporary
- [x] Final changed-line count: 1,681 after review hardening, 181 above the
  1,500-line cap; merged by the user with all review findings addressed
- [x] Synced with merged Step 5; post-merge verification remained green
- [x] PR #5 merged with all five checks passing

### Step 7/16

- [x] `dart pub get`
- [x] `dart analyze --fatal-infos`
- [x] `dart test`: protocol source-manifest and SHA-256 integrity pass
- [x] `git diff --check`
- [x] Synced with current `origin/main` after Step 6 merged
- [x] Final changed-line count: 1,379, above the 1,100 soft target and below the 1,500-line cap
- [x] Runtime PR #6 corrected pagination/question schema invariants before the
  exact merged commit and digests were re-vendored
- [x] Runtime PR #7 required plan-review choices before its exact merged commit
  and digests were re-vendored
- [x] Runtime PR #8 constrained selection IDs and successful question answers
  before its exact merged commit and digests were re-vendored

### Step 8/16

- [x] DeepSeek and ACP `dart analyze --fatal-infos`
- [x] DeepSeek and full ACP `dart test`
- [x] Generated JSON and every vendored valid/invalid fixture verified
- [x] Architecture implementation review passed twice
- [x] `git diff --check`
- [x] Final changed-line count: 1,500, at the 1,500-line cap

### Step 9/16

- [x] DeepSeek and ACP `dart analyze --fatal-infos`
- [x] DeepSeek and full ACP `dart test`
- [x] `git diff --check`
- [x] Synced with merged Step 8 and current `origin/main`; post-merge verification remained green
- [x] Final changed-line count: 480, below soft and hard caps
- [x] Architecture implementation review passed twice

### Step 10/16

- [x] DeepSeek and ACP `dart analyze --fatal-infos`
- [x] DeepSeek `dart test`: 21 tests pass
- [x] Full ACP `dart test`: 261 tests pass
- [x] `git diff --check`
- [x] Synced with merged Step 9 and current `origin/main`; post-merge verification remained green
- [x] Late Step 9 review feedback carried forward with blank parent IDs rejected and replay identity override narrowed to user messages
- [x] Final changed-line count: 480, below soft and hard caps
- [x] Architecture implementation review passed twice

### Step 11/16

- [x] DeepSeek and ACP `dart analyze --fatal-infos`
- [x] DeepSeek `dart test`: 31 tests pass
- [x] Full ACP `dart test`: 261 tests pass
- [x] Explicit/PATH setup probes, catalog mapping and ordered writes, adapter
  rename, extension refusal, crash recovery, and clean shutdown covered
- [x] `git diff --check`
- [x] Changed-line count: 1,347, below soft and hard caps
- [x] Architecture implementation review passed after moving rename behind its
  repository/service boundary
- [x] PR #1100 merged as `9b7abf2caaae6e9af12d77a096f56771344da4ad`

### Step 12/16

- [x] Adapter `0.1.0`, DeepSeek Harness `0.1.1-rc.2`, and Node `24.19.0` pinned
- [x] All six official Node archive SHA-256 values pinned in source
- [x] `npm run check`: lint, typecheck, 106 tests, 3 release-script tests, and build pass
- [x] Host `darwin-arm64` packaged archive passes checksum/signature verification,
  SBOM/license validation, native loading, relocation, and full ACP lifecycle smoke
- [x] Architecture implementation review passed after adding independent Node digest pins
- [x] Final PR head `15a38ee`: all six matching-native package/smoke jobs,
  cross-repository conformance, and aggregate checksum-set verification pass
- [x] PR #9 merged as `b7bf472fd2f8df66bc04ba978d764598fc669b91`
- [x] Annotated `v0.1.0` tag points at the exact merge commit
- [x] Tag workflow `32772789900` passed all six package/smoke jobs and publication
- [x] Stable, non-draft [v0.1.0 release](https://github.com/sesori-ai/sesori-deepseek-acp/releases/tag/v0.1.0)
  publishes six archives plus `checksums.txt`; every GitHub asset digest matches
  its aggregate checksum entry

### Step 13/16

- [x] Stable `0.1.0` PATH floor and `0.1.1` managed version pinned after publication
- [x] All six immutable `v0.1.1` archive SHA-256 values pinned in a package-directory manifest
- [x] Explicit, supported PATH, then exact managed-runtime precedence uses shared runtime services
- [x] Install capability is platform-aware and disabled by an explicit adapter path
- [x] DeepSeek `check --state-dir` remains side-effect-free setup validation after runtime selection
- [x] `dart pub get`
- [x] DeepSeek `dart analyze --fatal-infos`
- [x] DeepSeek `dart test`: 35 tests pass
- [x] Shared managed-runtime provisioning selection/install/cleaner suite: 39 tests pass,
  covering checksum failure, abort, package adoption, and stale-version sweep
- [x] `git diff --check`
- [x] Architecture implementation review passed with no findings
- [x] Real managed-install smoke exposed npm `.bin` symlinks in `v0.1.0`; secure extraction rejected the archive before adoption
- [x] Runtime PR #10 merged as `4ae635d1c3a6a0829722e8363dd564cc582c1f6e`; annotated `v0.1.1` points at that exact commit
- [x] Tag workflow `32820418706` passes all six package jobs, aggregate verification, and publication
- [x] Stable, non-draft [v0.1.1 release](https://github.com/sesori-ai/sesori-deepseek-acp/releases/tag/v0.1.1)
  publishes six archives plus `checksums.txt`; every GitHub asset digest matches
  its aggregate checksum entry
- [x] Real managed install plus ACP smoke passes through download, checksum,
  secure extraction, package adoption, version/readiness probes, ACP health, and shutdown
- [x] Final changed-line count: 608, below the 1,250 soft target and 1,500 hard cap
- [x] PR #1109 opened against `main`
- [x] PR #1109 merged with all 14 checks passing

### Step 14/16

- [x] DeepSeek added to the built-in harness identity and bridge registry; OpenCode remains preferred default
- [x] Registered CLI exposes `--deepseek-bin`; exact registry identity fixture includes DeepSeek once
- [x] Client renders the bridge-supplied `DeepSeek` name with the generic plug in light and dark themes; metadata-free surfaces retain raw-ID fallback
- [x] Unknown plugin IDs retain generic-icon and raw-ID fallback behavior
- [x] README documents managed/PATH/explicit install precedence, local provider setup,
  `DSH_HOME` ownership, isolated Sesori session state, telemetry-off, and sandbox/approval defaults
- [x] No analytics event added: activation has no authoritative adoption outcome and backend identity is outside the approved analytics contract
- [x] DeepSeek opts into the bridge workspace `no_slop_linter`; 22 initial findings resolved to zero
- [x] DeepSeek package analysis and all 35 tests pass with the linter enabled
- [x] Bridge app analysis and 6 focused registry/CLI tests pass
- [x] Shared package analysis and all 361 tests pass
- [x] Module Prego analysis and 20 branding tests pass
- [x] Mobile and desktop shell analysis pass
- [x] Architecture implementation review passed with no findings
- [x] Synced with merged Step 13; focused bridge and client verification remains green
- [x] Final changed-line count: 293, below the 1,000 soft target and 1,500 hard cap
- [x] PR #1110 opened against `main`
- [x] PR #1110 merged with all 17 checks passing

### Step 15/16

- [x] Reconciled all ten affected regression documents with shipped DeepSeek behavior
- [x] Corrected DeepSeek bridge-acceptance, adapter-settlement, and detached-history ownership distinctions
- [x] Recorded isolated state/config ownership, standard/extension boundaries,
  generic presentation, local setup, and retained adapter artifacts
- [x] Kept real provider, relay/client, compatibility build-pair, deletion-residue,
  and complete packaged-host evidence pending Step 16
- [x] Markdown fences, local links, and all ten regression-document references valid
- [x] `git diff --check`
- [x] Final changed-line count: 176, below the 600 soft target and 1,500 hard cap
- [x] PR #1129 opened against `main`

Later implementation and live evidence is appended here by step. Never mark a
regression row passed without the boundary and matrix required by `PLAN.md`.
