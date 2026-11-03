# Periodic cleanup 2026-11

## Goal, evidence and scope

The last cleanup retired on 2026-09-06 ([completed plan](../../completed/periodic-cleanup/PLAN.md)).
Two months of feature work have landed since. On 2026-11-02, ten area audits
read the whole repository at `origin/main` `fd391cd370`, using the same brief:
- leftovers, then simplification, then rule violations, then test debt;
- each finding must be verified;
- nothing may be reopened that the previous audit deliberately kept or declined.

Their reports are in [audit/](audit/) and hold the file:line evidence for every
finding ID used below:

| Report | IDs |
| --- | --- |
| [phone-ui.md](audit/phone-ui.md) | UI-1…12 |
| [module-core.md](audit/module-core.md) | MC-1…7 |
| [plugin-interface-and-acp.md](audit/plugin-interface-and-acp.md) | PI-1…9 |
| [bridge-core.md](audit/bridge-core.md) | BA-1…12 |
| [native-plugins.md](audit/native-plugins.md) | PN-1…22 |
| [bridge-services.md](audit/bridge-services.md) | BS-1…25 |
| [desktop-and-shared.md](audit/desktop-and-shared.md) | DS-1…14 |
| [compatibility-and-dependencies.md](audit/compatibility-and-dependencies.md) | XC-1…7 |
| [ci.md](audit/ci.md) | XC-CI-1…13 |
| [docs-and-plans.md](audit/docs-and-plans.md) | XC-DOC-1…14 |

Phase 1 is the cleanup that needs no product-level redesign:
- dead production code, and production APIs that only tests call;
- never-called routes;
- duplicated or one-implementation layers;
- AGENTS.md rule violations;
- unused dependencies, CI leftovers and stale docs or plans.

It removes roughly 12k authored lines plus about 8–18k generated or scaffold
lines, depending on the pending decisions. Phase 2 holds the larger items that
need their own plans (see the end of this file).

PN-1 was a live OpenCode v2 bug, and it was fixed outside this series: v2 turns
never emitted the session-idle signal (#2309, merged 2026-11-03).

### Rules for every step

- **Re-verify each finding before acting.** The audits used a token-count heuristic plus manual tracing. A finding that turns out to be wrong is dropped and noted in the tracker; never force it through.
- **Wire safety.** Before removing or changing a client↔bridge route, field, enum value or SSE variant, `git grep` every public release tag for a caller or decoder:
  - Bridge releases: `bridge-v0.3.0`…`bridge-v1.0.7`, then `v1.0.8`…`v1.11.0`.
  - v1.9.2, v1.10.0 and v1.10.2 were never public.
  - Remove the item only when no public peer uses it. Otherwise keep it, with a dated `COMPATIBILITY` marker.
- **Behavior.** Steps preserve behavior except where a step names a user-visible change. Each PR updates its affected `docs/regression/` documents in the same PR.
- **New findings.** Anything found mid-step follows the user's findings rule:
  - fix it when it follows from an existing decision or rule;
  - raise it on a review page when it is a design choice;
  - never leave it silently.
- **No new machinery.** A cleanup step adds no new mutable coordination. The one deliberate exception is step 14.

## Decisions

Decided while consolidating the audit. These are minor polish or follow from
existing rules or decisions:

| Item | Decision |
| --- | --- |
| MC-2 | Session rename shows the new title immediately in the All Sessions rows (Option B). The `SessionListCubit` list state that nothing renders goes. |
| PN-22 | Keep the OpenCode v1 adapter. Live checks cover v2 only (earlier user decision). |
| PN-16, PI-7 (overrides the "retire" half of XC-2) | Keep the "Plan advertised as an agent" aliases, and reword their markers. Stored new-session defaults never expire, and older apps still send `plan`. Removing the Codex alias would turn a plan request into an editing turn. |
| PN-17 | Shared managed-runtime setup-status helper for Pi and OMP, with exhaustive switches instead of casts. |
| BS-1 | Push maintenance telemetry shrinks to one summary line. |
| BS-2 | Remove the dead updater state. Keep the downgrade-parse warning as a plain log. |
| BS-19 | Remove the retired `--import-plugin` flag. |
| BS-24 | Close the warm-up listener-pair deferral as kept: one trigger per listener. |
| UI-3, DS-7 | Shared platform adapters move into `client/module_app_ui/lib/src/platform/`, which `client/AGENTS.md` already allows. |
| DS-2 | Delete the no_slop_linter rules that never run. |
| DS-13 | Widen the `prefer_specific_type` exemptions for JSON maps and error causes, and remove the suppressions this makes redundant. |
| DS-14 | `avoid_bang_operator` also covers tests (the user's "no null assertions in any language" rule). Fix the roughly 78 test sites. |
| DS-6 | (a) Share desktop notification-open routing now. (b) The desktop attention-state rework goes to phase 2. |
| DS-11 | Keep `Session.branchName` for older public apps, and add its marker. |
| XC-CI-3 | `sesori_shared` gets `publish_to: none`. Delete its broken Makefile publish path. |
| XC-CI-6 | Remove the fully rolled-out `DESKTOP_MACOS_PUBLICATION_ENABLED` gate. |
| XC-CI-8 | Delete `.github/release.yml` and its label check. |
| XC-CI-12 | Run the `tool/mcp-contracts` tests in CI. |
| XC-CI-13 | Keep `deploy-android-internal.yml` as a manual single-platform wrapper. |
| XC-DOC-6 | Condense the orphaned auth-reconnect plan into a short draft under `.plan/drafts/`. |
| XC-DOC-11 | Rewrite `docs/cursor-acp-followups/README.md` against current code. |

Pending user decisions, asked on the review page:

| Q | Item | Options (suggested first) | Affects step |
| --- | --- | --- | --- |
| Q1 | BA-2 bridge restart route and subsystem | remove; or keep it debug-only and off the relay | 24 |
| Q2 | PI-4 / XC-DOC-2 inert runtime-update seam and the stalled `path-runtime-authority-split` plan | remove and retire the plan; or keep it and re-plan steps 7–9 | 23, 25 |
| Q3 | UI-7 phone app macOS/Linux/Windows/web runners | delete; or keep for local development | 26 |
| Q4 | UI-8 "temporary" voice-engine picker in v1.11.0 | gate it to internal builds; remove it; or make it permanent | 16 |
| Q5 | XC-DOC-1 retire eight finished or stalled plans | all eight, accepting the named gaps; or only the four without gaps | 23 |

A step whose decision removes its work is marked **dropped** in the tracker.
Its number stays, so series titles keep one total.

## Phase 1 steps

Titles use `<emoji> [periodic-cleanup-2026-11] <description> [step x/28]`.
Sizes are rough changed-line counts (additions plus deletions), split into
authored and generated.

| Step | Title | Findings | Size | After |
| --- | --- | --- | --- | --- |
| 1 | 🌱 Raise the plan | — | docs | — |
| 2 | ⚙️ Remove plugin-interface members the bridge never calls | PI-3, PN-5, PN-14, PN-15 | ~400 | 1 |
| 3 | ⚙️ Remove the never-called project-questions and plugin-setup routes | BA-1, BA-4 | ~1,100 | 2 |
| 4 | 🌿 Trim the ACP family | PI-1, PI-2, PI-5, PI-8, PI-9 | ~520 | 3 |
| 5 | 🌿 Trim the Claude plugin | PN-7, PN-8, PN-11, PN-12, PN-18, PN-19 (Claude parts) | ~550 | 2 |
| 6 | 🌿 Trim the Codex plugin | PN-4, PN-8, PN-9, PN-10, PN-11, PN-19 (Codex parts) | ~725 | 2 |
| 7 | 🌿 Trim the Pi, OMP and OpenCode plugins | PN-3, PN-8, PN-11, PN-12, PN-13, PN-17, PN-19 (their parts) | ~900 + ~2,100 gen | 2 |
| 8 | 🌱 Stop generating unused OpenCode v1 models | PN-2 | ~4.4–5.9k gen | 1 |
| 9 | 🌿 Remove dead bridge persistence methods and hand-rolled plugin fakes | BA-3, BA-5, BA-12 | ~850 | 3 |
| 10 | 🌿 Trim push and the updater | BS-1, BS-2, BS-3, BS-4, BS-6, BS-8, BS-13, BS-16, BS-21 | ~850 | 1 |
| 11 | ⚙️ Simplify the runtime package and plugin lifecycle | BS-5, BS-7, BS-10, BS-11, BS-12, BS-14, BS-15, BS-20, BS-22, BS-25 | ~630 | 1 |
| 12 | 🌿 Fix bridge app rule violations | BA-7, BA-9, BA-10, BA-11, BS-9, BS-17, BS-18, BS-19, BS-23 | ~550 | 9, 10, 11 |
| 13 | ⚙️ Remove dead and test-only module_core APIs | MC-1, MC-3, MC-4, MC-5, MC-6, MC-7 | ~500 | 1 |
| 14 | 🌿 Show renamed session titles immediately and drop the unrendered list state | MC-2 | ~560 | 13 |
| 15 | 🌿 Delete dead Prego components | UI-1, UI-11 | ~620 | 1 |
| 16 | 🌿 Clean up the phone app | UI-2, UI-4, UI-5, UI-6, UI-8 (per Q4), UI-9, UI-10, UI-12 | ~500–1,000 | 13 |
| 17 | 🌿 Share the platform adapters between phone and desktop | UI-3, DS-7 | ~610 | 16 |
| 18 | 🌿 Delete dead sesori_shared code | DS-1, DS-3, DS-5, DS-8 | ~1,300 + ~390 gen | 1 |
| 19 | 🌿 Remove the unrendered login control prompt and share notification routing | DS-4, DS-6a | ~125 | 17, 18 |
| 20 | 🌿 Retire dead lint rules and tighten the live ones | DS-2, DS-9, DS-13, DS-14, XC-6 (linter part) | ~1,150 | all code steps up to 19 |
| 21 | 🌱 Remove CI leftovers | XC-CI-1…12 | ~250 | 1 |
| 22 | 🌱 Correct compatibility markers | XC-2 (auth branch), XC-3 (Codex), XC-5, XC-7, BA-8, DS-11, PN-16, PI-7 | ~220 | 4, 6 |
| 23 | 🌱 Retire finished plans and fix stale docs | XC-DOC-1 (per Q5), XC-DOC-2 (per Q2), XC-DOC-3…14, DS-10, PI-6 | docs | answers |
| 24 | per Q1: 🌿 Remove the bridge restart subsystem, or 🌱 keep restart debug-only | BA-2 | ~940 or ~5 | 12 |
| 25 | per Q2: 🌿 Remove the inert runtime-update seam, or dropped | PI-4 | ~230 | 4 |
| 26 | per Q3: 🌱 Remove the phone app's desktop and web runners, or dropped | UI-7 | ~9.9k scaffold | 17 |
| 27 | 🌱 Reconcile regression docs | — | docs | 2–26 |
| 28 | 🌱 Run the verification matrix and retire the plan | — | docs | 27 |

The "After" column lists hard dependencies, which exist to avoid conflicts in
shared files. Independent steps run in parallel worktrees: at most about four
PRs open at once, never two that edit the same files.

Steps 7, 8, 18 and 26 exceed the 1,500-line soft cap only through generated
deletions or runner scaffold. Their authored churn stays under the cap; report
the split in the PR body. If step 7's authored churn exceeds about 1,000 lines,
split PN-3 out as 7.a/7.b.

### Step contracts

Only what the findings do not already make obvious.

- **2.**
  - `healthCheck`, `renameProject` and `markFailed` go from the interface, every plugin and the fakes.
  - `getSessions` loses its always-null `start` and `limit`.
  - This touches every plugin package. Steps 5–7 rebase on it.
- **3. Wire.**
  - Confirm that no public client tag calls `POST /project/questions` or `GET /plugin/setup` before removing either route.
  - Remove `getProjectQuestions` from the six plugins that implement it, along with `setupSnapshot` and `PluginSetupResponse`.
  - A shared wire type that a public client decodes stays.
- **4.**
  - PI-5 moves the throwing `PluginMessagePart` accessors into a test-only extension. Tests keep their call sites through one import, and production code uses exhaustive switches.
  - PI-2 removes the process-wide prompt lane only after it confirms no ACP plugin sets the switches.
- **5–7.**
  - Test fakes shipped under `lib/*_testing.dart` move under `test/` (PN-12).
  - The Claude transcript stops copying the `raw` map per line (PN-8).
  - Re-run each plugin's code generator after DTO removals (PN-3, PN-4). Never hand-edit generated files.
  - The Pi flake fix (PR in flight, `pi_extension_ui_service_test.dart`) lands first.
- **8.** Change the generator root in `bridge/sesori_plugin_opencode/tool/generate_opencode_client.dart` so unreferenced v1 models are not emitted, then regenerate. The v1 adapter itself stays (PN-22).
- **10.** Keep one summary line of push maintenance telemetry. The updater is built once and shared by `bin/` and the runner. Rollback failures are logged with their stacks.
- **11.**
  - BS-5 replaces `PluginLifecycleService`'s two-phase `initialize` with constructor parameters; the 64 test call sites change mechanically.
  - BS-25 removes the relay `1000 + "replaced"` fallback only after confirming that the deployed relay (`sesori_relay_server` main) sends the dedicated close code. Otherwise keep the fallback, add a marker, and record the condition.
- **12.**
  - `ManagedRuntimePathService` uses `resolveUserHomeDirectory` (BS-9).
  - Relay control frames parse into a sealed `RelayControlMessage` at the boundary (BA-11).
  - Swallowed relay and auth errors get logs that keep cause and stack (BA-7).
- **13.**
  - `bridgeOffline` stops fabricating `HealthResponse(version: "")`; model the absent health honestly (MC-4).
  - Route parsing throws `ArgumentError` on a missing id instead of falling back to `""` (MC-7).
- **14.**
  - Rename sets the new title on the matching `SessionWindowService` row at once. It reverts on failure and settles when the bridge's `SesoriSessionUpdated` echo arrives.
  - Reuse `OptimisticRenameTracker`, which projects already use, rather than adding a new mechanism.
  - `SessionListCubit` keeps only its actions. The dispatcher reads running and unseen state from the row.
  - The `projects-and-sessions.md` rename claim becomes true. Feel check: the title changes in place with no row jump or reorder flicker.
- **16.**
  - Removing the deep-link stack drops the `app_links` dependency.
  - UI-8 follows Q4.
  - Unused ARB keys are deleted from the source ARB and regenerated.
- **17.** Move the identical adapters and the shared route dispatcher and no-op config sources into `module_app_ui/lib/src/platform/`. Both shells keep only their genuinely different adapters.
- **18.** Before deleting `GlobalSession` and `SessionProject`, confirm that no public client tag decodes them (DS-3).
- **19.**
  - Before removing `ControlPromptKind.loginNeeded`, confirm that no public desktop build renders it. Its unknown-value fallbacks go only where no public peer can send an unknown kind.
  - Desktop notification-open routing shares one owner.
- **20.**
  - Comes after the code steps, because DS-13 removes suppressions across about 100 files and DS-14 edits tests in many packages.
  - Run `dart analyze --fatal-infos` per package; `flutter analyze` hides the custom lint infos.
- **22.**
  - Retire the dead auth-server 404/405 branch now; its retiring condition has passed.
  - Add markers to unmarked compatibility code (XC-5, BA-8, DS-11).
  - Fix marker format (XC-7), using `v1.12.0` as the current product version.
  - Drop the misleading Codex null-agent marker (XC-3).
- **23.**
  - `git mv` each retired plan to `.plan/completed/`, adding a dated "Retired with accepted gaps" note that names each unexecuted check.
  - Repoint every `.plan/active/` link that the move breaks.
  - Correct the stale tracker states.
- **24.**
  - Option A removes the route, `RoutedRequestOutcome`, the restart service and launcher, exit code 86 and the desktop respawn case. The supervised E2E test restarts by stop/start on the same data directory.
  - Option B only unregisters the route from the relay router.
- **25.**
  - Confirm that `PluginControlCapability.runtimeUpdate` never reached a public client before deleting the enum value. If it did, keep the value with a marker and remove only the inert spec and overrides.
  - Retire `path-runtime-authority-split` as abandoned at step 6.
- **26.** Delete `client/app/{macos,linux,windows,web}` and the Dart branches only those targets reach. `client/desktop` is the desktop product.

## Complexity budget

New mutable state: one pending-title entry per renamed session in step 14,
owned by the existing `OptimisticRenameTracker`. It is justified because
otherwise a rename visibly lags until the bridge echoes it.

Everything else only removes state. The biggest removals:
- the unrendered `SessionListCubit` list state and its SSE subscription;
- the restart subsystem's exit-86 branches (if Q1 = remove);
- duplicated push requestId maps;
- the updater's dead stage state;
- the two-phase lifecycle init.

Deliberately not added:
- new shared packages;
- compatibility shims for internal packages;
- guards for flows no caller reaches.

## Verification and retirement

Follow the [regression proof boundaries](../../../docs/regression/README.md).
Each step runs its owning tests and `dart analyze --fatal-infos`, with CI for
the full matrix. The highest level is **L2**, scoped to the touched behavior:
this plan claims behavior preservation plus the step 14, 16, 19, 24, 25 and 26
changes, not a fresh pass of whole feature documents.

| Rows | Proof |
| --- | --- |
| Plugin interface, routes and plugins (steps 2–8, 25) | Owning suites for every plugin package. Headless live bridge on macOS: setup inspection of every registered harness; a real turn on OpenCode v2, Claude Code and Codex including turn completion; one question or permission round trip. |
| Bridge services (steps 9–12, 24) | Owning suites, including `supervised_e2e_test`. A headless bridge start, relay connect, reconnect and clean shutdown. With Q1 = remove, a desktop-supervised stop/start keeps the same data directory. |
| Client (steps 13–17) | Owning cubit, widget and golden suites. Headless iOS simulator (`xcrun simctl boot`, never Simulator.app) on the device the local testing setup assigns: project list, session list, rename showing the new title at once without a jump, session detail, settings (voice entry per Q4), sign-out and in. |
| Desktop-specific (step 19) | Owning `module_desktop_core` suites (`dart test`). Notification-open routing on a macOS desktop build if a display is available. Otherwise record it as not run; it is not a pass. |
| Shared, linter, CI, docs (steps 18, 20–23, 26) | Owning suites, analyzers, generator dry runs, the CI workflow run itself, link checks over the moved plans. |

Affected regression documents:
- `projects-and-sessions.md`: the rename claim, and the project questions route.
- `questions-and-permissions.md`
- `plugin-setup-and-lifecycle.md`: `healthCheck`, `/plugin/setup`.
- `plugin-runtime-installation.md`: the runtime-update seam.
- `bridge-connectivity.md`: relay control frames and close codes.
- `desktop-bridge-supervision.md`: restart.
- `notifications.md`: push telemetry, desktop notification routing.
- `voice-input.md`: the picker.
- `bridge-installation-and-updates.md`: updater, `--import-plugin`.
- `account-and-onboarding.md`: the login control prompt.

Step 27 reconciles them. Step 28 records Pass, Partial, Fail, Blocked or Not
run per row, and moves the plan to `.plan/completed/periodic-cleanup-2026-11/`
only when the rows pass. Reducing this matrix needs explicit user acceptance,
recorded here.

## Phase 2 (rough; each becomes its own plan when it starts)

- **Support floors and a client-side bridge-version gate** (XC-1, DS-12, XC-4). About 140 compatibility markers wait on floors that nobody has chosen. A floor is only safe with a gate that tells an old bridge or app to update:
  - A v1.10.1 floor in both directions retires about 112 markers, roughly 1k lib and 1.7k test lines.
  - The native storage v1 migration for installs older than v1.9.1 belongs to the same decision.
- **Codex and Pi turn-state remodel** (PN-20). Parallel mutable maps become sealed per-turn state. Its value is real but it is high-risk; schedule it only when those plugins are next touched for a feature.
- **Desktop attention-state rework** (DS-6b). Desktop is public and desktop-app is retiring, so the deferral's reopening condition is met.
- **Orchestrator policy extraction** (BA-6). Unseen-activity and YOLO policy move into their services.
- **Cross-plugin sharing** (PN-6, PN-21). Claude and Codex share one MCP elicitation form schema, and the ACP scratch-lease helper is shared, via `sesori_plugin_runtime`.

## Checked and kept

Each audit report's "Checked and kept" section lists the candidates it verified
and kept. Highlights:
- The OpenCode v1 adapter is reachable and supported (PN-22).
- The plan-mode aliases stay (PN-16).
- The warm-up listener pair stays (BS-24).
- `deploy-android-internal.yml` stays (XC-CI-13).
- The plan-maker's explicit-acceptance rule stays: the stalled plans came from never asking, which Q5 fixes.
