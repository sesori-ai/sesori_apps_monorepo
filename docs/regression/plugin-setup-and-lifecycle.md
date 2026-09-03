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
- DeepSeek is an ACP harness with six-platform managed package archives. Its
  descriptor honors an explicit `--deepseek-bin` path before a compatible PATH
  release (`>=0.1.0`) and the exact managed `0.1.1` release. An old or malformed
  PATH candidate falls through to managed selection. It performs bounded parseable-version and
  side-effect-free `check --state-dir` probes, advertises install only on a
  supported platform without an explicit path, and gives local DeepSeek
  provider/setup guidance. Managed installation verifies the immutable archive
  digest and preserves the packaged launcher with its bundled Node runtime. Startup
  validates ACP v1 plus required DeepSeek extension metadata, owns one stdio
  child through the host process seam, degrades on an unexpected exit, lazily
  reconnects on demand, and shuts down idempotently without treating its own
  termination as a crash.
- Standard ACP owns DeepSeek lifecycle, prompts, config options, and permissions;
  `deepseek/*` is limited to catalog, detached history, rename, questions, and
  bounded statuses on that same connection. Normal `DSH_HOME` remains the source
  of settings, credentials, providers, and skills but its session root is never
  scanned. Session, attachment, query, and spill mutations stay below plugin
  state, and session-local model/reasoning writes never modify user settings.
- GitHub Copilot is a standard ACP v1 harness launched as
  `copilot --no-auto-update --acp`. Setup keeps an explicit `--copilot-bin`
  authoritative, otherwise prefers a compatible PATH release (`>=1.0.78`) over
  the exact managed release. Version output must retain Copilot branding, and
  startup uses only the runtime selected during provisioning. Authentication is
  local and out of band; setup never reads credentials or runs `copilot login`.
  An unexpected owned-process exit degrades only Copilot, and demand reconnects
  it without affecting another harness.
- Grok Build is a direct-CLI ACP v1 harness with no managed install. An explicit
  `--grok-bin` path is authoritative; otherwise setup uses `grok` from PATH and
  requires version `1.0.5` or newer. Setup inspection and pre-start resolution
  run only a bounded `--version` probe: they never read credentials, invoke
  login, create a session, or start ACP. Startup launches exactly
  `--no-auto-update agent --no-leader stdio` through the host process seam and
  accepts only advertised headless authentication. Interactive-only
  authentication becomes local-login-required without invoking it. An
  unexpected exit degrades only Grok, demand reconnects it, and owned shutdown
  remains idempotent and is not reported as a crash.
- Pi and Oh My Pi are registered harnesses with managed installs where a platform
  archive exists and explicit `--pi-bin`/`--omp-bin` paths stay authoritative. Pi
  sessions always launch with `--approve` (project-local Pi settings, extensions,
  skills, and prompt templates are trusted without prompts); OMP launches `omp acp`
  without an approval-mode override, leaving approval behavior to OMP. Provider login
  for both happens locally, never from the phone.
- Backend `tui.toast.show` SSE events render through the backend-neutral toast
  surface, presented with the design-system popup alert on the root navigator's
  overlay. Session-attributed events appear only while that session's detail or
  diffs route is on top; unattributed events remain app-wide. Every accepted toast
  is a new effect (equal repeated guidance included), toasts with no renderable
  text are dropped, and unknown variants degrade to info.
- Listings order by display name case-insensitively with the identifier as tie-breaker,
  and the default is the preferred harness when selectable, else the first selectable.
- Client-owned branding maps recognized built-in harness ids to their stable names and
  theme-specific artwork. Hermes renders as `Hermes Agent` with its light or dark
  NousResearch logo, Pi as `Pi` with its official glyph, and Oh My Pi as `Oh My Pi`
  with its official icon. DeepSeek renders as `DeepSeek` with its official
  theme-independent brand-blue whale mark. GitHub Copilot renders with its
  Primer interface icon in black or white for the active theme. Grok renders as
  `Grok Build` with xAI's dark mark on light UI and light mark on dark UI.
  Surfaces without recognized metadata retain the generic icon and raw-id
  fallback.
- Harnesses start on demand unless eager; a transient one may suspend after a confirmed
  idle window and a resident one never does, and idle timeouts survive restart. With no
  configured default or per-harness override, every harness uses the bridge's 45-minute
  fallback. Enable, disable, restart, and refresh are offered only where declared, with
  enable persisting eligibility, re-inspecting setup, then starting when ready.
- Session-open plugin warm-up is one global bridge setting, enabled by default and persisted
  in `config.json`. While enabled, the bridge starts the plugin owning a session when a
  client begins viewing that session; loading the session screen never waits for warm-up.
  Enabling it in app settings immediately warms sessions already being viewed, without a
  bridge restart or reconnect. Disabling it immediately prevents future starts, including a
  start whose session lookup has not completed, but does not stop an already-running plugin;
  ordinary residency and idle-suspension policy still owns shutdown.
- A resident harness that keeps the idle-timeout capability (Claude Code or Pi) reports
  the configured timeout instead of zero and consumes it internally through the host.
  Each plugin reaps its idle per-session CLI/RPC child process after that window and
  transparently resumes it on the next prompt, so the settings knob stays effective
  without a competing whole-plugin suspension timer. A runtime timeout change
  immediately re-arms each currently idle session from the change, while busy
  sessions pick it up at their next idle transition; no timeout invalidates the
  existing idle timer and keeps the child resident.
- A Claude session whose CLI scheduled a `ScheduleWakeup` loop wakeup is not reaped
  before the wakeup fires (the in-process timer would die and `--resume` cannot rearm
  it); a wakeup that never fires stops deferring one idle window past its fire time.
  The wakeup-fired turn the CLI starts on its own is surfaced busy, then idle on its
  result, and abort interrupts it like any enqueued turn.
- A Claude session with a running background task (sub-agent, shell, or workflow the
  CLI reported) is busy for lifecycle purposes: the idle reap does not arm, the plugin
  work state stays busy so a safe stop or suspension refuses, and only a forced stop, a
  full-scope session stop, delete, or process exit ends it. A main-agent-only stop
  keeps the process resident for its tasks.
- A busy harness conflicts explicitly, forcing needs confirmation and is sent once, the
  snapshot changes only on real content change with a new token, and a terminal failure
  removes only that harness's routing and new-session choice.
- Deliberate bridge shutdown enters each live harness's lifecycle shutdown before closing
  its transport directly. Stdio transports close child stdin before graceful termination
  and bounded force-kill. Managed runtime monitors disarm before transport or process
  teardown, so a clean owned-runtime exit is neither reported nor restarted as a crash.
- Codex keeps its long-lived app-server connection active with a local in-memory RPC;
  idle keepalives never trigger remote model discovery, and stop when the plugin is disposed.
  A root remains busy for lifecycle and safe-stop purposes while any tracked
  child turn runs, even after the root's own turn completes; disconnect clears
  that connection-scoped child state and emits the visible idle cleanup once.
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
- Mobile and desktop show login only for authentication-required harnesses that declare the
  capability. Their shared device-code sheet keeps anti-phishing guidance and the
  selectable/copyable one-time code visible, opens the external browser only on explicit
  intent, and separates sheet dismissal from cancellation. Only one harness authentication
  flow can start at a time; an uncertain cancellation challenge can be reopened from its
  harness row. Terminal progress closes the sheet and refreshes setup.
- Mobile and desktop offer a per-harness catalog scan on Settings to Harnesses, the pointer
  and screen-reader equivalent of the lists' second-stage pull. It appears only for a harness
  whose reported runtime state is routable, so a setup-blocked or failed harness the bridge
  would reject is not offered a tappable no-op. The action reports work in place while any
  scan covering that harness runs, whichever surface started it, and does not accept a
  second start until it settles.
- A scan the user aimed at one harness reports its own rejection on that harness's card,
  unlike the all-harness fan-out, which silently skips a harness it cannot import from.
  Not-importable, unsupported-bridge, and failed-request answers each read differently and
  are cleared by the next attempt on that harness, whichever surface makes it. A start whose
  outcome is unknown leaves the harness in the running scan rather than reporting a refusal
  beside its own progress, so a card never pairs work in flight with a reason it failed. The
  underlying request error is kept for the local log and never rendered.
- A scan started from the harness settings surface announces how it ended there, because that
  surface carries no progress row and the published result clears itself before the user could
  reach a list to read it. What it found, a partial failure, and a total failure each read
  differently. A scan started from a list is not announced again here, and neither is a start
  the bridge refused outright, which the harness card already reports; a run that ends without
  a terminal outcome announces nothing at all.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | A started bridge inspects every registered harness and publishes coherent setup and management snapshots. A ready fixture has a selectable default; a fixture with no usable harness has zero selectable entries and no default without failing startup. Headless bridge; all registered harnesses listed. |
| L2 Routine | Demand-driven start of a ready harness, non-blocking session-open warm-up plus immediate app-setting enable/disable, clean lifecycle-owned bridge shutdown, Codex keepalive traffic remaining local and stopping on disposal, Codex root work remaining busy until its last child settles, setup refresh, and the disable list surviving restart with eligibility and ordering intact. Package automation covers DeepSeek explicit/PATH/managed selection, immutable six-platform archive metadata, readiness, extension refusal, crash/reconnect, and idempotent shutdown. Copilot package automation covers branded version parsing, explicit/PATH/managed precedence, exact six-archive metadata, provisioning-authoritative startup, and local-login-required failure. Grok package automation covers explicit/PATH authority, bounded branded version parsing, read-only inspection, local-login-required startup, crash/reconnect, and owned shutdown. Headless bridge; representative managed harness for start and shutdown, every registered harness for listing and ordering. |
| L3 Release | The shared mobile and desktop management surface as rendered: per-harness selected runtime version when reported, setup, runtime and work state, capability-appropriate controls, built-in name and light/dark artwork, default badge, enable/disable, restart, idle-timeout default plus override persisted across a bridge restart, and the per-harness catalog scan on a routable harness including its in-place progress and the announcement of what it found. Copilot renders the exact `GitHub Copilot` name and Primer interface icon in both themes. Grok renders as `Grok Build` with the official contrasting mark, selected version, local setup guidance, and no managed-install control. Client end to end on both product surfaces; every harness declaring the relevant capability must pass. |
| L4 Extended | Busy conflict with force confirmation and cancellation, authentication start/join/cancel plus shutdown cleanup, peer harness login rows disabled throughout a retained authentication operation, an owning row reopening a dismissed or `cancellingUncertain` challenge, idle suspension elapsing then returning on demand, harnesses blocked by missing runtime or authentication with no catalog-scan action offered on them, a targeted scan rejected by the bridge reporting on its own card, a terminally failed harness leaving others usable, a bridge with no usable harness, an externally managed configuration, two harnesses active at once, second mobile platform. Copilot live coverage includes an unexpected owned-process exit followed by demand reconnect and a deliberate clean shutdown that is not reported as a crash. Grok live coverage includes the same failure isolation and demand reconnect with a supported user-installed release. Live plugin where a real backend must start or be interrupted, client end to end where card state is claimed. |
| L5 Full | Every registered production harness through inspect, enable, disable, restart, refresh, and idle behavior on a supported platform, plus forward-compatible presentation of an unknown harness or capability and the reported state of a session interrupted by a forced disable. Compatibility pairs prove an older client treats `copilot` and `grok` as unknown raw-id/generic-icon harnesses without decode failure, while an older bridge simply supplies no corresponding entry to a newer client. Live plugin and client end to end as each entry requires. |

## Exploration Guidance

Vary which harness runs first and which stays disabled, and the configuration: default
managed, explicit binary path, externally managed backend. Vary the trigger between app
and management API, whether a session is idle or working, and fresh versus reused data
directories. For Hermes, vary missing and pre-ACP installs, a release below `0.20.0`, an
unconfigured model/provider, PATH discovery, and `--hermes-bin`. Restore eligibility,
timeouts, and sessions afterwards. For Copilot, vary missing, malformed, too-old,
compatible PATH, managed, and explicit runtimes; authenticated and unauthenticated
normal configuration; owned-process exit; and bridge restart. For Grok, vary
missing, malformed, too-old, current PATH, and authoritative explicit binaries;
headless and interactive-only authentication; catalog refresh; enable/disable;
owned-process exit; and restart.

## Failure Signals

- Setup inspection installing, logging in, starting a backend, or leaking secrets or raw
  output; resolution mutating runtime files; a disabled harness probed or started.
- An eligible harness dropped from listings, a drifting or unselectable default, or
  snapshot tokens that miss real changes.
- A harness card showing raw version-probe output, a rejected runtime's version, or a version
  different from the executable selected by setup inspection and runtime resolution.
- A control offered for an undeclared capability, a supported control missing, a busy
  harness accepting a safe command, or idle suspension on a resident or busy harness.
- The Claude idle reap or a safe stop kills a resident process while a background
  sub-agent it reported is still running.
- Codex reports idle, permits lifecycle suspension, or disappears from active
  work while a tracked child turn still runs, or retains child busy state after
  disconnect or deletion.
- Opening a session while warm-up is enabled blocks screen loading, starts the wrong plugin,
  or fails silently; changing the app setting requires a restart/reconnect, disabling it
  still admits a start after an in-flight session lookup returns, or warm-up bypasses normal
  plugin eligibility and lifecycle ownership.
- A catalog scan offered on a harness the bridge will not import from, a scan already
  covering a harness still accepting another start from its card, a targeted rejection
  landing on the wrong harness or on none, or a request error reaching the card as text.
- A scan started from harness settings finishing with no announcement, one announced twice,
  a scan started elsewhere announced there, or a refused start reported both on its card and
  as a finished scan.
- A missing authentication state from an older bridge decoding as anything but idle, a
  future state or conflict reason failing open, challenge data entering snapshots/SSE, or
  a failed progress payload without its required sanitized message.
- A malformed or non-HTTPS verification URL reaching the launcher, a browser opening
  without explicit user intent, response loss reported as definite failure, a fast terminal
  event being lost, or stale challenge state surviving reconnect or bridge replacement.
- Login shown without both capability and authentication-required setup, terminal-only
  guidance shown despite client login support, concurrent harness login rows remaining
  actionable, a dismissed or uncertain-cancellation challenge becoming impossible to
  reopen, sheet dismissal cancelling upstream or enabling peer login rows, a product shell
  diverging from the shared management view, or a
  browser/copy failure removing the challenge before the user can retry.
- One failing harness taking down the rest of the bridge, or an empty picker
  instead of the explicit no-harness state when none is usable.
- Direct API disposal bypassing lifecycle shutdown, or a deliberate owned-runtime exit
  being logged, failed, or restarted as an unexpected crash.
- A DeepSeek setup probe creates a session or mutates runtime state, accepts an
  old/malformed adapter version, selects managed runtime ahead of a supported
  PATH release, offers install with an explicit path or on an unsupported
  platform, or keeps using a dead stdio child after an unexpected exit.
- Copilot setup accepts unbranded version output, falls back from a provisioned
  runtime during start, mutates the user's configuration, offers in-app login,
  or leaves another harness unavailable after Copilot exits.
- Grok setup accepts an unrelated or malformed version line, falls through from
  an explicit path to PATH, performs login or ACP work during inspection, offers
  managed installation, launches with leader/auto-update attachment enabled, or
  leaves another harness unavailable after Grok exits.
- A recognized Grok entry renders the raw ID or generic icon, swaps its supplied
  light/dark marks, or an unknown plugin ID stops using the generic fallback.

## Known Limitations

- The harness set comes from the current registry; unregistered in-development harnesses
  are out of scope.
- DeepSeek is registered and enabled by default. Its official theme-independent
  brand-blue artwork, local provider setup guidance, and managed install controls
  follow the same backend-neutral registry and client surfaces as every other harness.
- Backend authentication and credential persistence happen on the bridge machine. A forced
  disable leaves work interrupted. Grok installation, updates, interactive login,
  API-key, enterprise, and custom-model configuration remain local and out of
  band; readiness proves only the CLI version, not service entitlement. Copilot
  exposes local recovery guidance only;
  Sesori neither implements its terminal-auth flow nor reads its credential store.
  Copilot CLI is an upstream public preview and still requires eligible GitHub
  Copilot access; entitlement and service availability are not install success.
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
  `bridge/app/lib/src/services/plugin_warmup_service.dart`,
  `bridge/app/lib/src/listeners/plugin_warmup_setting_listener.dart`,
  `bridge/app/lib/src/listeners/viewed_session_plugin_warmup_listener.dart`,
  `bridge/app/lib/src/runtime/plugin_registry.dart`
- `bridge/sesori_plugin_hermes/lib/src/runtime/hermes_plugin_descriptor.dart` and its tests
- `bridge/sesori_plugin_deepseek/lib/src/runtime/deepseek_plugin_descriptor.dart` and its tests
- `bridge/sesori_plugin_copilot/lib/src/runtime/copilot_plugin_descriptor.dart` and its tests
- `bridge/sesori_plugin_grok/lib/src/runtime/grok_plugin_descriptor.dart` and its tests
- `bridge/sesori_plugin_grok/lib/src/grok_plugin_impl.dart` and `grok_plugin_test.dart`
- `bridge/sesori_plugin_codex/lib/src/codex_plugin_impl.dart` and `codex_plugin_write_path_test.dart`
- `client/module_core/.../plugin_management_service.dart`, `PregoBrandLogo`, the
  Grok marks and `client/module_prego/BRAND_ASSETS.md`, and the harness settings
  screen
- Tests: `plugin_lifecycle_service_test.dart`, per-plugin setup and client suites
