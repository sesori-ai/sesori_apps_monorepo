# Step 1 — Plan raised; old desktop plan superseded

Date: 2026-08-28.

## Verification that grounded this plan (summary)

Four independent code-verification passes ran before planning:

1. **Bridge supervised mode** — every prior-plan Phase-1 component intact and
   wired at `bridge/app/lib/src/runtime/bridge_runtime_runner.dart`; analyzer
   clean; 107 control tests pass. Only substantive post-pause rework:
   `ControlStatusNotifier` adapted to `PluginLifecycleService.metadataSnapshots`
   (parallel plugins) with an aggregate reduce that reads degraded whenever any
   eligible plugin isn't ready — the step-5 semantics fix target. Relay remains
   single-slot; takeover (4007) handling live.
2. **Client desktop packages** — all PR 2.1–2.5 deliverables present and green
   (`--fatal-infos`; 52 module + 16 shell tests). Control channel registered
   but dormant (nothing starts it — resumed by step 3). 22 post-pause commits,
   all keep-up edits; no removals. Desktop CI intact and release-isolated.
3. **Landscape since the pause** — `ensureRuntime` now contractually read-only;
   installs are per-plugin over the relay management API with SSE progress
   (kills the old provisioning-over-control-channel design); setup-aware
   dormant-by-default lifecycle with denylist eligibility; bridge-owned prompt
   queue, archiving, attachment references changed cockpit-facing contracts;
   `OrchestratorSessionStartResult.ready` + `firstPhoneConnected` exist;
   `DebugServer` is the loopback-data-path precedent (recorded in ROADMAP).
4. **Client UI landscape** — `module_prego` absorbed the leaf-widget
   extraction; `connection_overlay` coupling risk resolved (`ConnectionBanner`
   is clean); residual coupling: ~7 go_router widgets, ~19 `getIt` call sites,
   app-owned l10n (71-file fan-in), unabstracted `sign_in_with_apple` /
   `share_plus` / keyboard-visibility / voice+media capabilities; adaptive
   `session_split` two-pane shell exists; relay is the only client transport.

## Delivered in this step

- `.plan/active/desktop-app/` (PLAN.md, TRACKER.md, this file).
- `docs/desktop/` deleted (superseded; git history preserves it).
- Pointers repointed: `docs/ROADMAP.md` (Stage A + resume note + loopback
  consideration), `docs/VISION.md`, `client/AGENTS.md`, `client/README.md`,
  `client/desktop/AGENTS.md`, `client/module_desktop_core/AGENTS.md`,
  `.github/workflows/desktop-ci.yml` header.
- Drift truth-ups: `control_status_notifier.dart` / `control_channel_client.dart`
  stale docstrings; `bridge/app/AGENTS.md` `control/` no longer labeled a
  self-contained subsystem.

## Architecture plan review

Run 2026-08-28 via sub-agent: approve-with-fixes; six findings (process
repository as the sole Layer-2 process boundary, GUI `bridgeId` persistence
step, named `ControlCommandService`/`DesktopLogoutOrchestrator`, `tokenUpdate`
deletion, `DesktopInstanceStorage` Layer 1, `module_prego` theme-assembly
ownership) — all applied to PLAN.md before this PR.

## Verification

`dart analyze app` in `bridge/` clean after the docstring edits. Docs-only
otherwise; no Dart/Flutter suites required.
