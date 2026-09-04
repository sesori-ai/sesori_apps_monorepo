# Antigravity ACP Harness Tracker

## Current State

- **Plan:** `.plan/active/antigravity-harness/PLAN.md`
- **Status:** Step 1/12 open for review; Step 2/12 in progress locally
- **Base:** `origin/main` at `a87f30ab98b07dd7262afba462a36d4fbcc2dd9a`
- **Current PR branch:** `antigravity-acp-plan`
- **Local successor:** `antigravity-harness-step-2-runtime-contract`
- **Open PR:** [#1285](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1285) (Step 1)
- **Next action:** monitor Step 1 while implementing and verifying Step 2 locally

## Fixed PR Series

- [ ] Step 1/12 — `🌱 [antigravity-harness] docs: plan Antigravity ACP support [step 1/12]`
- [ ] Step 2/12 — `⚙️ [antigravity-harness] feat(antigravity): pin the official ACP runtime contract [step 2/12]`
- [ ] Step 3/12 — `🚧 [antigravity-harness] feat(auth): accept browser authentication continuations [step 3/12]`
- [ ] Step 4/12 — `🚧 [antigravity-harness] feat(client): add remote browser authentication handoff [step 4/12]`
- [ ] Step 5/12 — `🚧 [antigravity-harness] feat(antigravity): add isolated profile authentication [step 5/12]`
- [ ] Step 6/12 — `🚧 [antigravity-harness] feat(antigravity): map ACP options and interactions [step 6/12]`
- [ ] Step 7/12 — `🚧 [antigravity-harness] feat(antigravity): compose persistent ACP sessions [step 7/12]`
- [ ] Step 8/12 — `⚙️ [antigravity-harness] feat(bridge): activate local Antigravity runtimes [step 8/12]`
- [ ] Step 9/12 — `🚧 [antigravity-harness] feat(antigravity): install the managed ACP runtime [step 9/12]`
- [ ] Step 10/12 — `🌱 [antigravity-harness] docs: complete Antigravity product guidance [step 10/12]`
- [ ] Step 11/12 — `🌱 [antigravity-harness] docs: reconcile Antigravity regression coverage [step 11/12]`
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

## Architecture Reviews

- **Plan review:** completed 2026-09-03. The reviewer rejected the first draft with six concrete findings across
  separation of concerns, composition, suffix naming, bridge layers, client DTO mapping, and presentation ownership.
  All valid findings were applied directly; repository policy does not call for re-reviewing those fixes.
- **PR review:** first wave of eight findings applied on 2026-09-03: explicit environment inheritance, service-owned
  auth/options workflows, generic artwork, pre-activation disclosure, extraction budgets, L5 Full scope, and shutdown
  install-abort semantics. The second wave adds service-owned runtime policy, plugin-owned identity, coherent Step 6/7
  composition, and host-backed profile chmod. The third wave extends per-asset archive budgets through traversal
  preflight and documents fresh-process first-session default-model behavior. The fourth wave adds metadata/setup
  service ownership, Layer-2 protocol mapping, per-feature regression updates, and current-client-only new auth.
- **Implementation review:** required in Step 12 over the Step 2-10 production range; maximum two passes

## Locked Decisions

- Official Google `antigravity-acp` registry pair only; no `agy` wrapper or community adapter.
- Plugin ID/name: `antigravity` / `Antigravity`, owned by `sesori_plugin_antigravity`; no shared `Harness` case.
- Exact initial pin: registry `1.0.0`, agent `agy_acp_server_20260818_01_RC01`.
- Personal OAuth only in initial support; other advertised auth methods remain documented gaps.
- Private profile under plugin state; no default-profile credential copy; POSIX setup applies owner-only mode through
  an injected host-backed command boundary before agent launch.
- Remote auth uses pure-Dart generic loopback-input validation, then independent exact plugin validation before relay.
- New browser authentication requires a current mobile/desktop client; older clients retain already-authenticated use
  and receive an update-client hint, with no claimed CLI/bridge-host login.
- Agent mode is always `default`; `allow_always`, `auto_edit`, `yolo`, and dangerous skip are unavailable.
- Before a process observes a model catalog from new/load/resume, options are partial and the first session uses the
  account default; no persistent scratch Google session is created for discovery.
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
