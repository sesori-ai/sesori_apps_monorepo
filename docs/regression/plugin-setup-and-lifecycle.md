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
  configuration; startup revalidates the effective PATH or explicit `--hermes-bin` executable
  while preserving an explicit path as authoritative.
  Provider setup remains an out-of-band Hermes CLI action, so authentication-required
  Hermes entries give local setup guidance rather than offering bridge-managed login.
- DeepSeek is an ACP direct-CLI harness until managed packaging is activated.
  Its descriptor honors an explicit adapter path before PATH, performs bounded
  parseable-version and side-effect-free `check --state-dir` probes, advertises
  no install control, and gives local DeepSeek provider/setup guidance. Startup
  validates ACP v1 plus required DeepSeek extension metadata, owns one stdio
  child through the host process seam, degrades on an unexpected exit, lazily
  reconnects on demand, and shuts down idempotently without treating its own
  termination as a crash.
- Pi and Oh My Pi are registered harnesses with managed installs where a platform
  archive exists and explicit `--pi-bin`/`--omp-bin` paths stay authoritative. Pi
  sessions always launch with `--approve` (project-local Pi settings, extensions,
  skills, and prompt templates are trusted without prompts); OMP launches `omp acp`
  without an approval-mode override, leaving approval behavior to OMP. Provider login
  for both happens locally, never from the phone.
- Backend `tui.toast.show` SSE events render app-wide through the backend-neutral
  toast surface, presented with the design-system popup alert on the root
  navigator's overlay: every accepted toast is a new effect (equal repeated guidance
  included), toasts with no renderable text are dropped, and unknown variants
  degrade to info.
- Listings order by display name case-insensitively with the identifier as tie-breaker,
  and the default is the preferred harness when selectable, else the first selectable.
- Client-owned branding maps recognized built-in harness ids to their stable names and
  theme-specific artwork. Hermes renders as `Hermes Agent` with its light or dark
  NousResearch logo, Pi as `Pi` with its official glyph, and Oh My Pi as `Oh My Pi`
  with its official icon, while an unknown plugin id retains the generic icon and
  raw-id fallback.
- Harnesses start on demand unless eager; a transient one may suspend after a confirmed
  idle window and a resident one never does, and idle timeouts survive restart.
  Enable, disable, restart, and refresh are offered only where declared, with enable
  persisting eligibility, re-inspecting setup, then starting when ready.
- A resident harness that keeps the idle-timeout capability (Claude Code or Pi) reports
  the configured timeout instead of zero and consumes it internally through the host.
  Each plugin reaps its idle per-session CLI/RPC child process after that window and
  transparently resumes it on the next prompt, so the settings knob stays effective
  without a competing whole-plugin suspension timer. A runtime timeout change applies
  at each session's next idle transition without a plugin restart; no timeout keeps the
  child resident.
- A Claude session whose CLI scheduled a `ScheduleWakeup` loop wakeup is not reaped
  before the wakeup fires (the in-process timer would die and `--resume` cannot rearm
  it); a wakeup that never fires stops deferring one idle window past its fire time.
  The wakeup-fired turn the CLI starts on its own is surfaced busy, then idle on its
  result, and abort interrupts it like any enqueued turn.
- A busy harness conflicts explicitly, forcing needs confirmation and is sent once, the
  snapshot changes only on real content change with a new token, and a terminal failure
  removes only that harness's routing and new-session choice.
- Deliberate bridge shutdown enters each live harness's lifecycle shutdown before closing
  its transport directly. Stdio transports close child stdin before graceful termination
  and bounded force-kill. Managed runtime monitors disarm before transport or process
  teardown, so a clean owned-runtime exit is neither reported nor restarted as a crash.
- Codex keeps its long-lived app-server connection active with a local in-memory RPC;
  idle keepalives never trigger remote model discovery, and stop when the plugin is disposed.
- Codex session metadata uses the top-level `model` and `model_provider` values from
  `~/.codex/config.toml` when durable rollout metadata omits them; rollout metadata
  remains authoritative when present.
- Interactive authentication is optional per descriptor. A capable harness owns its
  backend process and credentials, exposes only a safe challenge and sanitized terminal
  state, cancels cooperatively, and settles process cleanup before the operation ends.
- Shared management metadata advertises authentication independently and reports idle,
  in-progress, or fail-closed unknown state. Device-code challenges remain request-scoped;
  only sealed completed, failed, or cancelled progress enters the global SSE stream.
- Setup and management snapshots report the display-ready version of the exact usable local
  runtime selected by each harness's existing inspection precedence. Older bridges and
  configurations without a selected versioned local runtime omit it; the mobile harness card
  shows a Version fact only when the bridge reports one.
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
| L2 Routine | Demand-driven start of a ready harness, clean lifecycle-owned bridge shutdown, Codex keepalive traffic remaining local and stopping on disposal, setup refresh, and the disable list surviving restart with eligibility and ordering intact. Package automation covers DeepSeek explicit/PATH probes, readiness, extension refusal, crash/reconnect, and idempotent shutdown before registry activation. Headless bridge; representative managed harness for start and shutdown, every registered harness for listing and ordering. |
| L3 Release | The management surface as rendered: per-harness selected runtime version when reported, setup, runtime and work state, capability-appropriate controls, built-in name and light/dark artwork, default badge, enable/disable, restart, and idle-timeout default plus override persisted across a bridge restart. Client end to end; every harness declaring the relevant capability must pass. |
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
- A harness card showing raw version-probe output, a rejected runtime's version, or a version
  different from the executable selected by setup inspection and runtime resolution.
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
- Direct API disposal bypassing lifecycle shutdown, or a deliberate owned-runtime exit
  being logged, failed, or restarted as an unexpected crash.
- A DeepSeek setup probe creates a session or mutates runtime state, accepts an
  old/malformed adapter version, exposes install before managed packaging, or
  keeps using a dead stdio child after an unexpected exit.

## Known Limitations

- The harness set comes from the current registry; unregistered in-development harnesses
  are out of scope, and no lifecycle path installs a runtime.
- DeepSeek remains unregistered in the bridge app at this stage; package-level
  descriptor behavior is covered, while registry/client behavior begins at its
  activation step. Managed installation remains intentionally unavailable.
- Backend authentication and credential persistence happen on the bridge machine. A forced
  disable leaves work interrupted.
- Hermes model/provider configuration is intentionally unavailable through Sesori and must
  be completed with the Hermes CLI before setup can become ready.
- Idle windows are minutes-order, so observing a real elapse belongs at L4 or above.
- Untested Hermes gap (remove this entry once verified): the targeted L4 idle
  respawn was never exercised for Hermes, because it needs a controlled
  idle-timeout window rather than an interactive session.
- Untested Hermes gap (remove this entry once verified): older-client
  unknown-id fallback and older-bridge presentation were never exercised end to
  end against a second build pair; only the automated fallback and branding
  checks passed.

## Sources

- `bridge/sesori_plugin_interface/lib/src/lifecycle/`; registered production plugin
  descriptors; plugin routing handlers
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`,
  `bridge/app/lib/src/runtime/plugin_registry.dart`
- `bridge/sesori_plugin_hermes/lib/src/runtime/hermes_plugin_descriptor.dart` and its tests
- `bridge/sesori_plugin_deepseek/lib/src/runtime/deepseek_plugin_descriptor.dart` and its tests
- `bridge/sesori_plugin_codex/lib/src/codex_plugin_impl.dart` and `codex_plugin_write_path_test.dart`
- `client/module_core/.../plugin_management_service.dart`, `PregoBrandLogo`, and the
  harness settings screen
- Tests: `plugin_lifecycle_service_test.dart`, per-plugin setup and client suites
