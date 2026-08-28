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
- Added bounded 1/2/4/8/16-second crash retries. A process that has remained up
  for five minutes after its control handshake resets the crash budget; an
  exhausted budget stops retrying and exposes the latest 20 helper log lines.
- Added lifecycle generations and timer cancellation so manual Start/Off
  supersedes an old exit decision or pending timer without a delayed duplicate
  helper. Automatic startup failures re-enter the same bounded budget.
- Added Layer-3 `ControlCommandService` as the sole conversational
  GUI-to-helper sender. It sends typed `prompt_response` frames only for a
  currently pending prompt and removes the prompt only after the live socket
  accepts the frame. Expected `shutdown` remains in the repository's atomic
  stop operation.
- Registered/exported the new service and states and updated bridge-connectivity
  regression guarantees and failure signals.

Take-over is intentionally composition rather than another process command: an
explicit `BridgeProcessService.start()` performs the plain respawn, then the
fresh replacement prompt is accepted through `ControlCommandService`.

No rendered UI or database behavior changes in this step; later tray/window
steps consume these states and actions.

## Architecture implementation review

Approved 2026-08-28 with B-Client applied and no findings. The reviewer
confirmed process and expected-stop ownership remain in the repository,
Layer-3 dependencies point downward, the two services do not depend on each
other, manual generations prevent duplicate lifecycle work, contention remains
state, and inbound versus conversational control ownership stays separated.

## Verification

- `client/module_desktop_core`: `dart analyze --fatal-infos` — clean.
- `client/module_desktop_core`: `dart test` — 99 tests passed.
- Focused process/command/DI suites — 23 tests passed, covering all deliberate
  exit classes, auth recovery versus manual Off, bounded give-up with recent
  logs, stable-runtime reset, both manual timer-cancellation paths, and prompt
  send/retention/stale-id behavior.
- `client/desktop`: `dart analyze --fatal-infos` — clean.
- `client/desktop`: `flutter test` — 22 tests passed; four-phase DI resolves
  both Layer-3 services.
- Regenerated desktop-core Injectable output with `build_runner`.
- Change size: 1,104 changed lines including new files, under the 1,200-line
  soft cap.
