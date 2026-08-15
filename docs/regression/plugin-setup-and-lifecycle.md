# Plugin Setup And Lifecycle

## Capability

How the bridge discovers, gates, starts, suspends, and reports each registered coding
harness: setup inspection, eligibility, runtime resolution, demand-driven activation and
idle suspension, the management snapshot, and lifecycle commands.

## Required Behavior

- Registration is inert: it contributes CLI options and listing presence but starts
  nothing, and all registered harnesses appear in the snapshots. Setup inspection never
  installs, logs in, or starts a backend, reporting a bounded state and action hint
  without secrets or raw output.
- Runtime resolution before start may resolve a suitable existing or managed binary but
  never downloads or mutates files, and failure there is non-fatal. The persisted disable
  list is the only durable eligibility policy, with setup deciding blocked versus routable.
- Hermes is a direct-CLI harness with no managed install. Setup distinguishes a missing or
  pre-ACP binary, a Hermes Agent release below `0.20.0`, and missing model/provider
  configuration; startup revalidates both PATH and explicit `--hermes-bin` executables while
  preserving an explicit path as authoritative.
  Model/provider setup remains an out-of-band Hermes CLI action, so authentication-required
  Hermes entries give local setup guidance rather than offering bridge-managed login.
- Listings order by display name case-insensitively with the identifier as tie-breaker,
  and the default is the preferred harness when selectable, else the first selectable.
- Client-owned branding maps recognized built-in harness ids to their stable names and
  theme-specific artwork. Hermes renders as `Hermes Agent` with its light or dark
  NousResearch logo, while an unknown plugin id retains the generic icon and raw-id fallback.
- Harnesses start on demand unless eager; a transient one may suspend after a confirmed
  idle window and a resident one never does, and idle timeouts survive restart.
  Enable, disable, restart, and refresh are offered only where declared, with enable
  persisting eligibility, re-inspecting setup, then starting when ready.
- A busy harness conflicts explicitly, forcing needs confirmation and is sent once, the
  snapshot changes only on real content change with a new token, and a terminal failure
  removes only that harness's routing and new-session choice.
- Interactive authentication is optional per descriptor. A capable harness owns its
  backend process and credentials, exposes only a safe challenge and sanitized terminal
  state, cancels cooperatively, and settles process cleanup before the operation ends.
- Shared management metadata advertises authentication independently and reports idle,
  in-progress, or fail-closed unknown state. Device-code challenges remain request-scoped;
  only sealed completed, failed, or cancelled progress enters the global SSE stream.
- The bridge exposes explicit plugin-scoped start and cancel routes. Duplicate starts join
  the active operation, management commands conflict while it runs, cancellation settles
  upstream cleanup, and setup reinspection remains authoritative before normal startup.
- Client authentication orchestration accepts only absolute HTTPS challenge URLs, retains
  challenge data ephemerally, and opens the browser only after an explicit user action.
  Start and cancel response loss remain uncertain; terminal SSE is presented only for an
  operation this client started, then triggers an authoritative management refresh.
- Authentication ownership and challenge state are fenced to the current connection epoch
  and bridge identity and clear on reconnect, identity change, or disposal. External
  operations still update shared management metadata without claiming local presentation.
- Mobile shows login only for authentication-required harnesses that declare the capability.
  Its device-code sheet keeps anti-phishing guidance and the selectable/copyable one-time
  code visible, opens the external browser only on explicit intent, and separates sheet
  dismissal from cancellation. Terminal progress closes the sheet and refreshes setup.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | A started bridge inspects every registered harness and publishes coherent setup and management snapshots. A ready fixture has a selectable default; a fixture with no usable harness has zero selectable entries and no default without failing startup. Headless bridge; all registered harnesses listed. |
| L2 Routine | Demand-driven start of a ready harness, setup refresh, and the disable list surviving restart with eligibility and ordering intact. Headless bridge; representative harness for start, every registered harness for listing and ordering. |
| L3 Release | The management surface as rendered: per-harness setup, runtime and work state, capability-appropriate controls, built-in name and light/dark artwork, default badge, enable/disable, restart, and idle-timeout default plus override persisted across a bridge restart. Client end to end; every harness declaring the relevant capability must pass. |
| L4 Extended | Busy conflict with force confirmation and cancellation, authentication start/join/cancel plus shutdown cleanup, idle suspension elapsing then returning on demand, harnesses blocked by missing runtime or authentication, a terminally failed harness leaving others usable, a bridge with no usable harness, an externally managed configuration, two harnesses active at once, second mobile platform. Live plugin where a real backend must start or be interrupted, client end to end where card state is claimed. |
| L5 Full | Every registered production harness through inspect, enable, disable, restart, refresh, and idle behavior on a supported platform, plus forward-compatible presentation of an unknown harness or capability and the reported state of a session interrupted by a forced disable. Live plugin and client end to end as each entry requires. |

## Exploration Guidance

Vary which harness runs first and which stays disabled, and the configuration: default
managed, explicit binary path, externally managed backend. Vary the trigger between app
and management API, whether a session is idle or working, and fresh versus reused data
directories. For Hermes, vary missing and pre-ACP installs, a release below `0.20.0`, an
unconfigured model/provider, PATH discovery, and `--hermes-bin`. Restore eligibility,
timeouts, and sessions afterwards.

## Failure Signals

- Setup inspection installing, logging in, starting a backend, or leaking secrets or raw
  output; resolution mutating runtime files; a disabled harness probed or started.
- An eligible harness dropped from listings, a drifting or unselectable default, or
  snapshot tokens that miss real changes.
- A control offered for an undeclared capability, a supported control missing, a busy
  harness accepting a safe command, or idle suspension on a resident or busy harness.
- A missing authentication state from an older bridge decoding as anything but idle, a
  future state or conflict reason failing open, challenge data entering snapshots/SSE, or
  a failed progress payload without its required sanitized message.
- A malformed or non-HTTPS verification URL reaching the launcher, a browser opening
  without explicit user intent, response loss reported as definite failure, a fast terminal
  event being lost, or stale challenge state surviving reconnect or bridge replacement.
- Login shown without both capability and authentication-required setup, terminal-only
  guidance shown despite mobile login support, sheet dismissal cancelling upstream, or a
  browser/copy failure removing the challenge before the user can retry.
- One failing harness taking down the rest of the bridge, or an empty picker
  instead of the explicit no-harness state when none is usable.

## Known Limitations

- The harness set comes from the current registry; unregistered in-development harnesses
  are out of scope, and no lifecycle path installs a runtime.
- Backend authentication and credential persistence happen on the bridge machine. A forced
  disable leaves work interrupted.
- Hermes model/provider configuration is intentionally unavailable through Sesori and must
  be completed with the Hermes CLI before setup can become ready.
- Idle windows are minutes-order, so observing a real elapse belongs at L4 or above.

## Sources

- `bridge/sesori_plugin_interface/lib/src/lifecycle/`; registered OpenCode, Codex,
  Cursor, Claude Code, and Hermes Agent descriptors; plugin routing handlers
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`,
  `bridge/app/lib/src/bridge/runtime/plugin_registry.dart`
- `bridge/sesori_plugin_hermes/lib/src/runtime/hermes_plugin_descriptor.dart` and its tests
- `client/module_core/.../plugin_management_service.dart`, `PregoBrandLogo`, and the
  harness settings screen
- Tests: `plugin_lifecycle_service_test.dart`, per-plugin setup and client suites
