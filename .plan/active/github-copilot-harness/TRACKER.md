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
- [ ] **Step 4/7** — `⚙️ [github-copilot-harness] feat(copilot): install the managed Copilot CLI [step 4/7]`
  - State: in review
  - PR: [#1159](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1159)
  - Evidence: 13 package tests pass; analyzer reports no issues; all six official `1.0.80` asset names and SHA-256 digests match the GitHub release API; architecture implementation review passed
- [ ] **Step 5/7** — `⚙️ [github-copilot-harness] feat(app): activate and brand GitHub Copilot [step 5/7]`
  - State: implemented and verified locally on `github-copilot-harness/step-5-activate`; waiting for Step 4 to merge
  - PR: pending
  - Evidence: bridge app analyzer and 6 focused registration/CLI tests pass; shared analyzer and 8 plugin-identity compatibility tests pass; module_prego analyzer and 24 branding/fallback tests pass; downstream mobile analyzer reports no issues; architecture implementation review passed
- [ ] **Step 6/7** — `🌱 [github-copilot-harness] docs: document Copilot regression coverage [step 6/7]`
  - State: not started
  - PR: pending
- [ ] **Step 7/7** — `🌱 [github-copilot-harness] docs: verify and retire the Copilot plan [step 7/7]`
  - State: not started
  - PR: pending

## Decisions

- Use native ACP, not the Copilot SDK.
- Require local/out-of-band authentication in v1; do not run terminal-auth commands from the bridge.
- Pin managed runtime `1.0.80`; accept compatible PATH versions `>=1.0.78`.
- Launch with `--no-auto-update --acp`.
- Keep Copilot `ask_user` unsupported until upstream forwards it over ACP.
- Map standard Copilot model, mode, and thought-level options; keep its permission config backend-private.
- Do not read Copilot credential or private session files.
- Do not bundle Copilot binaries; managed installation downloads the official unmodified asset directly from GitHub after explicit user intent.

## Review And Verification

- Architecture plan review: approved after clarifying ACP lifecycle and bridge/client/shared ownership
- Architecture implementation review: required after each architecture-bearing implementation step, scoped to that step's branch against its target
- Final regression matrix: pending; see `PLAN.md`
