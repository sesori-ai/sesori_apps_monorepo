# GitHub Copilot Harness Tracker

Plan: [PLAN.md](PLAN.md)

## Delivery

- [x] **Step 1/7** — `🌱 [github-copilot-harness] docs: plan GitHub Copilot harness support [step 1/7]`
  - State: merged
  - PR: [#1154](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1154)
  - Evidence: upstream ACP/release/license research and no-prompt `1.0.80` protocol probe recorded in the plan
- [x] **Step 2/7** — `⚙️ [github-copilot-harness] feat(copilot): add the ACP harness package [step 2/7]`
  - State: merged
  - PR: [#1155](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1155)
  - Evidence: package tests and analyzer pass; architecture implementation review passed
- [x] **Step 3/7** — `⚙️ [github-copilot-harness] feat(copilot): add runtime setup and lifecycle [step 3/7]`
  - State: merged
  - PR: [#1158](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1158)
  - Evidence: 5 Copilot package tests, 266 shared ACP tests, and 47 focused app tests pass; owning analyzers report no issues; Makefile verification includes the package; live `1.0.80` probes confirmed authenticated scratch discovery and `session/set_config_option`; architecture implementation review passed
- [x] **Step 4/7** — `⚙️ [github-copilot-harness] feat(copilot): install the managed Copilot CLI [step 4/7]`
  - State: merged
  - PR: [#1159](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1159)
  - Evidence: 13 package tests pass; analyzer reports no issues; all six official `1.0.80` asset names and SHA-256 digests match the GitHub release API; architecture implementation review passed
- [x] **Step 5/7** — `⚙️ [github-copilot-harness] feat(app): activate and brand GitHub Copilot [step 5/7]`
  - State: merged
  - PR: [#1161](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1161)
  - Evidence: bridge app analyzer and 6 focused registration/CLI tests pass; shared analyzer and 8 plugin-identity compatibility tests pass; module_prego analyzer and 24 branding/fallback tests pass; downstream mobile analyzer reports no issues; architecture implementation review passed
- [x] **Step 6/7** — `🌱 [github-copilot-harness] docs: document Copilot regression coverage [step 6/7]`
  - State: merged
  - PR: [#1163](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1163)
  - Evidence: all 10 affected feature documents define Copilot behavior,
    level boundaries, exploration, failure signals, limitations, and sources;
    required headings and L1-L5 tables are intact; review corrections aligned
    image capability, permission replay, plan visibility, lifecycle automation,
    and fail-soft pagination with production behavior
- [x] **Step 7/7** — `🌱 [github-copilot-harness] docs: verify and retire the Copilot plan [step 7/7]`
  - State: completed on `github-copilot-harness/step-7-verify-retire`; the
    duplicate cold replay blocker was fixed in #1171 and targeted verification passed
  - PR: pending
  - Evidence: see the privacy-safe matrix below; unavailable environmental variants remain recorded as accepted Partial coverage

## Decisions

- Use native ACP, not the Copilot SDK.
- Require local/out-of-band authentication in v1; do not run terminal-auth commands from the bridge.
- Pin managed runtime `1.0.80`; accept compatible PATH versions `>=1.0.78`.
- Launch with `--no-auto-update --acp`.
- Keep Copilot `ask_user` unsupported until upstream forwards it over ACP.
- Map standard Copilot model, mode, and thought-level options; keep its permission config backend-private.
- Do not read Copilot credential or private session files.
- Do not bundle Copilot binaries; managed installation downloads the official unmodified asset directly from GitHub after explicit user intent.
- Fix the sole release-blocking replay failure before retirement; accept the unavailable host/profile/version variants as honest non-blocking Partial coverage after affected checks pass.

## Step 7 Verification Evidence

Execution date: 2026-08-28.

- Copilot CLI: managed `1.0.80`, with all six checked-in archive digests matching the official stable GitHub release.
- Bridge: source-run production tree from the Step 6 branch for the full matrix;
  targeted post-fix suites and live replay reran on merged `origin/main` at
  `be45cf8bb4`.
- Host: macOS 26.6.2, arm64; Dart 3.13.1 and Flutter 3.47.1.
- Client: Flutter debug build on the `sesori-dev-1` iPhone 17 simulator,
  iOS 26.5; traffic traversed client → relay → isolated slot-1 bridge → Copilot.
- Account: an already authenticated Copilot entitlement was used without
  inspecting identity, tier, credentials, settings, or private history. It
  advertised Agent, Plan, and Autopilot modes plus 38 commands, but no selectable
  model or reasoning catalog.
- Privacy: repository evidence contains no prompts, transcripts, paths, tokens,
  account/session identifiers, image bytes, or raw logs.

| Matrix row | Result | Privacy-safe evidence |
|---|---|---|
| Plugin runtime installation | **Pass** | Client install progressed from missing runtime to ready/active `1.0.80`; official metadata matched all six archives; compatible PATH won over managed selection; explicit current, too-old, and unbranded executables classified correctly; checksum failure, cancellation, placement, provisioning, and superseded cleanup automation passed. |
| Plugin setup and lifecycle | **Partial** | Missing/managed/PATH/explicit/too-old/unrecognized setup, capability gating, enable/disable/restart, plugin-local SIGKILL degradation, demand reconnect, clean shutdown, and another harness remaining available passed. A live unauthenticated normal profile and alternate host were unavailable. |
| Projects and sessions | **Partial** | Explicit import and unchanged re-import completed, normal reads stayed database-only while Copilot was disabled, and local attribution remained `copilot`. The live catalog fit one page; cancellation and later-page fail-soft behavior remained automated-only. |
| Session creation and options | **Pass** | The phone created a dedicated Copilot session; Agent and Plan applied and persisted; an exact advertised command executed. No model/reasoning values were invented when this account advertised none; automated stale-selection, model-specific reasoning, no-mode, and authentication failure coverage passed. |
| Session turns | **Pass** | Phone-visible text, tools, statuses, exact command, two simultaneously busy sessions, queued-prompt cancellation, abort cleanup, and a selected mode change passed. No reasoning was emitted by the available implicit model, which is not a failure under the documented boundary. |
| Session history and recovery | **Pass** | Plugin restart and unexpected process replacement recovered in the full run. After #1171, a fresh three-message live tool transcript retained the identical semantic multiset after a clean bridge restart and first cold read, with zero extra duplicates. |
| Questions and permissions | **Pass** | A real Copilot permission exposed Once, Reject, and Always; each outcome behaved correctly, rejection prevented mutation, abort retired a pending request, and no question capability was claimed. Copilot clarification arrived as normal text, consistent with the upstream `ask_user` limitation. |
| Attachments and images | **Partial** | The phone sent a 64×64 single-color PNG and Copilot identified it correctly. No model/account rejection was available to exercise. |
| Tools and file changes | **Pass** | Live completed and aborted tools, permission linkage, exact workspace mutation, and the phone's one-file `+1/-0` diff passed. After #1171, one terminal live tool remained one terminal tool after cold replay; the three-message semantic multiset and one-file `+1/-0` diff were unchanged. |
| Session archiving and deletion | **Partial** | Local deletion removed one session and its clean dedicated worktree; explicit re-import did not resurrect it. Standard close removed it from the public ACP catalog, so the tombstone was not challenged by a still-listed row and private retained history was not inspected. |
| Compatibility and branding | **Partial** | Automated unknown-id fallback and both theme assets passed; the phone rendered the exact GitHub Copilot name and white Primer icon in dark mode. An older-client/older-bridge build pair was unavailable. |

Automated verification passed with no analyzer issues: 13 Copilot tests, 267
shared ACP tests, 45 managed-runtime tests, 177 focused bridge-app tests, 26
shared wire tests, 124 client business-layer tests, 24 branding tests, and 213
focused mobile widget tests. The iOS simulator build also completed. After the
fix merged, the bridge app analyzer, 90 focused history and tool-recovery tests,
and 11 ACP replay tests passed.

Cleanup restored the pre-run YOLO and system-theme settings, stopped every test
bridge and owned Copilot process, deleted all disposable local sessions, hid
their project entries, and removed the final fixture and managed runtime.
Upstream Copilot history residue is retained because the public protocol has
close but no delete operation.

## Review And Verification

- Architecture plan review: approved after clarifying ACP lifecycle and bridge/client/shared ownership
- Architecture implementation review: required after each architecture-bearing implementation step, scoped to that step's branch against its target
- Final regression matrix: executed; both replay Fail rows passed after #1171, and the owner accepted the unavailable environmental variants as non-blocking Partial coverage for retirement
