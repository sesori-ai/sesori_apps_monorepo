# Grok Build Harness Support Tracker

## Current State

- **Plan:** `.plan/active/grok-harness/PLAN.md`
- **Status:** Steps 1-5/9 merged; Step 6/9 in PR; Step 7/9 implemented locally
- **Current branch:** `grok-harness-step-7-branding`
- **Base:** `grok-harness-step-6-activation` (PR #1177)
- **Architecture plan review:** approved 2026-08-27 after catalog ownership and auth-policy corrections
- **Merged predecessor:** #1175 — <https://github.com/sesori-ai/sesori_apps_monorepo/pull/1175>
- **Open PR:** #1177 — <https://github.com/sesori-ai/sesori_apps_monorepo/pull/1177>
- **Local successor:** `grok-harness-step-7-branding`; client branding and support notes under verification

## Fixed Series

1. `🌱 [grok-harness] docs: plan Grok Build harness support [step 1/9]`
   - **State:** merged in #1152.
   - **Evidence:** architecture-approved plan; released-binary facts, titles, paths, and whitespace passed.
2. `🌿 [grok-harness] feat(grok): scaffold the Grok plugin package [step 2/9]`
   - **State:** merged in #1156.
   - **Evidence:** workspace package, launch spec, typed fixtures/codegen, tests/analyzer, LSP, and budget.
3. `⚙️ [grok-harness] feat(grok): expose models and reasoning effort [step 3/9]`
   - **State:** merged in #1160.
4. `⚙️ [grok-harness] feat(grok): compose ACP sessions and turns [step 4/9]`
   - **State:** merged in #1169.
   - **Evidence:** generic auth allowlist, Grok plugin composition, 270 ACP tests, 42 Grok tests, affected-package
     analyzers, LSP diagnostics, two architecture approvals, and the 1,500-line budget pass.
5. `⚙️ [grok-harness] feat(grok): add direct-CLI setup and lifecycle [step 5/9]`
   - **State:** merged in #1175.
6. `⚙️ [grok-harness] feat(bridge): activate Grok Build [step 6/9]`
   - **State:** in PR #1177.
7. `🌿 [grok-harness] feat(client): brand Grok Build [step 7/9]`
   - **State:** implemented locally; held until #1177 merges.
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

## Step 2 Checklist

- [x] Validate the official 1.0.5 artifact, build ID, SHA-256, launch arguments, and initialize structure.
- [x] Add `sesori_plugin_grok` to workspace, Makefile/CI inventory, bridge module docs, and package docs.
- [x] Add Grok identity and the dedicated no-update/no-leader ask-mode ACP launch spec.
- [x] Add typed Freezed model/reasoning DTOs plus privacy-safe synthetic initialize/session fixtures.
- [x] Generate source; do not hand-edit generated files.
- [x] Run package tests, fatal-info analysis, and Dart LSP diagnostics.
- [x] Run architecture implementation review for `origin/main...HEAD`; approved with no findings.
- [x] Keep the measured change below the 1,500-line soft cap by leaving initialize/session envelope DTOs for Step 3.
- [x] After #1152 merged, sync to `origin/main`, publish PR #1156, and start its monitor.

## Step 3 Checklist
- [x] Add typed envelopes, initialize-only probing, exact selection writes, and cause-preserving failures.
- [x] Keep catalog and selection state in their trackers; preserve opaque models and canonical effort values.
- [x] Cover hostile wire siblings, tuple fallbacks, default reset, stale tracked state, and failed writes.
- [x] Pass 267 ACP and 27 Grok tests, analysis, LSP, line/diff checks, and two architecture reviews.
- [x] Accept 1,821 lines: audit-required boundary/transition coverage takes precedence over the soft cap.
- [x] Complete hostile wire, state-invariant, and post-fix general correctness reviews; final verdict approved.

## Step 4 Checklist

- [x] Add an optional generic advertised-auth allowlist while preserving every existing ACP default.
- [x] Cover allowed, interactive-only, and rejected allowlisted authentication outcomes.
- [x] Compose `GrokPlugin` over the shared ACP mapper, trackers, transport, and Step 3 collaborators.
- [x] Wire live initialize/new/load capture, exact pre-turn selection, one provider, commands, and connection reset.
- [x] Enable stop-and-send and fail-closed selection without Grok-specific permission or event machinery.
- [x] Cover identity validation, two sessions, accepted-send timing, cancellation, reasoning/tools, permissions, close,
  reconnect, disposal, stale prevalidation, loaded-effort replay, and selection failure; retain history suppression.
- [x] Keep replay initialize validation pure and validate effort-only tuples after a stored session becomes resident.
- [x] Materialize replay with one complete selection tuple; expose no externally mutable collector selection fields.
- [x] Remove redundant Grok cleanup/command overrides; the shared tracker and command path remain authoritative.
- [x] Run 270 ACP, 42 Grok, and 41 DeepSeek tests plus affected-package analyzers, LSP, and whitespace checks.
- [x] Keep the measured Step 4 change below the 1,500-line soft cap (currently 1,143 lines).
- [x] Run initial and final architecture implementation reviews over Step 4 against Step 3; both approved.
- [x] Complete the post-rebase general correctness review; final verdict approved.
- [x] Publish Step 4 as PR #1169 after #1160's merge and start its PR monitor.

## Step 5 Checklist

- [x] Add `--grok-bin`, the frozen 1.0.5 floor/target, and explicit-before-PATH selection.
- [x] Classify missing, malformed, outdated, current, and bounded-output version probes without reading credentials.
- [x] Revalidate the selected runtime in `ensureRuntime`; never install, update, or fall back from an explicit path.
- [x] Compose one host-process-backed `GrokPlugin`/`AcpBridgePlugin` with bounded eager connection.
- [x] Surface local `grok login`/headless-credential guidance while isolating auth/start/crash degradation to Grok.
- [x] Cover setup, provisioning, abort, auth rejection, crash/reconnect, reported version, and owned shutdown.
- [x] Pass 52 Grok tests, fatal-info analysis, LSP diagnostics, whitespace, and authored line-width checks.
- [x] Keep the measured Step 5 change below the 1,500-line soft cap (currently 845 lines).
- [x] Run architecture implementation review over Step 5 against Step 4; approved with no findings.
- [x] Commit the completed successor locally; do not publish before #1169 merges.
- [x] Rebase onto merged #1169, reverify, publish PR #1175, and start its monitor.

## Step 6 Checklist

- [x] Add the Grok package dependency and register `GrokPluginDescriptor` only at the app composition point.
- [x] Add `Harness.grok`; keep plugin IDs string-based on transport and preserve unknown-client fallbacks.
- [x] Keep OpenCode preferred while making Grok eligible by default and startable only on demand after setup.
- [x] Cover the exact built-in registry and namespaced `--grok-bin` CLI option.
- [x] Update app composition/runtime inventories and reconcile missing Copilot, DeepSeek, and Grok architecture edges.
- [x] Record activation-specific Grok setup/auth/lifecycle regression behavior; Step 8 retains full reconciliation.
- [x] Add no analytics event; generic plugin lifecycle outcomes remain authoritative.
- [x] Pass app fatal-info analysis, 7 focused app tests, shared analysis, 392 shared tests, pub resolution, and LSP.
- [x] Keep the measured Step 6 change below the 1,500-line soft cap (currently 172 lines).
- [x] Run architecture implementation review over Step 6 against Step 5; approved with no findings.
- [x] Commit the completed successor locally; do not publish before #1175 merges.
- [x] Rebase onto merged #1175, reverify, publish PR #1177, and start its monitor.

## Step 7 Checklist

- [x] Source both theme marks byte-for-byte from xAI's official asset package and record archive/file hashes.
- [x] Reject scripts, external references, and metadata; preserve the supplied black/white artwork without alteration.
- [x] Map `Harness.grok` to theme-appropriate marks and the `Grok Build` name while retaining generic fallback.
- [x] Cover light/dark mapping, display name, exact geometry, theme contrast, safety, and unknown IDs.
- [x] Document the supported harness, 1.0.5 floor, official install, explicit path, local auth, ask mode, text-only
  prompts, model/reasoning selection, import, and retained upstream rows after local deletion.
- [x] Add no analytics event; existing generic plugin lifecycle outcomes remain sufficient.
- [x] Pass client pub resolution, 245 Prego tests, fatal-info analysis for Prego/mobile/desktop, LSP, and SVG checks.
- [x] Keep the measured Step 7 change below the 1,500-line soft cap (currently 108 lines).
- [x] Skip architecture review because this is localized presentation, static assets, tests, and documentation only.
- [x] Commit the completed successor locally; do not publish before #1177 merges.

## Decisions And Evidence

- 2026-08-28: Repeated substantive feedback exposed an incomplete parser/selection invariant matrix. The PR was removed
  from readiness and the monitor paused while hostile wire, state-transition, and general-correctness audits ran.
- 2026-08-28: The consolidated correction masks irrelevant envelope branches, preserves valid catalog siblings,
  rejects malformed owned containers, rejects stale tracked models, keeps model/effort as one tuple, and distinguishes
  explicit model-default reset from omitted selection. Official Grok source confirms a bare model switch resolves that
  model's declared default effort; explicit effort remains an override. Malformed optional effort lists remain fail-soft
  by plan: preserve the model with no variants, while malformed catalog/model containers reject.
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
- 2026-08-27: Follow-up #1152 feedback correctly identified that variants carry only strings. The plan now displays
  exact canonical reasoning values and explicitly defers Grok's separate labels/descriptions instead of implying a
  label-bearing transport/UI seam.

## Required Final Evidence

Step 9 must record:

- exact Grok release, bridge build/commit, bridge host, client build/platform, and bounded account capabilities;
- automated package/app/client commands and results;
- L3 matrix results for setup/lifecycle, projects/sessions, creation/options, turns, history/recovery,
  permissions, tools/file changes, archiving/deletion, and compatibility/presentation;
- privacy-safe live evidence, first divergent boundary for failures, and cleanup;
- `Pass`, `Partial`, `Fail`, `Blocked`, or `Not run` for every matrix row.

The plan stays active unless all required rows pass or the user explicitly accepts a named reduction in `PLAN.md`.
