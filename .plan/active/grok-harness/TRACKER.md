# Grok Build Harness Support Tracker

## Current State

- **Plan:** `.plan/active/grok-harness/PLAN.md`
- **Status:** Step 1/9 in PR
- **Current branch:** `grok-code-harness-inquiry`
- **Base:** `origin/main`
- **Architecture plan review:** approved 2026-08-27 after catalog ownership and auth-policy corrections
- **Open PR:** #1152 — <https://github.com/sesori-ai/sesori_apps_monorepo/pull/1152>
- **Local successor:** `grok-harness-step-2-scaffold`; released-binary research started and held locally

## Fixed Series

1. `🌱 [grok-harness] docs: plan Grok Build harness support [step 1/9]`
   - **State:** in PR #1152.
   - **Evidence:** current revision architecture-approved; released-binary facts, titles, paths, and whitespace pass.
2. `🌿 [grok-harness] feat(grok): scaffold the Grok plugin package [step 2/9]`
   - **State:** started locally; held until #1152 merges.
   - **Evidence:** isolated released 1.0.5 binary/version/help/initialize contract captured; package files not started.
3. `⚙️ [grok-harness] feat(grok): expose models and reasoning effort [step 3/9]`
   - **State:** not started.
4. `⚙️ [grok-harness] feat(grok): compose ACP sessions and turns [step 4/9]`
   - **State:** not started.
5. `⚙️ [grok-harness] feat(grok): add direct-CLI setup and lifecycle [step 5/9]`
   - **State:** not started.
6. `⚙️ [grok-harness] feat(bridge): activate Grok Build [step 6/9]`
   - **State:** not started.
7. `🌿 [grok-harness] feat(client): brand Grok Build [step 7/9]`
   - **State:** not started.
8. `🌱 [grok-harness] docs: reconcile Grok regression coverage [step 8/9]`
   - **State:** not started.
9. `⚙️ [grok-harness] test: verify Grok and retire the plan [step 9/9]`
   - **State:** not started.

## Step 1 Checklist

- [x] Inspect repository instructions, current ACP/plugin architecture, Hermes precedent, and regression rules.
- [x] Verify official Grok agent mode and current source-level ACP capabilities.
- [x] Record the released stable pointer (`1.0.5`) and source snapshot identifiers.
- [x] Assess analytics; no new event justified.
- [x] Draft fixed scope, ownership, complexity budget, cleanup assessment, PR titles, and retirement matrix.
- [x] Run architecture plan review through a sub-agent.
- [x] Apply valid in-scope review findings and record the result.
- [x] Validate the released 1.0.5 binary and correct the plan's auth/state assumptions.
- [x] Re-run architecture plan review for the material shared auth-policy hook; current revision approved.
- [x] Revalidate Markdown paths/titles and `git diff --check` after that correction.
- [x] Address all actionable #1152 review feedback and leave prefixed thread replies.
- [x] Commit, push, and open Step 1 PR (#1152).
- [x] Start the PR monitor.
- [x] Create the Step 2 successor branch in this worktree and begin released-binary research locally.

## Decisions And Evidence

- 2026-08-27: Initial delivery is direct CLI only. Managed install is excluded because xAI owns an official installer
  and self-update channel; Sesori has no current need to duplicate that lifecycle.
- 2026-08-27: Grok launches without yolo/always-approve, with leader attachment and auto-update disabled.
- 2026-08-27: Runtime setup inspection is intentionally not an authentication proof. The ACP handshake remains the
  authority across Grok login, API key, enterprise, and custom-model credentials.
- 2026-08-27: Grok's removed-from-stable-ACP model surface remains package-local rather than changing generic ACP.
- 2026-08-27: No database, transport, managed-runtime, analytics, or Grok-specific coordination state is planned.
- 2026-08-27: Isolated Grok 1.0.5 (`5115b46bc909`) accepts
  `--no-auto-update agent --no-leader stdio`, advertises ACP v1 list/load/resume/close, image false, embedded context,
  two structurally valid model entries, and the documented reasoning metadata. Initialize creates ordinary Grok-owned
  home/config/log/session-directory state but no session row.
- 2026-08-27: A logged-out isolated process advertises only interactive `grok.com`. The generic first-nonterminal rule
  would invoke it and wait for login input. The plan now adds one optional advertised-auth allowlist hook and allows
  only Grok's `xai.api_key` and `cached_token`; an interactive-only list fails as authentication-required before a call.
- 2026-08-27: Architecture plan review passed its pre-review gate and rejected one A2 ownership issue: the options
  service also owned last-good catalog state. The plan now gives that state and its replace/retain invariant solely to
  `GrokCatalogTracker`; the service consumes the tracker and stores no duplicate. Per repository policy, the valid
  finding was applied directly. A later material auth-policy change justified one fresh review of the complete revised
  plan; that current revision was approved with no findings.
- 2026-08-27: #1152 review feedback added a configuration repository between service and API, moved
  workspace/Makefile/CI registration into Step 2, moved production hook wiring into Step 4, preserved useful local
  diagnostic paths, and
  scheduled final Git-scoped architecture implementation review. The plan retains built-in `Harness.grok` branding
  because identity/presentation is not backend behavior and the existing client contract intentionally maps built-ins;
  it also retains penultimate regression reconciliation because that is the repository's mandated durable-plan flow.

## Required Final Evidence

Step 9 must record:

- exact Grok release, bridge build/commit, bridge host, client build/platform, and bounded account capabilities;
- automated package/app/client commands and results;
- L3 matrix results for setup/lifecycle, projects/sessions, creation/options, turns, history/recovery,
  permissions, tools/file changes, archiving/deletion, and compatibility/presentation;
- privacy-safe live evidence, first divergent boundary for failures, and cleanup;
- `Pass`, `Partial`, `Fail`, `Blocked`, or `Not run` for every matrix row.

The plan stays active unless all required rows pass or the user explicitly accepts a named reduction in `PLAN.md`.
