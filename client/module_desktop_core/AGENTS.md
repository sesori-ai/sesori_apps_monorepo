# sesori_desktop_core — Pure Dart Desktop Business Module

Desktop-specific business logic: bridge helper process supervision,
control-channel orchestration, tray/window state, and desktop cubits. Zero
Flutter SDK dependency — testable with plain `dart test`. `client/desktop` is
the only production consumer; `module_core` must NEVER depend on this package.

## Target Package Structure (built out phase by phase — see docs/desktop/PLAN.md §6)

```
lib/src/
├── foundation/              # Layer 0
│   ├── platform/            #   capability interfaces: SystemTray, WindowHost, LaunchAtLogin, AppUpdater
│   └── control_channel_server.dart  # GUI-hosted loopback WS host + per-spawn secret
├── api/                     # Layer 1 — bridge_process_api, desktop_instance_api, app_update_api, storages
├── repositories/            # Layer 2 — bridge_process_repository, desktop_instance_repository, app_update_repository
├── trackers/                # Layer 2 — reactive state derived from events (status, prompts, helper logs)
├── services/                # Layer 3 — bridge_process_service, desktop_instance_service, desktop_update_service
├── control/                 # Layer 4 — control_message_dispatcher (writes DOWN into trackers/token seam)
├── cubits/                  # Layer 4 — desktop state management (bridge_control, ...)
└── di/                      # @InjectableInit configureDesktopCoreDependencies
```

## Rules

- **NO `package:flutter*` imports.** Pure Dart only; use `package:meta` for
  annotations and `package:test` + `mocktail` for tests.
- Follow the strict layer architecture from the repo-root `AGENTS.md`
  (foundation → api → repositories/trackers → services → control/cubits). No
  layer skipping, no same-layer cross-dependencies.
- May depend on `sesori_dart_core` (shared relay/auth seams via its re-exports)
  and `sesori_shared` (control-protocol DTOs). MUST NOT import `sesori_auth`
  directly, product shells, or `module_prego`.
- Cubits are NOT registered in DI — the shell constructs them in
  `BlocProvider(create:)`. Everything else registers here via `injectable`
  annotations, never in `client/desktop`.
- Platform capabilities (tray, window, launch-at-login, updater) are abstract
  interfaces in `foundation/platform/`; `client/desktop` provides the concrete
  Flutter/plugin adapters. Adapters stay dumb — no process/status logic.
- Reactive, never polling: consume the control-channel/process event streams;
  no `Timer.periodic` re-fetching.
- Error handling per repo-root `AGENTS.md`: never silently swallow; pass errors
  as logger arguments, don't string-interpolate.

## Commands

```bash
dart test                                                 # from this dir
dart analyze --fatal-infos
dart run build_runner build --delete-conflicting-outputs  # after changing annotated classes
```
