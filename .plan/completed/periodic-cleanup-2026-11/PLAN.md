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
- **Wire safety.** The check depends on the contract and on which direction the data flows. "Public tags" means:
  - Phone app: `app-v1.0.5`, `app-v1.0.6`, then `v1.0.8`…`v1.11.0`.
  - Bridge: `bridge-v0.3.0`…`bridge-v1.0.7`, then `v1.0.8`…`v1.11.0`.
  - v1.9.2, v1.10.0 and v1.10.2 were never public.

  The rule for each contract:
  - **Phone and bridge.**
    - Before the bridge stops serving or sending something (route, field, SSE variant), `git grep` the public phone tags for a caller or decoder.
    - Before either side stops accepting something (enum value, variant, field), `git grep` the public tags of the side that sends it.
    - Never remove an unknown-value fallback on a type that crosses this wire. It also protects against future peers.
    - When a public peer still depends on the item, keep it with a dated `COMPATIBILITY` marker.
  - **Relay and bridge.** The relay deploys on its own schedule. Check what the deployed relay sends (`sesori_relay_server` main), and keep unknown-type handling.
  - **Desktop app and its bundled bridge.** They ship together, and the bundled bridge never self-updates. No tag check is needed.
  - **Internal Dart contracts** (plugin interface, packages): no check and no markers. Update every consumer together.
- **Behavior.** Steps preserve behavior except where a step names a user-visible change. Each PR updates its affected `docs/regression/` documents in the same PR; step 27 only reconciles what the series left inconsistent across documents.
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
| PN-22 | Keep the OpenCode v1 adapter. Live checks cover v2 only (earlier user decision), except the OpenCode 1.18.32 PATH row that Q6 folds into step 28 from the retired opencode-v2 matrix. |
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

User decisions (review pages, 2026-11-02 and 2026-11-03):

| Q | Item | Decision | Step |
| --- | --- | --- | --- |
| Q1 | BA-2 bridge restart route and subsystem | Remove the route and the whole restart subsystem. | 24 |
| Q2 | PI-4 / XC-DOC-2 inert runtime-update seam | Remove the seam and retire `path-runtime-authority-split` as abandoned at step 6. Updating harnesses from the app would be a new plan. | 23, 25 |
| Q3 | UI-7 phone app macOS/Linux/Windows/web runners | Delete them. The phone app is iOS and Android only. | 26 |
| Q4 | UI-8 "temporary" voice-engine picker in v1.11.0 | Remove the picker, its route, cubit and stored preference. The automatic device-then-server fallback stays. | 16 |
| Q5 | XC-DOC-1 eight finished or stalled plans | Retire all eight. The user accepts these unexecuted checks: quota-auto-continuation macOS QA; mcp-management step 37 L4 and external checks; desktop-sign-in full Apple sign-in on a macOS build; user-analytics Looker report and 3-day reconciliation. | 23 |
| Q6 | Round 2: the retired plans skipped more checks than Q5 listed (opencode-v2 and step-timers never ran their final live matrices; desktop-sign-in and quota-auto-continuation skipped more rows) | Fold the opencode-v2 and step-timers live rows into step 28's matrix and step-timers' reconciliation into step 27. Every other gap stays accepted as recorded in each retired tracker. | 27, 28 |
| Q7 | Round 2: ROADMAP's same-machine loopback transport for the desktop cockpit | Keep it as an unscheduled idea with a concrete trigger: users needing the desktop app offline, or relay latency hurting same-machine use. | 23 |
| Q8 | Round 3: on Windows, Codex and OpenCode runtimes outlive a bridge crash (the record holds the `cmd.exe` pid, with no start time to match) | A: put every runtime the bridge launches into a kill-on-close Windows job object, so it ends with the bridge however the bridge exits. | Out of series (#2365) |
| Q9 | Round 4: which linter rules the 9 bridge packages that never loaded the linter follow | A: the bridge enforces the written rules (no `!`, no forced casts, required named parameters, exhaustive switches, no mutable fields, no dynamic return types). `prefer_specific_type` and `avoid_implicit_tostring` are off for the bridge only; the client keeps every rule. | 20.e–20.g |
| Q10 | Rounds 4 and 5: about 1,030 `!` in the bridge app's tests | A: sweep them now, then the bridge app joins the linter. | 20.h, 20.i |
| Q11 | The dropped format-only PR: should CI check `dart format`? | Yes (A). CI checks `dart format` on hand-written Dart files, and one reformat lands at a quiet time, while few PRs are open. | 20.k, 20.l |
| Q12 | Windows job object: a runtime can escape it before it is bound | B: close the escape with a suspended start. Start the runtime suspended, bind it to the job object, then resume it. | Out of series (#2379) |
| Q13 | Round 7: step-timer rows the current sign-ins could not run | A: accept them as recorded: OpenCode background sub-agent Blocked and foreground Task Partial (revoked Anthropic sign-in), retry rows Not run, DeepSeek working timer Partial. | 28 |
| Q14 | Round 7: desktop notification-open check on a macOS build | A: record it as Not run. The desktop core (454/454) and shared routing (26/26) suites stand in. | 28 |
| Q15 | Round 7: step 28 test leftovers in real harness stores, including a dictated-speech prompt in Hermes | A: delete everything step 28 created. | 28 |
| Q16 | Round 8: when the "Are you enjoying Sesori?" sheet slides up | C: keep it as it is: right after the fifth point, over whatever is on screen. | No change |

## Phase 1 steps

Titles use `<emoji> [periodic-cleanup-2026-11] <description> [step x/28]`.
Sizes are rough changed-line counts (additions plus deletions), split into
authored and generated.

| Step | Title | Findings | Size | After |
| --- | --- | --- | --- | --- |
| 1 | 🌱 Raise the plan | — | docs | — |
| 2 | ⚙️ Remove plugin-interface members the bridge never calls | PI-3, PN-5, PN-14, PN-15 | ~400 | 1 |
| 3 | ⚙️ Remove the never-called project-questions and plugin-setup routes | BA-1, BA-4 | ~1,100 | 2, 11 |
| 4 | 🌿 Trim the ACP family | PI-1, PI-2, PI-5, PI-8, PI-9 | ~520 | 3 |
| 5 | 🌿 Trim the Claude plugin | PN-7, PN-8, PN-11, PN-12, PN-18, PN-19 (Claude parts) | ~550 | 3 |
| 6 | 🌿 Trim the Codex plugin | PN-4, PN-8, PN-9, PN-10, PN-11, PN-19 (Codex parts) | ~725 | 3 |
| 7 | 🌿 Trim the Pi, OMP and OpenCode plugins | PN-3, PN-8, PN-11, PN-12, PN-13, PN-17, PN-19 (their parts) | ~900 + ~2,100 gen | 4 |
| 8 | 🌱 Stop generating unused OpenCode v1 models | PN-2 | ~4.4–5.9k gen | 1 |
| 9 | 🌿 Remove dead bridge persistence methods and hand-rolled plugin fakes | BA-3, BA-5, BA-12 | ~850 | 3 |
| 10 | 🌿 Trim push and the updater | BS-1, BS-2, BS-3, BS-4, BS-6, BS-8, BS-13, BS-16, BS-21 | ~850 | 1 |
| 11 | ⚙️ Simplify the runtime package and plugin lifecycle | BS-5, BS-7, BS-10, BS-11, BS-12, BS-14, BS-15, BS-20, BS-22, BS-25 | ~630 | 10 |
| 12 | 🌿 Fix bridge app rule violations | BA-7, BA-9, BA-10, BA-11, BS-9, BS-17, BS-18, BS-19, BS-23 | ~550 | 9, 11 |
| 13 | ⚙️ Remove dead and test-only module_core APIs | MC-1, MC-3, MC-4, MC-5, MC-6, MC-7 | ~500 | 1 |
| 14 | 🌿 Show renamed session titles immediately and drop the unrendered list state | MC-2 | ~560 | 13 |
| 15 | 🌿 Delete dead Prego components | UI-1, UI-11 | ~620 | 1 |
| 16 | 🌿 Clean up the phone app and remove the voice-engine picker | UI-2, UI-4, UI-5, UI-6, UI-8, UI-9, UI-10, UI-12 | ~1,000 | 14 |
| 17 | 🌿 Share the platform adapters between phone and desktop | UI-3, DS-7 | ~610 | 16 |
| 18 | 🌿 Delete dead sesori_shared code | DS-1, DS-3, DS-5, DS-8 | ~1,300 + ~390 gen | 1 |
| 19 | 🌿 Remove the unrendered login control prompt and share notification routing | DS-4, DS-6a | ~125 | 12, 17, 18 |
| 20 | 🌿 Retire dead lint rules and tighten the live ones | DS-2, DS-9, DS-13, DS-14, XC-6 (linter part) | ~1,150 | 2–19, 22, 24–26 |
| 21 | 🌱 Remove CI leftovers | XC-CI-1…12 | ~250 | 1 |
| 22 | 🌱 Correct compatibility markers | XC-2 (auth branch), XC-3 (Codex), XC-5, XC-7, BA-8, DS-11, PN-16, PI-7 | ~220 | 4, 6, 18 |
| 23 | 🌱 Retire finished plans and fix stale docs | XC-DOC-1, XC-DOC-2, XC-DOC-3…14, DS-10, PI-6 | docs | 1 |
| 24 | 🌿 Remove the bridge restart subsystem | BA-2 | ~940 | 12 |
| 25 | 🌿 Remove the inert runtime-update seam | PI-4 | ~230 | 4 |
| 26 | 🌱 Remove the phone app's desktop and web runners | UI-7 | ~9.9k scaffold | 17 |
| 27 | 🌱 Reconcile regression docs | — | docs | 2–26 |
| 28 | 🌱 Run the verification matrix and retire the plan | — | docs | 27 |

The "After" column lists hard dependencies; dependencies are transitive. They
keep parallel PRs out of the same files and types. In particular:
- step 11 lands the final runtime-selection types (BS-10, BS-15) before any
  plugin step switches over them (PN-17);
- step 3 removes the shared interface members first; steps 4, 5 and 6 then
  each own a different plugin package and run in parallel;
- step 7 follows step 4, and step 25 (which edits
  `plugin_lifecycle_service.dart` like step 3) follows step 4. Small overlaps
  with step 5 or 6 in plugin descriptors are resolved by merging main in.

Steps without a path between them run in parallel worktrees, about four to
six PRs at a time. The first wave is steps 2, 8, 10, 13, 15, 18, 21 and 23.

Steps 7, 8, 18 and 26 exceed the 1,500-line soft cap only through generated
deletions or runner scaffold. Their authored churn stays under the cap; report
the split in the PR body. If step 7's authored churn exceeds about 1,000 lines,
split PN-3 out as 7.a/7.b.

### Step contracts

Only what the findings do not already make obvious.

- **2.**
  - `healthCheck`, `renameProject` and `markFailed` go from the interface, every plugin and the fakes.
  - `getSessions` loses its always-null `start` and `limit`.
  - This touches every plugin package. Also update `bridge/app/tool/cursor_smoke.dart`, the only `healthCheck` caller, and the benchmark fakes in `bridge/app/tool/benchmarks`.
- **3. Wire.**
  - Confirm that no public phone tag calls `POST /project/questions` or `GET /plugin/setup` before removing either route.
  - Remove `getProjectQuestions` from the six plugins that implement it, along with `setupSnapshot` and `PluginSetupResponse`.
  - A shared wire type that a public client decodes stays.
- **4.**
  - PI-5 moves the throwing `PluginMessagePart` accessors into a test-only extension. Tests keep their call sites through one import, and production code uses exhaustive switches.
  - PI-2 removes the process-wide prompt lane only after it confirms no ACP plugin sets the switches.
- **5–7.**
  - Test fakes shipped under `lib/*_testing.dart` move under `test/` (PN-12).
  - The Claude transcript stops copying the `raw` map per line (PN-8).
  - Re-run each plugin's code generator after DTO removals (PN-3, PN-4). Never hand-edit generated files.
  - The Pi flake fix (`pi_extension_ui_service_test.dart`) merged first as #2311.
- **8.** Change the generator root in `bridge/sesori_plugin_opencode/tool/generate_opencode_client.dart` so unreferenced v1 models are not emitted, then regenerate. The v1 adapter itself stays (PN-22).
- **10.**
  - Keep one summary line of push maintenance telemetry.
  - BS-3: `UpdateCommand.run` and the runner's `_buildUpdateLifecycleService` run in separate commands, so they cannot share one object. Add one composition function in the updater code that both call. No static setup method on the service, because a service must not build its own repositories.
  - Rollback failures are logged with their stacks.
- **11.**
  - BS-5 replaces `PluginLifecycleService`'s two-phase `initialize` with constructor parameters:
    - The constructor validates `setupById` and exposes a `final startupPolicy`, so the runner no longer gets it from `initialize`.
    - `uncontrollableDisabledPluginIds` becomes a static function over the registered plugin list, called before `inspect`.
    - No second initialization step survives under another name.
    - The 64 test call sites change mechanically.
  - Land BS-10 and BS-15 (the sealed `ManagedRuntimeHandle` and the merged selection types) here, before the plugin steps switch over them.
  - BS-25 removes the relay `1000 + "replaced"` fallback only after confirming that the deployed relay (`sesori_relay_server` main) sends the dedicated close code. Otherwise keep the fallback, add a marker, and record the condition.
- **12.**
  - `ManagedRuntimePathService` uses `resolveUserHomeDirectory` (BS-9).
  - BA-11: relay control frames to the bridge parse into a sealed `RelayControlMessage` in `sesori_shared/lib/src/protocol/messages.dart`, next to `RelayNoticeMessage`.
    - Build it the same way, with a `fallbackUnion: "unknown"` variant.
    - The relay loop parses it with `fromJson`, switches over every case, and logs and ignores unknown types, because the relay deploys on its own schedule.
    - This replaces the magic-string parsing in `orchestrator.dart`.
  - Swallowed relay and auth errors get logs that keep cause and stack (BA-7). Skip the edit to `bridge_restart_service.dart`, which step 24 deletes.
- **13.**
  - `bridgeOffline` stops fabricating `HealthResponse(version: "")`; model the absent health honestly (MC-4).
  - Route parsing throws `ArgumentError` on a missing id instead of falling back to `""` (MC-7).
- **14.** Follow the existing project pattern: `ProjectInventoryService.renameProject` and its visible-title overlay.
  - **Owner.** `SessionWindowService.renameSession` owns the rename. It holds the token counter and the `OptimisticRenameTracker` map, and it calls `SessionRepository.renameSession`.
    - Each screen scope has its own window. The rename runs on the window of the scope it was started from.
  - **Visible title.** The window applies the pending title in every path that emits rows: paged loads, complete mode, and replay or reload.
    - On failure the title reverts.
    - On success the window writes the confirmed title into its stored row, so the later `SesoriSessionUpdated` echo changes nothing. The tracker settles when the bridge answers, so without that write the row would flash back to the old title before the echo.
  - **The action object.**
    - The list state goes: `sessions`, `activeSessionIds` and `unseenBySessionId`, along with the SSE subscription, resolvers and freezed state.
    - With no state left to emit, `SessionListCubit` stops being a `Cubit`. It becomes a plain action object built by the existing composition function, which now receives the scope's window: `createSessionListCubit(window: context.read<SessionWindowService>())`. Both shells and their session-detail screens sit inside a `SessionScope`.
    - Its rename hands off to `window.renameSession`.
    - The dispatcher reads running and unseen state from the row.
  - The `projects-and-sessions.md` rename claim becomes true. Feel check: the title changes in place with no row jump, reorder or flicker.
- **16.**
  - Removing the deep-link stack drops the `app_links` dependency.
  - UI-8 removes the picker view and screen, the `settingsVoiceEngine` route, `VoiceEngineCubit`, the `VoiceEngine` preference and its storage, and their ARB keys. Dictation always tries on-device first and falls back to the server, still behind `voice_on_device_enabled`. A stored preference becomes a dead key; do not migrate it. Settings visibly loses the voice-engine row, so include before and after screenshots.
  - Unused ARB keys are deleted from the source ARB and regenerated.
- **17.** Move the identical adapters and the shared route dispatcher and no-op config sources into `module_app_ui/lib/src/platform/`. Both shells keep only their genuinely different adapters.
- **18.** Before deleting `GlobalSession` and `SessionProject`, confirm that no public client tag decodes them (DS-3).
- **19.**
  - Control prompts travel between the desktop app and its bundled bridge, which ship together, so `ControlPromptKind.loginNeeded` and its unknown-value fallbacks can go without a tag check.
  - DS-6a: one function in `module_core/lib/src/routing/` builds the session-detail route, applies the "already on this screen" check and replaces the route stack.
    - The phone keeps its computer-switch path in `NotificationOpenDispatcher`, and skips the "already on this screen" check when a switch happens.
    - The desktop keeps window showing, its open checks and popup closing in `DesktopAttentionService`.
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
- **24.** Remove the restart path end to end:
  - the route and `RoutedRequestOutcome`, so the dispatcher returns a plain `RelayResponse`;
  - the restart dispatcher, the restart service and the Windows successor launcher;
  - the restart command and env;
  - the restart-predecessor wait and the update re-check after it (`bridge_runtime_runner.dart`);
  - exit code 86 and its runner branches;
  - the desktop respawn case.

  The desktop app and its bundled bridge ship together, so dropping exit code 86 from `BridgeSupervisedExitCode` needs no tag check. The supervised E2E test restarts by stop/start on the same data directory.
- **25.**
  - Delete `PluginRuntimeUpdateSpec`, the `runtimeUpdateSpec` overrides in 8 descriptors and `PluginControlCapability.runtimeUpdate`, with their tests and the HARNESS_CAPABILITIES rows. `PluginControlCapability` is an internal plugin-interface enum; the client-facing `PluginManagementCapability` has no such value, so no marker is needed.
  - Retire `path-runtime-authority-split` as abandoned at step 6.
- **26.** Delete `client/app/{macos,linux,windows,web}` and the Dart branches only those targets reach. `client/desktop` is the desktop product.

## Complexity budget

New mutable state: in step 14, `SessionWindowService` holds a rename token
counter and one `OptimisticRenameTracker` entry per renamed session. This
mirrors what `ProjectInventoryService` already does for projects. It is
justified because otherwise a rename visibly lags until the bridge echoes it.
In exchange, step 14 removes the cubit's whole list state and its SSE
subscription.

Everything else only removes state. The biggest removals:
- the unrendered `SessionListCubit` list state and its SSE subscription;
- the restart subsystem's exit-86 branches;
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
| Bridge services (steps 9–12, 24) | Owning suites, including `supervised_e2e_test`. A headless bridge start, relay connect, reconnect and clean shutdown. A desktop-supervised stop/start keeps the same data directory, now that restart is gone. |
| Client (steps 13–17) | Owning cubit, widget and golden suites. Headless iOS simulator (`xcrun simctl boot`, never Simulator.app) on the device the local testing setup assigns: project list, session list, rename showing the new title at once without a jump, session detail, settings without the voice-engine row, dictation still working, sign-out and in. |
| Desktop-specific (step 19) | Owning `module_desktop_core` suites (`dart test`). Notification-open routing on a macOS desktop build if a display is available. Otherwise record it as not run; it is not a pass. |
| Retired opencode-v2 live rows (Q6) | The cases of the retired plan's [Verification Matrix](../../completed/opencode-v2/PLAN.md#verification-matrix), headless on macOS arm64 with a real provider: managed OpenCode 2.1.4 (the pin at step 28; 2.0.11 is the v2 floor) fresh install and upgrade from 1.18.32, OpenCode 1.18.32 on PATH, and `--opencode-no-auto-start` attach. |
| Retired step-timers live rows (Q6) | The harness rows of the retired plan's [Regression Coverage](../../completed/step-timers/PLAN.md#regression-coverage) matrix (Claude Code, Codex, OpenCode, Pi, DeepSeek, Grok and another ACP harness where installed), on a headless live bridge plus the iOS simulator. Device, Android and macOS desktop rows are not run, per the testing rule. |
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

Step 27 reconciles them, and also runs the retired step-timers plan's step-6 reconciliation over `tools-and-file-changes.md`, `session-turns.md`, `transcript-turn-navigation.md` and the `docs/HARNESS_CAPABILITIES.md` "Live timers" section (Q6). Step 28 records Pass, Partial, Fail, Blocked or Not
run per row, and moves the plan to `.plan/completed/periodic-cleanup-2026-11/`
only when the rows pass. Reducing this matrix needs explicit user acceptance,
recorded here.

Accepted on 2026-11-03: the user accepted retirement with a reduced matrix, Q13 A
(the step-timer rows the current sign-ins could not run) and Q14 A (desktop
notification-open recorded as Not run). Every other row passed, or passed after
the step 28 fixes; the results are in the [tracker](TRACKER.md#step-28-verification).

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

## Plan review

`architecture-plan-review` (2026-11-03) rejected the first draft with eight
findings, all applied here and not re-reviewed:
1. Name step 14's rename owner (`SessionWindowService`), and write the
   confirmed title into the stored row.
2. Reorder steps so that parallel PRs never share files or runtime types.
3. Complete step 24's removal list. Its debug-only option was moot after Q1.
4. Split wire safety by contract and direction, and add the phone tags.
5. Place `RelayControlMessage` next to `RelayNoticeMessage`, with an unknown
   fallback.
6. Make step 10's updater composition a shared function, not a static.
7. Specify step 11's constructor output (`startupPolicy`).
8. Name step 19's routing owner.
