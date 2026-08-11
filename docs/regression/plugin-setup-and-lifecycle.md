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
- Listings order by display name case-insensitively with the identifier as tie-breaker,
  and the default is the preferred harness when selectable, else the first selectable.
- Harnesses start on demand unless eager; a transient one may suspend after a confirmed
  idle window and a resident one never does, and idle timeouts survive restart.
  Enable, disable, restart, and refresh are offered only where declared, with enable
  persisting eligibility, re-inspecting setup, then starting when ready.
- A busy harness conflicts explicitly, forcing needs confirmation and is sent once, the
  snapshot changes only on real content change with a new token, and a terminal failure
  removes only that harness's routing and new-session choice.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | A started bridge inspects every registered harness and publishes coherent setup and management snapshots. A ready fixture has a selectable default; a fixture with no usable harness has zero selectable entries and no default without failing startup. Headless bridge; all registered harnesses listed. |
| L2 Routine | Demand-driven start of a ready harness, setup refresh, and the disable list surviving restart with eligibility and ordering intact. Headless bridge; representative harness for start, every registered harness for listing and ordering. |
| L3 Release | The management surface as rendered: per-harness setup, runtime and work state, capability-appropriate controls, default badge, enable/disable, restart, and idle-timeout default plus override persisted across a bridge restart. Client end to end; every harness declaring the relevant capability must pass. |
| L4 Extended | Busy conflict with force confirmation and cancellation, idle suspension elapsing then returning on demand, harnesses blocked by missing runtime or authentication, a terminally failed harness leaving others usable, a bridge with no usable harness, an externally managed configuration, two harnesses active at once, second mobile platform. Live plugin where a real backend must start or be interrupted, client end to end where card state is claimed. |
| L5 Full | Every registered production harness through inspect, enable, disable, restart, refresh, and idle behavior on a supported platform, plus forward-compatible presentation of an unknown harness or capability and the reported state of a session interrupted by a forced disable. Live plugin and client end to end as each entry requires. |

## Exploration Guidance

Vary which harness runs first and which stays disabled, and the configuration: default
managed, explicit binary path, externally managed backend. Vary the trigger between app
and management API, whether a session is idle or working, and fresh versus reused data
directories. Restore eligibility, timeouts, and sessions afterwards.

## Failure Signals

- Setup inspection installing, logging in, starting a backend, or leaking secrets or raw
  output; resolution mutating runtime files; a disabled harness probed or started.
- An eligible harness dropped from listings, a drifting or unselectable default, or
  snapshot tokens that miss real changes.
- A control offered for an undeclared capability, a supported control missing, a busy
  harness accepting a safe command, or idle suspension on a resident or busy harness.
- One failing harness taking down the rest of the bridge, or an empty picker
  instead of the explicit no-harness state when none is usable.

## Known Limitations

- The harness set comes from the current registry; unregistered in-development harnesses
  are out of scope, and no lifecycle path installs a runtime.
- Backend authentication happens on the bridge machine and ends this scope, and a forced
  disable leaves work interrupted.
- Idle windows are minutes-order, so observing a real elapse belongs at L4 or above.

## Sources

- `bridge/sesori_plugin_interface/lib/src/lifecycle/`; registered OpenCode, Codex,
  Cursor, and Claude Code descriptors; plugin routing handlers
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`,
  `bridge/app/lib/src/bridge/runtime/plugin_registry.dart`
- `client/module_core/.../plugin_management_service.dart` and the harness settings screen
- Tests: `plugin_lifecycle_service_test.dart`, per-plugin setup and client suites
