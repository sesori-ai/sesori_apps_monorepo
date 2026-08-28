# Grok Build Harness Support Tracker

## Current State

- **Plan:** `.plan/completed/grok-harness/PLAN.md`
- **Status:** completed through Step 9/9 and retired on 2026-08-28; every required row passed without reduction
- **Current branch:** `grok-harness-step-9-verify-retire`
- **Base:** `origin/main` at `cb9baa91dd`
- **Architecture plan review:** approved 2026-08-27 after catalog ownership and auth-policy corrections
- **Merged predecessor:** #1181 — <https://github.com/sesori-ai/sesori_apps_monorepo/pull/1181>
- **Open PR:** #1190 — <https://github.com/sesori-ai/sesori_apps_monorepo/pull/1190>
- **Next action:** review and merge the final retirement PR

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
   - **State:** merged in #1177.
7. `🌿 [grok-harness] feat(client): brand Grok Build [step 7/9]`
   - **State:** merged in #1179.
8. `🌱 [grok-harness] docs: reconcile Grok regression coverage [step 8/9]`
   - **State:** merged in #1181.
9. `⚙️ [grok-harness] test: verify Grok and retire the plan [step 9/9]`
   - **State:** verification and retirement complete in PR #1190.

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
- [x] Keep the measured Step 7 change below the 1,500-line soft cap (currently 116 lines).
- [x] Skip architecture review because this is localized presentation, static assets, tests, and documentation only.
- [x] Commit the completed successor locally; do not publish before #1177 merges.
- [x] Rebase onto merged #1177 and repeat focused verification.
- [x] Publish Step 7 as PR #1179 and start its monitor.

## Step 8 Checklist

- [x] Reconcile all eight affected regression contracts named by the plan.
- [x] Record Grok setup, branding, import, exact options, turns, replay, permissions, tools, archive, and deletion.
- [x] Extend each affected level matrix through the complete authoritative Grok boundary without duplicating behavior.
- [x] Add Grok-specific exploration, material failure signals, honest limitations, and owning source paths.
- [x] Keep `attachments-and-images.md` unchanged because Grok advertises no image capability.
- [x] Keep `plugin-runtime-installation.md` unchanged because Grok has no managed install.
- [x] Add no production code, transport/persistence shape, analytics, or unrelated historical-gap changes.
- [x] Validate headings, tables, source paths, plan coverage, line width, and Git whitespace.
- [x] Keep the measured Step 8 change below the 1,500-line soft cap (currently 226 lines).
- [x] Skip architecture review because this step changes regression documentation only.
- [x] Commit the completed successor locally; do not publish before #1179 merges.
- [x] Rebase onto merged #1179 and repeat focused documentation validation.
- [x] Publish Step 8 as PR #1181 and start its monitor.
- [x] Merge Step 8 with all required checks passing.

## Step 9 Checklist

- [x] Rebase the final step onto merged #1181 and current `origin/main`.
- [x] Run the required Git-scoped architecture review over Steps 2-7; approved with no findings.
- [x] Run a final architecture review over the verification-discovered persisted-identity fix; approved with no
  findings.
- [x] Run the final package, app, shared, and client analyzer/test matrix.
- [x] Exercise every required L1-L3 Grok row with an authenticated released CLI and iOS simulator client.
- [x] Fix the live-discovered ACP restart identity and accepted-user ordering defect with deterministic regressions.
- [x] Re-run the affected live restart flow and the complete automated matrix after rebasing onto current main.
- [x] Record privacy-safe evidence, remove disposable state, release the local-testing slot, and retire the plan.
- [x] Publish final PR #1190 and start its monitor.
- [x] Address #1190 review findings with required named turn parameters and prompt-write server-request ordering.

## Decisions And Evidence

- 2026-08-28: Authenticated restart testing exposed one shared ACP defect: process-local fallback turn counters reused
  id-less assistant message IDs after a bridge restart, overwriting an earlier persisted answer. A second concrete race
  allowed an agent update to publish before the accepted user message while the prompt frame was still flushing. The
  fix anchors fallback IDs to the accepted prompt identity and gates agent updates plus attributable server requests
  until the user and preceding tool state publish. Focused regressions, the complete ACP/downstream matrix, a live
  post-restart turn, and the final architecture review all passed.
- 2026-08-28: PR #1190 review correctly required `beginTurn`'s nullable identity to remain named and required, and
  identified that the prompt-write gate covered notifications but not the approval registry's separate server-request
  stream. Every caller now states its identity choice, and attributable requests flush after the accepted user and
  buffered tool updates. Deterministic slow-flush regressions cover cross-stream ordering and retain sessionless
  attribution when another session dispatches before the first frame finishes flushing.
- 2026-08-28: The released Grok 1.0.5 client matrix passed without a scope reduction. The authoritative YOLO-disabled
  runs exercised Once and Reject; the live requests advertised no Always action. Seven consecutive debug-only
  unrecognised-frame messages appeared only in the abandoned non-authoritative global-config launch; all six later
  isolated bridge runs recorded none and showed no protocol loss.
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

All required rows passed without a named reduction, so the plan is retired.

## Step 9 Final Evidence

### Release Boundary

- **Grok runtime:** stable `1.0.5` build `5115b46bc909` from the user-installed `grok` on PATH.
- **Bridge host:** Apple silicon (`arm64`), macOS 26.6.2; live source bridge at `ed10b6f04a` on main
  `9395494962`. The identical fix was then rebased onto main `cb9baa91dd` and the automated matrix reran.
- **Client:** source debug build at `5efede9afc`; iPhone 17 simulator named `sesori-dev-2` on iOS 26.5. The intervening
  commits were documentation or unrelated code; the final current-source client analyzers and Prego suite also passed.
- **Account capability:** one locally authenticated credential-backed account exposed at least two selectable models
  and three reasoning-effort values. No account or model identifier is recorded.
- **Permission posture:** the authoritative runs used an isolated home with bridge YOLO mode disabled. The process
  retained Grok's normal ask mode and the exact no-auto-update/no-leader launch policy.
- **Privacy:** committed evidence records versions, bounded capability/count outcomes, statuses, and build identifiers
  only. It contains no credentials, account/model identifiers, prompts, transcripts, private paths, or protocol frames.

### Architecture Review

- **Pass:** the required Git-scoped review of Steps 2-7 found no architecture issues and returned `OK`.
- **Pass:** the final review of the verification-discovered persisted identity and event-ordering fix found no issues
  in identity ownership, lifecycle cleanup, the generic ACP boundary, or compatibility and returned `OK`.

### Automated Matrix

| Scope | Commands | Result |
|---|---|---|
| Shared ACP | `dart analyze --fatal-infos`; `dart test` | Pass: no issues; 274 tests |
| Grok | `dart analyze --fatal-infos`; `dart test` | Pass: no issues; 52 tests |
| Cursor | `dart analyze --fatal-infos`; `dart test` | Pass: no issues; 138 tests |
| Copilot | `dart analyze --fatal-infos`; `dart test` | Pass: no issues; 13 tests |
| DeepSeek | `dart analyze --fatal-infos`; `dart test` | Pass: no issues; 41 tests |
| Hermes | `dart analyze --fatal-infos`; `dart test` | Pass: no issues; 39 tests |
| OMP | `dart analyze --fatal-infos`; `dart test` | Pass: no issues; 53 tests |
| Bridge app | `dart analyze --fatal-infos`; two focused test files | Pass: no issues; 7 tests |
| Shared contracts | `dart analyze`; `dart test` | Pass: no issues; 393 tests |
| Client workspace | `dart pub get` | Pass |
| Prego | `dart analyze --fatal-infos`; `flutter test` | Pass: no issues; 245 tests |
| Mobile and desktop | `dart analyze --fatal-infos` in each shell | Pass: no issues |
| Changed Dart files | Dart LSP diagnostics | Pass: zero diagnostics across eight files |

The final matrix ran again after rebasing onto current main. The Cursor suite's intentional missing-file case logged its
expected `PathNotFoundException` while all 138 tests passed. Dart format 3.1.12 still crashes on the enhanced-enum
source shape in `acp_event_mapper.dart`; analyzer, focused tests, the full suites, LSP, and whitespace validation are
the formatting/compile authorities for this file.

### L3 Retirement Matrix

- **Setup and lifecycle — Pass.** Deterministic probes covered missing, malformed, below-floor, PATH, and authoritative
  explicit binaries. The client showed Grok available, enabled, branded, versioned, and without managed-install
  controls. Live on-demand start, initialize-only refresh, child crash recovery, bridge restart, and owned shutdown all
  completed.
- **Projects and sessions — Pass.** Explicit live import scanned two projects and two sessions; unchanged and
  post-delete scans added zero sessions. Ordinary listing/history reads used bridge state, and every imported row
  retained `grok` attribution.
- **Creation and options — Pass.** The client exposed the bounded multi-model/three-effort catalog, created sessions
  with changed model/effort selections, and retained the exact selected tuple through cold load and restart. Automated
  stale, refresh, default, and failed-write cases passed.
- **Turns — Pass.** Text, reasoning, tools, status, idle completion, early/late stop, stop-and-send, visible process
  failure, and two simultaneous sessions were exercised. A post-fix fast reply persisted after its accepted user
  message.
- **History and recovery — Pass.** An external session imported, replayed, continued, and grew to 57 messages; paging
  crossed the 50-message first page. Cold reopen, process replacement, plugin restart, and bridge restart retained
  content and exact option attribution. The live-discovered restart overwrite was fixed and reverified.
- **Questions and permissions — Pass.** Real ask-mode execution requests appeared under the correct session/tool with
  only the advertised `Once` and `Reject` actions and no `Always`. Reject produced a visible tool failure; Once
  completed the exact tool. Later abort/process cleanup left no stale request, and deterministic ACP/Grok cleanup
  coverage passed.
- **Tools and file changes — Pass.** A live mutation produced the expected one-line content, completed tool card, and
  file-change surface. Execution and mutation tools, running/done/failed states, cancellation, bounded output, and
  replay identity were observed. The disposable file was removed.
- **Archiving and deletion — Pass.** A Grok session archived from the list, remained readable, showed the permanent
  read-only state, and exposed no composer. A separate running session deleted only after its long command was
  cancelled; no child command survived. Its local row/history disappeared, one tombstone remained, the upstream
  directory and prompt remained, and exhausted explicit imports before and after bridge restart scanned the catalog
  while adding zero sessions.
- **Compatibility and presentation — Pass.** The current client rendered the built-in name and official theme artwork.
  Automated light/dark and unknown-ID fallback coverage passed; transport IDs remain strings and no wire field or
  database migration was added.

### First Divergent Boundary And Fix

The real Grok transcript remained correct upstream, but after a bridge restart Sesori's `/session/messages` response
showed a prior id-less assistant reply replaced by the next reply. The first divergent boundary was the shared ACP event
mapper: fallback assistant IDs used a process-local turn counter that restarted at one. A second deterministic race
showed an agent update could arrive while stdin flush was pending and publish before the synthetic accepted-user event.
PR review extended that concrete race to a tool update followed by an attributable server request on the separate
approval stream.

`AcpEventMapper` now derives id-less assistant, halt, and error fallback IDs from the accepted prompt's stable user
message ID. `AcpPlugin` gates session updates and server requests during the prompt-frame write, emits the accepted user
first, flushes buffered updates before buffered requests, and drops both on stale state, dispatch failure, or teardown.
Four regressions cover mapper replacement, the reply race, tool-before-permission ordering, and retained sessionless
attribution. A live post-restart turn then appeared and persisted as user followed by a separate assistant reply. There
is no schema or migration; the
fix prevents future overwrite/reordering. The deliberately corrupted disposable test database was removed rather than
treated as production data.

### Cleanup

- Stopped every source bridge and Grok child; port 9972 is free.
- Shut down only the owned `sesori-dev-2` simulator and retained the device for later slot-2 reuse.
- Removed the disposable workspace probe, temporary opaque-ID files, isolated Grok home, archive, and intentionally
  corrupted slot database. Preserved only the slot's dev login token and bridge identity as directed by the testing
  skill.
- Left the real user Grok and Sesori configuration unchanged; authoritative permission evidence came only from the
  isolated YOLO-disabled home.
- Retained the Git worktree and branch, removed no source branch, and moved this passing plan to
  `.plan/completed/grok-harness/`.
