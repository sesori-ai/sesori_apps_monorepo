# Step 4 — Exit-code state machine + prompt answers

Date: 2026-08-28.

## Delivered

- Expanded Layer-3 `BridgeProcessService` with an independent desired-state
  enum and typed lifecycle states for login-required, contention, scheduled
  crash retry, and crash give-up.
- Centralized the supervised exit vocabulary and mapped clean/expected exits to
  stop, restart (86) to one immediate respawn, auth-required (87) to a
  no-thrash login-required state, and bridge contention (88) to a state that
  presentation can render without forcing a modal during hidden startup.
- Kept desired On across auth-required and subscribed to `AuthSession`; a later
  authenticated emission restarts the helper, while manual Off prevents that
  restart.
- Added bounded 1/2/4/8/16-second crash retries. Layer-3 supervision derives
  the five-minute stable-runtime reset from Layer-2 `BridgeStatusTracker`, whose
  connectivity is written by the dispatcher; an exhausted budget stops retrying
  and exposes the latest 20 helper log lines.
- Added lifecycle generations and timer cancellation so manual Start/Off
  supersedes an old exit decision or pending timer without a delayed duplicate
  helper. Automatic startup failures re-enter the same bounded budget, and an
  immediate sentinel restart waits for any failing startup slot to clear.
- Added Layer-3 `ControlCommandService` as the sole conversational
  GUI-to-helper orchestrator. It validates prompt ownership, calls Layer-2
  `ControlCommandRepository`, and removes the prompt only after Layer-1
  `ControlChannelApi` serializes the typed response and the Layer-0 socket
  accepts it. Expected `shutdown` remains in the process repository's atomic
  stop operation.
- Registered/exported the new service and states and updated bridge-connectivity
  regression guarantees and failure signals.

Take-over is intentionally composition rather than another process command: an
explicit `BridgeProcessService.start()` performs the plain respawn, then the
fresh replacement prompt is accepted through `ControlCommandService`.

No rendered UI or database behavior changes in this step; later tray/window
steps consume these states and actions.

## Architecture implementation review

Approved twice on 2026-08-28 with B-Client applied and no findings. The final
review covered the review-driven architecture changes and confirmed the strict
service → repository → API → foundation command path, Layer-2 status ownership,
Layer-4 dispatcher writes, serialized restart ownership, and generated DI
composition. Process/expected-stop ownership remains in the process repository,
and the two Layer-3 services do not depend on each other.

## Verification

- `client/module_desktop_core`: `dart analyze --fatal-infos` — clean.
- `client/module_desktop_core`: `dart test` — 106 tests passed.
- Focused process/command/API/DI suites — 30 tests passed, covering all deliberate
  exit classes, auth recovery versus manual Off, bounded give-up with recent
  logs, tracker-owned stable-runtime reset, early exit-86 restart serialization,
  both manual timer-cancellation paths, and prompt send/retention/stale-id behavior.
- `client/desktop`: `dart analyze --fatal-infos` — clean.
- `client/desktop`: `flutter test` — 22 tests passed; four-phase DI resolves
  both Layer-3 services.
- Regenerated desktop-core Injectable output with `build_runner`.
- Change size after review fixes: 1,397 changed lines including new files,
  under the 1,500-line soft cap.
