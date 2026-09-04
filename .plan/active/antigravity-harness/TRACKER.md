# Antigravity ACP Harness Tracker

## Current State

- **Plan:** `.plan/active/antigravity-harness/PLAN.md`
- **Status:** Step 1/12 merged; Step 2/12 in progress locally
- **Base:** `origin/main` at `3d65382e8cd4e33bbaedaf6c6a679a24ad211320`
- **Current branch:** `antigravity-harness-step-2-runtime-contract`
- **Merged PR:** [#1285](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1285) (Step 1)
- **Next action:** commit, push, and open the verified Step 2 PR; retain local-pair WIP for Step 3

## Fixed PR Series

- [x] Step 1/12 — `🌱 [antigravity-harness] docs: plan Antigravity ACP support [step 1/12]`
- [ ] Step 2/12 — `⚙️ [antigravity-harness] feat(antigravity): pin the official ACP runtime contract [step 2/12]`
- [ ] Step 3/12 — `⚙️ [antigravity-harness] feat(antigravity): resolve local runtime pairs [step 3/12]`
- [ ] Step 4/12 — `🚧 [antigravity-harness] feat(auth): accept browser authentication continuations [step 4/12]`
- [ ] Step 5/12 — `🚧 [antigravity-harness] feat(client): add remote browser authentication handoff [step 5/12]`
- [ ] Step 6/12 — `🚧 [antigravity-harness] feat(antigravity): add isolated profile authentication [step 6/12]`
- [ ] Step 7/12 — `🚧 [antigravity-harness] feat(antigravity): map ACP options and interactions [step 7/12]`
- [ ] Step 8/12 — `🚧 [antigravity-harness] feat(antigravity): compose persistent ACP sessions [step 8/12]`
- [ ] Step 9/12 — `⚙️ [antigravity-harness] feat(bridge): activate local Antigravity runtimes [step 9/12]`
- [ ] Step 10/12 — `🚧 [antigravity-harness] feat(antigravity): install the managed ACP runtime [step 10/12]`
- [ ] Step 11/12 — `🌱 [antigravity-harness] docs: complete guidance and regression coverage [step 11/12]`
- [ ] Step 12/12 — `🚧 [antigravity-harness] test: verify Antigravity and retire the plan [step 12/12]`

## Step 1 Checklist

- [x] Inspect shared ACP transport, plugin hooks, approval registry, session options, and replay behavior.
- [x] Inspect plugin descriptor/runtime/install patterns and app/client registration seams.
- [x] Inspect the official ACP registry manifest and Google docs.
- [x] Inspect T3 Code PR #9348 as corroborating released-agent evidence.
- [x] Record local-first then managed-install delivery order.
- [x] Record personal OAuth, remote loopback callback, isolated profile, supervised permission, and five-host decisions.
- [x] Write the implementation plan and retirement matrix.
- [x] Complete one architecture plan review and apply valid findings.
- [x] Validate plan paths, fixed titles, Markdown whitespace, and worktree diff.
- [x] Commit, push, open the Step 1 PR, and start the PR monitor.
- [x] Create the Step 2 successor branch and begin the package/runtime-contract work locally.

## Step 2 Checklist

- [x] Sync the successor branch to merged Step 1 and preserve the reviewed plan corrections.
- [x] Independently download, hash, inspect, and initialize-probe the official macOS arm64 runtime pair.
- [x] Separate shared ACP initialize-only and authenticate operations without changing combined callers.
- [x] Add the inactive package, pair/launch facts, generated initialize DTO, release facts, and Layer-1 ACP probe API.
- [x] Add the package to bridge workspace, Makefile, and CI discovery inventories without app registration.
- [x] Cover official target/launch facts, generated parsing, malformed/timeout/abort/exit handling, and cleanup.
- [x] Split local pair resolution into Step 3 after the combined diff measured above the 1,500-line cap.
- [x] Complete architecture implementation review and apply the generated-DTO boundary finding.
- [x] Run final focused analysis/tests and Git/Markdown validation.
- [ ] Commit, push, open the Step 2 PR, and start the PR monitor.

## Architecture Reviews

- **Plan review:** completed 2026-09-03. The reviewer rejected the first draft with six concrete findings across
  separation of concerns, composition, suffix naming, bridge layers, client DTO mapping, and presentation ownership.
  All valid findings were applied directly; repository policy does not call for re-reviewing those fixes.
- **PR review:** first wave of eight findings applied on 2026-09-03: explicit environment inheritance, service-owned
  auth/options workflows, generic artwork, pre-activation disclosure, extraction budgets, L5 Full scope, and shutdown
  install-abort semantics. The second wave adds service-owned runtime policy, plugin-owned identity, coherent Step 6/7
  composition, and host-backed profile chmod. The third wave extends per-asset archive budgets through traversal
  preflight and documents fresh-process first-session default-model behavior. The fourth wave adds metadata/setup
  service ownership, Layer-2 protocol mapping, per-feature regression updates, and current-client-only new auth. The
  fifth wave adds typed catalog/interaction mapping and policy ownership, staging-contained managed validation, and a
  backend-neutral residency-preference hook. A follow-up aligned the authentication-operation dependency list. Four
  post-merge findings add layered interaction replies, Layer-2 auth-line mapping, useful local model diagnostics, and
  atomic host-store injection for profile settings; these corrections travel with Step 2.
- **Step 2 implementation review:** first pass rejected handwritten parsing of newly exposed ACP initialize fields. The
  shared parser additions were reverted, and Layer 1 now maps into generated Antigravity Freezed/JSON DTOs before the
  repository. The second and final pass approved the corrected architecture with no remaining violations.
- **Series implementation review:** required in Step 12 over the Step 2-10 production range; maximum two passes

## Locked Decisions

- Official Google `antigravity-acp` registry pair only; no `agy` wrapper or community adapter.
- Plugin ID/name: `antigravity` / `Antigravity`, owned by `sesori_plugin_antigravity`; no shared `Harness` case.
- Exact initial pin: registry `1.0.0`, agent `agy_acp_server_20260818_01_RC01`.
- Personal OAuth only in initial support; other advertised auth methods remain documented gaps.
- Private profile under plugin state; no default-profile credential copy. Settings use the same plugin-scoped atomic
  host store across authentication and live hosting, and POSIX setup applies owner-only mode before launch.
- Remote auth uses pure-Dart generic loopback-input validation, then independent exact plugin validation before relay.
- New browser authentication requires a current mobile/desktop client; older clients retain already-authenticated use
  and receive an update-client hint, with no claimed CLI/bridge-host login.
- Agent mode is always `default`; `allow_always`, `auto_edit`, `yolo`, and dangerous skip are unavailable.
- Before a process observes a model catalog from new/load/resume, options are partial and the first session uses the
  account default; no persistent scratch Google session is created for discovery. Raw catalogs and permissions cross
  a Layer-2 mapper before policy, and outbound interaction replies cross a connection-scoped repository/service path.
  Bounded model IDs remain in local failure diagnostics only; analytics carry none.
- Shared ACP retains load-first residency by default; Antigravity selects resume-first through a backend-neutral hook.
- Managed exact probing uses an owner-only disposable home inside staging before atomic placement; it cannot touch the
  persistent profile, authenticate, or create a session.
- Local pair support lands before managed install.
- Managed targets: macOS arm64, Linux x64/arm64, Windows x64/arm64; macOS x64 unsupported.
- No database migration and no Antigravity-specific analytics.

## Retirement Coverage

Highest required level: **L5 Full**, including the complete applicable documented L1-L5 catalog.

Required target rows:

| Target | Local pair | Managed install | ACP identity | Process smoke | Status |
| --- | --- | --- | --- | --- | --- |
| macOS arm64 | Required | Required | Required | Required | Not run |
| Linux x64 | Required | Required | Required | Required | Not run |
| Linux arm64 | Required | Required | Required | Required | Not run |
| Windows x64 | Required | Required | Required | Required | Not run |
| Windows arm64 | Required | Required | Required | Required | Not run |
| macOS x64 | Unsupported guidance | Must be absent | N/A | N/A | Not run |

Required representative end-to-end rows:

| Flow | Boundary | Status |
| --- | --- | --- |
| Same-host personal OAuth | Google -> bridge host -> official agent -> desktop | Not run |
| Remote personal OAuth | Google -> client -> pasted redirect -> bridge loopback -> agent | Not run |
| Model/session create and turn | client -> relay -> bridge -> official agent -> Google | Not run |
| Permission and interaction question | official agent -> bridge -> client -> exact response | Not run |
| History, cold resume, bridge restart | isolated profile -> ACP load/resume -> client | Not run |
| Managed install rollback/shutdown abort | Google archive -> shared installer -> validated active pair | Not run |
| Unknown/older-client fallback | shared wire/plugin identity -> client presentation | Not run |

Antigravity-affected regression documents are listed in Step 11 of `PLAN.md`. Step 12 additionally collects every
applicable catalog entry from L1 through L5 across its required plugin/platform boundaries.

## Evidence Log

- 2026-09-03 — Official registry manifest pinned at
  `agentclientprotocol/registry@536e378b70a7a6d5f078a9160180e3569a23253c`.
- 2026-09-03 — T3 Code PR #9348 / commit `fff33f9e851912363c5b1f3ac65598be35eb5f0d` reviewed for
  released-agent auth, pair, protocol, model, interaction, and tool behavior.
- 2026-09-03 — No repository production files changed before Step 1 planning.
- 2026-09-03 — Architecture plan review rejected the first draft with six concrete A3/A7/A8, B-Bridge, B-Client,
  and naming findings. The revised plan moves validation out of UI, maps wire DTOs in `PluginRepository`, adds explicit
  Layer-1/repository boundaries, fixes the launch-spec Builder suffix, and records constructor/composition ownership.
- 2026-09-03 — The official macOS arm64 archive matched 314,500,221 bytes and SHA-256
  `f122ca7e7030a27f9649da4cf1a7d80e12c48c5f6118ff35affc34d56cbf83dd`; its only members match the expected pair.
  Isolated initialize confirmed ACP v1, exact identity/version, load/list/resume/logout, absent close, and four
  authentication IDs.
- 2026-09-03 — PR #1285 first review produced eight actionable plan findings. All were applied without expanding into
  a user-facing install-cancel flow: shutdown/interruption recovery is the supported install-abort boundary.
- 2026-09-03 — PR #1285 second review produced four actionable findings. Runtime decisions now belong to
  `AntigravityRuntimeService`; the ID remains plugin-owned; plugin/descriptor creation is coherent in Step 7; and
  profile chmod uses an injected host-backed lower boundary.
- 2026-09-03 — PR #1285 third review produced two actionable findings. Each archive's required command budget now
  covers traversal preflight and extraction, and model discovery honestly reports partial/default-only state until a
  real new/load/resume response provides the catalog.
- 2026-09-04 — PR #1285 fourth review produced five actionable findings. Metadata recovery and combined setup now have
  explicit service owners; protocol normalization is Layer 2; behavior-changing PRs update regression contracts when
  they land; and new authentication requires a current client with an explicit update hint.
- 2026-09-04 — PR #1285 fifth review produced four actionable findings. The protocol mapper now normalizes
  catalogs and permission requests for owning services. Managed exact validation uses a disposable staging home before
  placement, and a backend-neutral ACP hook preserves load-first behavior while Antigravity selects resume-first.
- 2026-09-04 — PR #1285 merged as `3d65382e8c`; a final post-merge review found four valid plan gaps. Step 2 carries
  layered reply dispatch, Layer-2 auth parsing, bounded local model-ID diagnostics, and atomic profile settings.
- 2026-09-04 — Step 2 architecture review rejected handwritten additions to the shared ACP initialize parser. The
  correction keeps legacy parsing unchanged, maps raw initialize data to generated typed DTOs inside Layer 1, and
  exposes only typed values to Layer 2. The second review approved the corrected architecture.
- 2026-09-04 — The combined runtime-contract WIP measured 2,209 changed lines, so local pair resolution moved to Step 3
  and the final guidance/regression steps were combined to retain twelve PRs. No behavior or retirement coverage was
  dropped.
- 2026-09-04 — Split Step 2 verification passed: generated output is fresh, Antigravity analysis and 10 tests pass,
  shared ACP analysis and 305 tests pass, and Git/Markdown validation reports no source-width or whitespace failures.
