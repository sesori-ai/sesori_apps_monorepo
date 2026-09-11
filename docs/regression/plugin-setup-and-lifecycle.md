# Plugin Setup And Lifecycle

## Capability

How the bridge discovers, gates, starts, suspends, and reports each registered coding
harness: setup inspection, eligibility, runtime resolution, demand-driven activation and
idle suspension, the management snapshot, and lifecycle commands.

## Required Behavior

- Existing chat interaction consumes the shared management snapshot, not a separate
  poller. It resolves the session's exact plugin ID rather than the default harness;
  a missing exact entry blocks only that chat, and unrelated harness changes do not
  reload it. Disabled, authentication-required, missing-runtime, unavailable,
  stopping, uninspected, unknown and missing-harness states block interaction. Ready
  setup with dormant, starting, active or degraded runtime remains routable.
- Only an authentication-required block offers Recheck. It requests fresh management
  evidence when authentication may have been restored elsewhere; it does not authenticate.
  Disabled and every other blocked reason omit that action. A first check failure
  remains blocked and keeps its original error for local diagnosis. Retained refresh
  errors show a warning without changing the last established decision. An older public
  bridge without management support keeps interaction available with an upgrade
  warning; a request failure is never treated as endpoint absence.
- Disconnect preserves an established block. Reconnect requires fresh connected
  management evidence before restoring positive availability, then refreshes session
  prerequisites before restoring blocked input. Setup evidence is advisory rather
  than continuous credential validation: a provider can still reject an admitted
  turn before a later management refresh reports the change.

- Registration is inert: it contributes CLI options and listing presence but starts
  nothing, and all registered harnesses appear in the snapshots. Setup inspection never
  installs, logs in, or starts a backend, reporting a bounded state and action hint
  without secrets or raw output.
- Host process spawning explicitly selects environment inheritance. Existing registered
  harnesses retain inherited environment behavior; an isolated launch must not receive
  parent variables again through either the OS spawn or ACP host adapter.
- Plugin JSON child scopes select one directory segment without filesystem I/O, retain
  bare-file/reserved-name restrictions, and share the root's per-directory atomic-update
  lock owner across authentication and live hosting. An interrupted update leaves the
  last completed settings write readable.
- ACP output interception, when configured, bounds each raw partial line before decoding
  or logging. Consumed stdout/stderr never reaches logs; other bytes and useful diagnostics
  remain intact, including fragmented UTF-8, CRLF and EOF partial lines. Failures never echo
  payload text, and idle-stream interception must not delay cancellation or process cleanup.
  A failed interceptor detaches and tears down its process generation, including failures before
  any request; later requests fail immediately until a fresh connection is established.
  Without interception the existing ACP transport behavior is unchanged.
- Runtime resolution before start may resolve a suitable existing or managed binary but
  never downloads or mutates files, and failure there is non-fatal. Eligible descriptors
  resolve and start concurrently within one startup batch; each settled descriptor closes
  its generation stream independently, while the startup mutex remains held until every
  descriptor settles. The persisted disable list is the only durable eligibility policy,
  with setup deciding blocked versus routable.
- Managed selection prefers the pinned target and otherwise takes the newest installed
  managed version still at or above the harness's minimum, so raising the target leaves
  the previous install usable rather than reporting the runtime as missing. A managed
  version below the minimum is never selected.
- Hermes is a direct-CLI harness with no managed install. Setup distinguishes a missing or
  pre-ACP binary, a Hermes Agent release below `0.20.0`, and missing model/provider
  configuration; startup revalidates the effective PATH or explicit `--hermes-bin` executable
  while preserving an explicit path as authoritative.
  Provider setup remains an out-of-band Hermes CLI action, so authentication-required
  Hermes entries give local setup guidance rather than offering bridge-managed login.
- DeepSeek is an ACP harness with six-platform managed package archives. Its
  descriptor honors an explicit `--deepseek-bin` path before a compatible PATH
  release (`>=0.1.5`) and then a managed release at or above that minimum,
  preferring the pinned `0.1.5` target. An outdated explicit
  binary is rejected; an old or malformed PATH candidate falls through to managed
  selection. It performs bounded parseable-version and
  side-effect-free `check --state-dir` probes, advertises install only on a
  supported platform without an explicit path, and gives local DeepSeek
  provider/setup guidance. Managed installation verifies the immutable archive
  digest and preserves the packaged launcher with its bundled Node runtime. Startup
  validates standard ACP v1 plus DeepSeek extension protocol v2, owns one stdio
  child through the host process seam, degrades on an unexpected exit, lazily
  reconnects on demand, and shuts down idempotently without treating its own
  termination as a crash. Scoped-stop phone QA on unchanged published adapter
  0.1.4 verified that the bridge and native runtime survived atomic cancellation
  of an independently resumed child and its grandchild after #1379, and accepted
  a successful follow-up turn. That evidence does not requalify current managed
  target 0.1.5 or cover setup selection, crash reconnect, idle suspension/reap,
  bridge restart, desktop, or another platform.
- Standard ACP owns DeepSeek lifecycle, prompts, config options, and permissions;
  `deepseek/*` adds catalog, detached history, rename, questions, bounded statuses,
  and correlated sub-agent lifecycle on that same connection. Normal `DSH_HOME` remains the source
  of settings, credentials, providers, and skills but its session root is never
  scanned. Session, attachment, query, and spill mutations stay below plugin
  state, and session-local model/reasoning writes never modify user settings.
- Antigravity is an ACP v1 harness over Google's official proprietary runtime pair. An explicit
  `--antigravity-bin` server is authoritative and requires its matching sibling harness; otherwise PATH then the
  installed managed pair are checked. Setup inspection is static and inert, reports personal-auth readiness from
  token-file presence without reading it, and advertises current-client browser login only when required. It never
  imports ambient credentials, starts a process, opens a browser or downloads a runtime. Managed Install is explicit,
  limited to macOS arm64, Linux x64/arm64 and Windows x64/arm64 (not macOS x64), absent with an override, and preceded
  by Google terms/documentation guidance visible on the detail screen before installation. The overview download icon
  opens that screen rather than starting a download. Preparation, exact identity/version probing, login and live start use the same isolated profile/environment
  with parent inheritance disabled.
- GitHub Copilot is a standard ACP v1 harness launched as
  `copilot --no-auto-update --acp`. Setup keeps an explicit `--copilot-bin`
  authoritative, otherwise prefers a compatible PATH release (`>=1.0.78`) over
  a managed release at or above that minimum, preferring the pinned target.
  Version output must retain Copilot branding, and
  startup uses only the runtime selected during provisioning. Authentication is
  local and out of band; setup never reads credentials or runs `copilot login`.
  An unexpected owned-process exit degrades only Copilot, and demand reconnects
  it without affecting another harness.
- A managed harness whose first handshake stalls does not hang bridge startup.
  Codex and OpenCode wait a bounded 15 seconds for that cold start: succeeding
  within it reports connected, failing within it reports degraded, and exceeding
  it starts the harness degraded while the cold start keeps running in the
  background, where a later failure is logged rather than surfacing as an
  unhandled error. OpenCode skips the bounded wait whenever it holds no server
  handle — its attach probe found nothing reachable, or managed provisioning
  produced no runnable binary — and instead reports degraded immediately and
  retries the cold start in the background, because a cold start against a
  server that is not there has no bound of its own. An abort observed after the
  cold start still rolls back everything the start acquired.
- Grok Build is a direct-CLI ACP v1 harness with no managed install. An explicit
  `--grok-bin` path is authoritative; otherwise setup uses `grok` from PATH and
  requires version `1.0.5` or newer. Setup inspection and pre-start resolution
  run bounded `--version` and `models` probes: they never read credentials,
  invoke login, create a session, or start ACP. A listing that reports not
  being authenticated is authentication-required carrying the resolved
  version; any other wording leaves setup ready, and a listing that cannot be
  run is unknown. Startup launches exactly
  `--no-auto-update agent --no-leader stdio` through the host process seam and
  accepts only advertised headless authentication. Interactive-only
  authentication becomes local-login-required without invoking it. An
  unexpected exit degrades only Grok, demand reconnects it, and owned shutdown
  remains idempotent and is not reported as a crash. Exit cleanup publishes
  cancellation and idle for every running Grok child, clears autonomous-root
  holds, then clears tracker state and releases a deferred root idle. Corrected
  production-composition QA after PR #1429 kept the same runtime usable through
  named-child cleanup, already-finished handling, full-stop settlement, and
  fresh-session dispatch. Phone setup separately verified source bridge health
  and relay connection before UI automation failed to start; this is no visible
  lifecycle claim.
- Pi and Oh My Pi are registered harnesses with managed installs where a platform
  archive exists and explicit `--pi-bin`/`--omp-bin` paths stay authoritative. Pi
  sessions always launch with `--approve` (project-local Pi settings, extensions,
  skills, and prompt templates are trusted without prompts); OMP launches `omp acp`
  without an approval-mode override, leaving approval behavior to OMP. Provider login
  for both happens locally, never from the phone.
- Pi setup inspection follows its version probe with a bounded `--list-models`
  run in the same environment. A listing that reports no available models is
  authentication-required carrying the resolved version, any other listing is
  ready, and a listing that cannot be run is unknown rather than ready. The
  probe never starts a backend, opens an RPC session, or invokes login, so a
  managed install with no provider credentials stops being reported as ready
  and stops offering start.
- OMP setup inspection follows its version probe with a bounded `models --json`
  run in the same environment. Only a listing that parses and reports an empty
  model array is authentication-required; an unparsable or non-zero listing
  leaves setup ready, because supported releases predate that flag and a
  working older install must not regress. A listing that cannot be run at all
  is unknown.
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
- A harness generation cold-started solely because catalog snapshot import fell back
  to the live plugin path uses an import-only idle residency cap of five minutes.
  A shorter positive configured timeout stays shorter and a non-positive timeout
  stays disabled. Any ordinary plugin acquisition, explicit/eager start, session
  warm-up, or session operation monotonically promotes that same generation to its
  configured normal residency and immediately re-arms applicable idle ownership;
  importing through an already-running or starting generation never changes its
  profile. This policy controls post-use idleness only: it is not an import,
  enumeration, server-start, or publication deadline.
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
- Cursor records one root-level unresolved-background observation when a Task
  launch explicitly reports `isBackground: true`. It keeps only process work state
  busy, preventing safe suspension without changing UI status, summaries, child
  counts, or idle events. It survives later turns and clears only on exact session
  cleanup, process reset/forced teardown, or disposal because Cursor exposes no
  terminal fact.
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
  child turn runs, even after the root's own turn completes. Lifecycle-wide
  interruption snapshots active roots, children, pending turn admissions, and
  pending input, then starts an exact per-thread interrupt for every selected
  session; native terminal notifications settle status without synthetic idle.
  Thus safe stop continues to refuse tracked descendant work, while forced stop
  drains that work through the same owned transport before teardown. Disconnect
  first cancels every open inline child tile, then clears connection-scoped
  child state and emits visible idle cleanup for both a provisional child and
  its effective root before resetting work state. Already-terminal tiles retain
  their child-derived state.
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
- Browser challenges require a current client, exact loopback callback-shape validation, and one-shot redirect
  submission; unknown challenges fail closed with update guidance.
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

- Mobile and desktop share a grouped overview (Needs attention, Enabled, Not installed,
  Disabled) and URL-addressable `/settings/harnesses/:pluginId` details. Registry order is
  retained within groups; empty groups disappear. Installing entries belong to Not installed;
  genuinely disabled entries belong to Disabled; only ready dormant/starting/active entries
  are Enabled. Degraded remains attention even though its separate scan capability is routable.
  A stopping harness belongs to Disabled — where a toggled-off harness settles — and keeps its
  `Stopping` status there instead of jumping through Needs attention while it drains.
  A harness that changes group closes in the section it left while opening in the section it
  joined, and an emptied section closes with its last row rather than disappearing under it;
  reduced motion keeps the same result without the transition.
- Harness names and the separate download target open details without starting installation;
  setup guidance stays visible before the explicit detail installation button. Switches send
  actual enable/disable intent and retain the bridge's
  known enabled preference while blocked by setup or another operation; unknown runtime
  has no inferred switch. A pending toggle replaces only that harness's switch with an
  in-place indicator in the same 64×44 slot; the list and unrelated harness toggles stay
  usable. Each harness retains its own pending action, failure or safe-conflict confirmation
  across refresh and overview/detail navigation. Same-harness commands, overrides, installs
  and authentication cannot conflict locally; a global timeout update excludes pending
  harness actions/confirmations in both directions. Independent results never erase a peer's
  feedback, and dismissals apply only to the displayed attempt. Local authentication
  ownership releases on terminal progress even if reconciliation fails and retained
  metadata still reports in-progress; that metadata never proves success or blocks retry.
  Remote conflicts and uncertain retries remain explicit failures. An owned retained
  challenge can reopen, except while a global action is pending. Retained installation
  or authentication alone does not prevent editing the global idle-timeout setting.
- Force conflicts can auto-open only on an uncovered flow. Additional conflicts retain a
  named Review action on their harness, within a single grouped surface on both overview
  and detail; Review opens the existing confirmation without sending force. No stacked
  dialogs or automatic queue: confirmation and cancellation
  require the exact current attempt, and loading, identity replacement, unsupported/failure
  reset and close fence old completions and sheet callbacks.
- Running means reported busy session work, not merely an active runtime. Idle or stopped
  overview entries have no subtitle section, even when the process is alive; disabled
  entries also omit it. Installation/setup problems remain visible on eligible entries,
  and unknown activity is not labelled Running. Global timeout is last; its value remains
  visible but not editable during per-harness commands, and only its own all-harness update
  shows progress.
- Detail reports only known version and idle/busy activity, never a fabricated session count.
  Missing runtime has setup/install content rather than operational actions. Unknown and
  externally managed capabilities remain honest. Individual timeout inheritance, custom
  minutes and no-timeout are all available through the timeout editor.
- One flow-owned cubit and transient-presentation owner survives overview/detail navigation.
  Opened from Settings, overview and detail show only left Back: detail returns to overview,
  then overview returns to the same Settings page. Opened modally from New Session,
  overview shows only right X and detail shows left Back plus right X. Detail Back retains
  the overview flow; X from either page dismisses only the harness modal, preserving the
  same New Session page and draft. Direct detail links construct overview ancestry without
  creating an unrelated Settings page, and links without an opener fall back to
  signed-in Projects on both shells. Removed IDs show an unavailable detail, not another harness.
  Authentication and force sheets belong to this flow and leave with it; sheet dismissal
  remains distinct from cancelling authentication. Safe lifecycle conflicts still authorize
  force confirmation, never an install retry.
- Shared cards use surface2, 26px radius, 16px page/section gaps, 68px minimum overview/action
  rows and 52px minimum detail facts, growing at larger text sizes. Switches keep their
  64×28 visual track inside an independently tappable, labeled 64×44 target; padding taps
  toggle rather than navigate. Overview groups omit dividers and default badges.
  Unsupported automatic-update and install pause/stop controls
  are hidden rather than simulated.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | A started bridge inspects every registered harness and publishes coherent setup and management snapshots. A ready fixture has a selectable default; a fixture with no usable harness has zero selectable entries and no default without failing startup. Automated client projection covers the exact session harness for ready/routable versus disabled, setup-blocked, stopping, failed, unknown, missing-entry, initial-loading, initial-failure and public-old-bridge unsupported evidence. Headless bridge; all registered harnesses listed. |
| L2 Routine | Automated client coverage retains an established block through disconnect, requires current evidence after reconnect, preserves a supported snapshot's decision across refresh failure, and retains an initial check failure's original cause for local diagnosis. Demand-driven start of a ready harness, non-blocking session-open warm-up plus immediate app-setting enable/disable, clean lifecycle-owned bridge shutdown, Codex keepalive traffic remaining local and stopping on disposal, Codex root work remaining busy until its last child settles, and Codex lifecycle interruption covering active descendants plus pending turn admission without synthetic settlement; setup refresh and the disable list surviving restart with eligibility and ordering intact. Package automation covers DeepSeek explicit/PATH/managed selection, immutable six-platform archive metadata, readiness, extension refusal, crash/reconnect, and idempotent shutdown. Copilot package automation covers branded version parsing, explicit/PATH/managed precedence, exact six-archive metadata, provisioning-authoritative startup, and local-login-required failure. Grok package automation covers explicit/PATH authority, bounded branded version parsing, read-only inspection, local-login-required startup, crash/reconnect, and owned shutdown. Automated runtime coverage proves the bounded cold start reports connected on success, degraded on failure, and degraded on budget exhaustion while absorbing the late failure. Headless bridge; representative managed harness for start and shutdown, every registered harness for listing and ordering. Automated client service coverage separately proves that a management SSE-triggered GET during enable/restart preserves the correlated acknowledgment without publishing its superseded snapshot; a failed reconciliation retains its typed refresh error. Representative neutral fixtures, no live plugin or rendered UI claim. Cubit/service composition and shared-widget automation prove two independent toggles dispatch before either response, per-target progress/errors and peer padding taps; bridge lifecycle fixtures prove independent named command slots and settings preservation. |
| L3 Release | The shared mobile and desktop management surface as rendered: per-harness selected runtime version when reported, setup, runtime and work state, capability-appropriate controls, built-in name and light/dark artwork, grouped overview and per-harness detail navigation, enable/disable, restart, idle-timeout default plus override persisted across a bridge restart, and the per-harness catalog scan on a routable harness including its in-place progress and the announcement of what it found. Copilot renders the exact `GitHub Copilot` name and Primer interface icon in both themes. Grok renders as `Grok Build` with the official contrasting mark, selected version, local setup guidance, and no managed-install control. Client end to end on both product surfaces; every harness declaring the relevant capability must pass. |
| L4 Extended | Client end to end for an existing chat: Claude authentication-required then restored, one managed runtime missing then restored, and one supporting ACP harness disabled then enabled; another harness remains usable throughout, and an unrelated-harness management change leaves the open chat untouched. Repeat one unavailable-to-usable transition from a second surface and one reconnect against a different bridge identity. Busy conflict with force confirmation and cancellation, authentication start/join/cancel plus shutdown cleanup, peer harness login rows disabled throughout a retained authentication operation, an owning row reopening a dismissed or `cancellingUncertain` challenge, idle suspension elapsing then returning on demand, harnesses blocked by missing runtime or authentication with no catalog-scan action offered on them, a targeted scan rejected by the bridge reporting on its own card, a terminally failed harness leaving others usable, a bridge with no usable harness, an externally managed configuration, two harnesses active at once, second mobile platform. Copilot live coverage includes an unexpected owned-process exit followed by demand reconnect and a deliberate clean shutdown that is not reported as a crash. Grok live coverage includes the same failure isolation and demand reconnect with a supported user-installed release. Live plugin where a real backend must start or be interrupted, client end to end where card state is claimed. Automated client service ordering coverage separately exercises reversed command completion, bridge mismatch after an intervening GET, and disconnect/reconnect, replacement, unsupported management or disposal during reconciliation; old responses stay fenced and uncertain results stay uncertain despite active/idle metadata. Cubit/widget automation also covers same-harness duplicates, global-timeout exclusion, retained auth/install exclusion, both completion orders, reset/retry fencing, and two safe conflicts with explicit Review and stale dialog callbacks. |
| L5 Full | Every registered production harness through inspect, enable, disable, restart, refresh, and idle behavior on a supported platform, plus forward-compatible presentation of an unknown harness or capability and the reported state of a session interrupted by a forced disable. Compatibility pairs prove an older client treats `copilot` and `grok` as unknown raw-id/generic-icon harnesses without decode failure, while an older bridge simply supplies no corresponding entry to a newer client. Live plugin and client end to end as each entry requires. |

## Exploration Guidance

Vary which harness runs first and which stays disabled, and the configuration: default
managed, explicit binary path, externally managed backend. Vary the trigger between app
and management API, whether a session is idle or working, and fresh versus reused data
directories. For Hermes, vary missing and pre-ACP installs, a release below `0.20.0`, an
unconfigured model/provider, PATH discovery, and `--hermes-bin`. Restore eligibility,
timeouts, and sessions afterwards. For Antigravity, vary missing, mismatched and
valid official pairs, PATH versus authoritative explicit selection,
authenticated versus authentication-required isolated profiles, and current
versus unsupported older clients. Do not use real Google OAuth for synthetic
setup checks. For Copilot, vary missing, malformed, too-old,
compatible PATH, managed, and explicit runtimes; authenticated and unauthenticated
normal configuration; owned-process exit; and bridge restart. For Grok, vary
missing, malformed, too-old, current PATH, and authoritative explicit binaries;
headless and interactive-only authentication; catalog refresh; enable/disable;
owned-process exit; and restart.

## Failure Signals

- A pending harness disables peer switches, a peer completion erases another harness's
  error, a duplicate/conflicting request escapes its target slot, or Review sends force
  without confirmation. Stacked/queued force sheets or an old callback authorizing a retry.

- A chat uses the default or another harness's state, unknown evidence enables
  input, a disconnect bypasses a known block, reconnect reuses stale positive
  evidence, an initial request failure is mistaken for unsupported management,
  or a retained refresh error changes the last established decision.
- Detail navigation recreating operation state, duplicate force/auth sheets or scan announcements,
  pushed Back skipping Settings, modal X losing the New Session page or draft, incorrect
  Back/X header controls, or a missing ID displaying another harness.
- A setup-blocked switch falsely shown off, unknown preference represented as disabled,
  degraded grouped as healthy, or controls overflowing at phone width with larger text.
- DeepSeek scoped STOP crashes the bridge or native runtime, prevents a later
  turn on the retained runtime, or mistakes surviving root-owned background
  shell jobs for failed descendant-agent cancellation.

- An isolated child receiving ambient variables, an inert JSON child selection creating
  directories, repeated child scopes losing concurrent updates, consumed ACP output appearing
  in diagnostics, or interception preventing idle-process shutdown.
- Setup inspection installing, logging in, starting a backend, or leaking secrets or raw
  output; resolution mutating runtime files; a disabled harness probed or started.
- A stalled first handshake holds bridge startup past the cold-start budget, a
  budget-exceeded harness reports connected instead of degraded, or its late
  cold-start failure surfaces as an unhandled error rather than a log line.
- A slow descriptor's provisioning or start keeps a ready descriptor's generation
  stream open, a descriptor-local failure takes down another descriptor, or the startup
  mutex releases before every descriptor start settles.
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
- A malformed or non-HTTPS verification URL reaching the launcher, a mismatched/non-loopback callback reaching the
  bridge, duplicate redirect submission, a browser opening without explicit user intent, response loss reported as
  definite failure, a fast terminal
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
- Antigravity inspection creates profile state, reads token contents, inherits ambient credentials, launches ACP,
  opens a browser, falls through from an explicit pair, downloads automatically, or offers managed install with an
  override/on macOS x64; registration changes the OpenCode preferred default or adds a shared `Harness` enum case.
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

- The harness set comes from the current registry; unregistered in-development harnesses are out of scope.
  Antigravity managed installation is implemented. Native Linux/Windows correctness and real OAuth evidence remain
  unverified; current native managed-pipeline evidence is macOS arm64 only.
- DeepSeek is registered and enabled by default. Its official theme-independent
  brand-blue artwork, local provider setup guidance, and managed install controls
  follow the same backend-neutral registry and client surfaces as every other harness.
- Management reports bounded setup evidence, not continuous provider entitlement.
  Credentials can expire after a ready inspection and the admitted turn can fail
  before the next authoritative refresh; client gating does not parse backend text.
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

- [Antigravity operator guidance](../ANTIGRAVITY.md),
  [official runtime activation](antigravity-descriptor-and-setup.md),
  [isolated profile](antigravity-isolated-profiles.md), and
  [personal authentication](antigravity-personal-authentication.md) contracts.
- Shared host/process boundary coverage: `bridge_host_json_store_test.dart`,
  `bridge_host_process_service_test.dart`, `host_process_acp_factory_test.dart`,
  `acp_output_interceptor_test.dart`, and `acp_stdio_client_test.dart` cover atomic
  scopes, explicit inheritance, byte preservation, pre-log consumption, and cleanup.
- `bridge/sesori_plugin_interface/lib/src/lifecycle/`; registered production plugin
  descriptors; plugin routing handlers
- `bridge/app/lib/src/runtime/plugin_generation_factory.dart` and
  `bridge/app/test/bridge/runtime/plugin_generation_factory_test.dart` cover concurrent
  provisioning/start, per-descriptor stream settlement and startup mutex ownership.
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
- Client availability gate: `client/module_core/lib/src/services/plugin_management_service.dart`,
  `session_interaction_calculator.dart`, session-detail cubit composition and
  their focused tests
- Shared management presentation: `PregoBrandLogo`, the Grok marks,
  `client/module_prego/BRAND_ASSETS.md`, and the harness settings screen
- Tests: `plugin_lifecycle_service_test.dart`, per-plugin setup and client suites;
  `client/module_core/test/services/plugin_management_service_test.dart` proves client
  acknowledgment/publication ordering and identity fencing through fake repository and
  connection streams; `client/module_core/test/repositories/plugin_repository_test.dart`
  proves timeout, response-loss, 503 and malformed-response uncertainty mapping.
