# Desktop Bridge Supervision

## Capability

The desktop window and tray jointly supervise the local bridge: present live
status, control desired On/Off state, expose diagnostics, coordinate sign-out,
and keep native close/quit behavior safe.

## Required Behavior

- A connected helper process is distinct from a ready bridge. The control channel
  reports starting, waiting for the server or desktop authentication, and ready; desktop shows
  "Starting — waiting for server (retrying every minute)" during an outage.
  Waiting does not exit the helper or spend the supervisor's crash-retry budget.
  Startup status is available before authentication and is replayed after a
  control-channel reconnect. Stop and Quit remain available during the wait.
- If desktop cannot obtain a fresh token while its account remains authenticated,
  it asks the helper to retry later and desktop shows waiting for authentication. Only a missing/signed-out session takes the
  existing login-required path; an offline token refresh must not be treated as
  a logout.

- The desktop boots a visible Prego-themed window and eagerly initializes tray
  supervision even while signed out. Exactly one process owns the desktop
  instance lock and activation listener. The macOS tray uses the transparent
  monochrome Sesori mark as a template image so the system renders it legibly
  in both light and dark menu bars.
- A second launch signals the owner, exits without another tray/helper, and
  restores/focuses the owner's window. A killed owner releases the OS lock;
  stale activation metadata cannot block the next launch.
- Desired bridge On/Off state persists under desktop-owned application data.
  After authentication, a missing preference initializes On, admits helper start
  and best-effort enables launch at login. Existing On/Off (including invalid
  contents treated as Off) is never overwritten. The existing write queue and
  restore generation preserve explicit Off/logout even after its disk write fails.
  Auth lost during initialization leaves admitted On login-required until sign-in,
  not stranded Off. Native enable failure leaves On intact and logs the error;
  success refreshes existing General/tray state after initial loading. Opening
  General also reads OS registration. No helper starts before dispatcher readiness.
  Startup restores last-On through the process service after the dispatcher is
  ready; signed-out restore reaches login-required without spawning a helper.
  Launch at login is an idempotent per-user registration that starts the app
  with `--hidden`; disabling it removes the registration rather than merely
  flipping an in-app flag. Development builds resolve the repository helper
  from the desktop executable path when a login service supplies `/` as the
  working directory. Before spawning, the development resolver verifies the
  helper exists: a missing repository bundle reports `cd bridge/app && make
  build-host`, while a missing explicit override identifies
  `SESORI_DESKTOP_BRIDGE_PATH`. Those overrides apply only to debug/profile
  builds. Release builds resolve the complete bundled helper from the installed
  GUI executable, independent of cwd, repository paths and environment overrides.
  Every spawn checks its immutable version/build/source/OS/CPU identity against
  the running GUI. Missing or mismatched payloads refuse startup with restart/
  reinstall guidance, including a Linux package replacement while the old GUI
  remains open. After startup cleanup, the existing process-state stream retains
  privacy-safe repair guidance without inventing a PID. The cockpit shows it with
  explicit Retry, and the tray directs the user to Open Sesori. The refusal notice
  does not offer child logs for a helper that never spawned; detailed failures
  remain in local application diagnostics. Hidden launch remains non-modal when a
  tray is available. A later valid Start clears the failure. An automatic restart
  logs the refusal without replacing repair guidance with crash backoff; ordinary
  startup errors keep their existing handling. The identity check is not signature
  verification.
  The supervised helper receives a login-shell-derived executable
  search path, so harnesses installed outside launchd's default PATH remain
  discoverable after autostart. Only PATH is derived for the helper; shell
  variables are not imported or persisted. If the login-shell probe fails, the
  desktop emits no PATH override and preserves the inherited environment
  unchanged while retaining a bounded diagnostic warning. Each supervised
  start resolves PATH again so a bridge restart can discover newly installed
  harnesses; concurrent resolution callers still share one in-flight probe.
- A `--hidden` launch stays tray-only when the tray is proven available. The
  macOS runner suppresses the native first ordering and the Flutter window
  adapter applies the hidden state as a fallback. If the tray is unavailable
  or fails to initialize, the window is shown so the app remains reachable.
- On a proven tray host, native close hides the window immediately, including
  during bridge lifecycle work, removes the macOS app from the Dock while it is
  hidden, and Open restores/focuses it and returns it to the Dock. Without a
  usable tray host, close defers safe Quit until active lifecycle work settles
  instead of dropping the request or leaving an invisible process.
- Window position and size persist under desktop-owned application data. Startup
  validates the saved bounds, selects the current display with greatest overlap
  (or nearest center), clamps them to its usable work area, and applies them
  before the first explicit show; on macOS the native runner suppresses the
  XIB's first ordering for normal and hidden launches so restoration cannot
  flash the default frame. Missing or invalid bounds and display lookup failures
  use the centered 720×620 default. The 560×480 minimum shrinks only when the
  selected display work area is smaller. Move/resize events debounce writes;
  terminal Quit flushes the final observation before disposing the window host.
- Primary and secondary (right/trackpad) clicks on the tray icon open the same
  typed context menu. The macOS Dock icon is a desktop-owned copy of the
  Sesori Icon Composer asset used by the main client, not the Flutter starter
  icon; keeping the copy local preserves independent shell builds.
- Quit expected-stops the supervised helper before disposing native surfaces or
  terminating the desktop process. Quit preserves the persisted On/Off intent;
  only an explicit Bridge Off action or coordinated logout writes Off. A failed
  stop leaves the app alive.
- Window and tray On/Off actions share one serialized owner. Intent is durable
  before lifecycle work begins: a persistence failure leaves the helper and
  session unchanged, while a failed start or stop leaves the next action
  targeted at retrying that failed operation.
- The signed-in window opens on project/session guidance and recovery. Its
  pinned Bridge popover presents local process status and relevant controls;
  account information remains in Settings, and the tray retains active-session
  counts, application Quit and launch-at-login. Explicit Start/Stop actions
  preserve their intent even if process state changes before dispatch; failed
  starts/crashes offer recovery, not a misleading Stop. Busy states still permit
  diagnostics. Take Over is an explicit action for contention/displacement; it
  persists On, performs one stop-and-respawn, and accepts only replacement
  prompts from the fresh helper. A persistent desktop sidebar reaches bridge
  controls, projects, and settings, while exceptional login-required, crash-give-up, and
  takeover recovery appears in the sidebar footer across cockpit destinations. Recovery starts or retries the supervised helper or
  opens its logs and never offers mobile CLI-install instructions.
- The window routes between shared project/session inventory, settings,
  profile, and harness-management surfaces without creating another
  auth/session owner. Desktop injects account state, navigation, external-link/
  package metadata, and its coordinated logout workflow; it deliberately omits
  the mobile push-notification preference surface and instead exposes one
  desktop-owned native attention switch. Desktop derives permission/question
  alerts from authenticated relay SSE and never registers for push. Attention
  installs its listeners before rendering without waiting for native notification
  readiness or a permission decision. Delivery shares the existing initialization
  future before entering tracked writes, so pending native readiness cannot block
  logout/disposal while actual native writes still settle before cleanup. Captured
  attention gets one replay after failed startup initialization; later failures use
  event-driven retry. Initial-open metadata is consumed asynchronously, including
  after native failure, without reopening or routing a disposed service. Notification
  opens dismiss root popups after the account check, even for the current editable
  session; that session keeps its page and Back stack rather than remounting.
  A different destination still receives the canonical typed stack.
  Project recovery never shows
  mobile CLI installation guidance: both never-registered and disconnected
  states offer supervised **Start the bridge**, which persists desired On,
  starts or retries rather than applying toggle semantics, and establishes the
  authenticated desktop relay connection. Session rows open a typed detail
  route that composes the shared transcript, pending interactions, child-session
  navigation, links, and image actions. Root active sessions open the shared
  diff view, and the session list opens shared session creation with plugin,
  model, command, attachment, and dedicated-workspace options. Desktop supplies
  text-first composition and omits voice rather than constructing a dead voice
  capability. The sidebar supplies recent-session navigation at every width;
  only All sessions owns the full list cubit. New-session, transcript and diff
  pages each occupy the full main pane. Desktop Enter
  sends from the inline composer, Shift+Enter inserts a newline, and active IME
  composition retains Enter for candidate confirmation. Escape first releases
  active text editing and otherwise dismisses only popup routes. Transcript and
  diff source text retain native selection/context-menu behavior while
  navigation, file-header, line-number, and prefix chrome stays outside copied
  diff source. Settings overlays the current pane; harness Back stays within
  its modal, while Close restores the opener. The analytics service starts
  before the app, while authenticated preference reconciliation is scheduled
  after the first rendered frame, so a slow server cannot leave the window
  blank; Account reflects synchronization
  progress until that bounded operation settles. One desktop connection pill
  overlays the main pane without moving routed content; local Off suppresses
  bridge-offline copy while relay recovery remains available.
- macOS home offers optional Full Disk Access guidance for local coding agents:
  folder prompts may pause unattended work; broader protected-file access is
  optional. Open System Settings never grants access or restarts a helper.
  Not now hides the card for this app run; Settings → Bridge → This computer
  retains the status/action. Focus return rechecks without polling. The probe
  opens/closes a protected file read-only without reading its contents; expected
  permission failures mean denied, other failures remain logged unknown.
  Other platforms perform no probe and show no permission row/card. Neither
  the guidance nor its dismissal changes another connected computer's settings.
- Appearance and default-input preferences are read before the first desktop
  frame, provided above the router, and persisted through the same shared
  cubits as mobile. Changing appearance in Settings re-themes the whole window
  immediately rather than only the current route.
- Shared client logging defaults to stdout, preserving level filtering, diagnostic
  context and stacks. HTTP/relay parsing errors retain typed causes but omit JSON
  excerpts from presentation; both shells omit outbound-link user-info/path/query/fragment
  and selectively replace the known URI in thrown-error diagnostics. Unrelated
  useful error context remains. Final desktop Quit awaits admitted log output for
  at most two seconds after cleanup; flush failure/timeout reports directly to stdout
  and does not prevent exit. A failed helper stop still refuses Quit before flushing.
- Open Logs prepares the owner-only active log through Layer-1 storage, then
  resolves it through the desktop log repository and delegates it to the system
  default application, including before the helper emits its first line. Both
  pipes continue draining through byte-bounded lines and a bounded persistence
  queue; storage warnings are rate-limited and do not stop the drains. Crash
  recovery preserves exit/count diagnostics and links to rotating logs.
- Device-local sign-out locks every bridge lifecycle surface, asks the live
  helper to `unregister_and_exit`, waits for that command's expected exit
  without sending a competing shutdown, and independently deletes the GUI's
  persisted account-bound bridge registration (404 is already success). The
  delete attempt has a bounded timeout and is best-effort offline; a confirmed
  deletion clears the local record, while an unconfirmed deletion keeps it for
  a later retry. A different account never submits or clears the record. Local
  analytics preparation runs after that successful stop and before delivered
  desktop notifications and local tokens are cleared. Notification cleanup is
  best effort but always settles started native writes and attempts cancel-all
  before credential clear; failed token clearing resumes analytics for the
  still-signed-in session. If stop fails, authentication and analytics remain
  intact. Other devices are never logged out.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated desktop startup proves eager tray initialization, Prego theme assembly, signed-out login rendering, signed-in cockpit/sidebar supervision rendering, shared desktop Settings with mobile push omitted and native attention exposed, and the typed session-detail route. No plugin. |
| L2 Routine | Automated outage-state, offline-readiness, token-wait/recovery and control-channel status replay coverage; cubit/adapter coverage for Open/focus, close-to-hide, no-tray close-to-Quit, ordered Quit, quit-preserved desired state, failed-stop/persistence refusal to exit, On/Off recovery, explicit idempotent Start, diagnostics launch, bounds restore/clamp/debounce/terminal flush before first show, durable-Off-before-local-logout, notification cancel-all before credential clear, helper unregister command, no-competing-shutdown expected stop, account-bound persisted bridge-id restart, owner-mismatch protection, 404-idempotent deletion, offline deletion failure, explicit Take Over, cockpit-wide exceptional supervision, retained bundle-refusal guidance/no-spawn cleanup/explicit retry and non-modal hidden startup, both project recovery variants omitting CLI copy, adaptive session split ownership, desktop Enter/Shift+Enter and safe Escape behavior, selectable transcript/diff content, SSE-derived attention gating/routing/cancellation/toggle, root-popup dismissal before same-session reveal or different-session replacement, desktop transcript rendering and pending-question presentation without dead composer/diff controls, app-wide preference persistence, desktop settings/harness composition, profile logout delegation, analytics-before-auth logout ordering, and failed-logout analytics recovery; cross-process lock/activation, killed-owner recovery, persisted desired state, and auth-gated startup restoration. No plugin. |
| L3 Release | Client end to end on macOS with a dev-built helper and representative live plugin: browser login/relaunch restore, healthy handshake, phone session round-trip, helper crash/backoff, exit-86 restart, login-required behavior, Off/close/Quit orphan checks, and standalone CLI coexistence. |
| L4 Extended | Client end to end on Windows and Linux, including a Linux StatusNotifier host and a no-host windowed fallback; vary helper startup/stop failures, relay takeover, crash diagnostics, and default log-file application availability. |
| L5 Full | Packaged desktop artifacts on every release target, including native tray/window appearance, signing/install behavior, and long-running supervision through repeated sleep, reconnect, restart, hide/show, and relaunch cycles. |

## Exploration Guidance

Vary signed-in versus signed-out startup, tray present versus absent, bridge On
versus Off, second launch while visible/hidden, owner crash with stale metadata,
and whether close occurs during a lifecycle transition. Exercise
both clean and failed helper teardown before Quit or sign-out. Exercise Take
Over from local contention and relay displacement, and verify one stop-and-
respawn rather than a restart war. Quit while desired On, relaunch, and verify
last-On restoration. Kill the helper at different handshake phases and inspect
the status and rotating log output. For packaged helper resolution, vary
installed paths containing spaces, an unrelated cwd and a development override;
only the installed payload should be used. Install a complete new GUI/helper package
while the old GUI remains open to test its next-spawn mismatch refusal; restart into
the newly installed GUI to restore the matching identity. Changing only a manifest
cannot be repaired by restarting the same GUI. Check that refused startup leaves
repair guidance in the cockpit and tray rather than silently reverting to Off;
hidden startup must not force a modal/window when the tray is usable. Retry after
restoring a matching payload and verify the notice clears. Quit before ordinary
package upgrades. The staging producer must preserve native libraries, executable
permissions and framework symlinks;
verify the actual relocated helper, not merely the presence of its binary.

## Failure Signals

- An outage leaves the helper claiming ready, hides the startup wait, consumes
  the crash budget, or loses the waiting status after control-channel reconnect.
  A disconnected helper claims ready, or a temporary desktop token refresh is
  treated as logout/login-required instead of waiting for authentication.

- No tray or command subscriptions until a signed-in screen reads the cubit.
- A second process creates another tray/helper, fails to focus the owner, or a
  killed owner leaves a lock that bricks future launches.
- First-run defaults overwrite saved intent, repeat after native-enable failure,
  start after a superseding Off/logout, or block rendering. Permission guidance
  claims unknown access is denied/granted, probes on unsupported platforms,
  loses dismissal after navigation, or lets an older focus probe replace newer state.
- Desired Off restores On, last-On never restores, startup bypasses auth gating,
  or bridge restore begins before the control dispatcher owns its event stream.
  Quit while desired On unexpectedly persists Off, or an explicit Take Over is
  missing when local or relay ownership is lost.
- A release uses an arbitrary development/PATH helper, loses its native assets,
  accepts mismatched GUI/helper identities, caches a manifest across package
  replacement, or hides the repair/restart explanation when startup is refused.
- Repeated launch-at-login enables create duplicate registrations, disabling
  leaves a stale login item, a login-launched development build cannot find its
  repository helper or its PATH-installed harnesses, an unbuilt repository
  helper falls through to an opaque `ProcessException` without the build
  command, a missing explicit helper override omits the responsible variable,
  `--hidden` startup hides the app without a usable tray,
  the macOS window flashes or remains visible during hidden startup, or a normal
  manual launch unexpectedly starts hidden.
- Close hides the only surface when no tray host exists, ignores a close during
  lifecycle work, Open shows without focusing, native close bypasses teardown,
  or the macOS tray icon has an opaque background/wrong light-dark treatment,
  the Dock still shows a hidden window, or secondary tray clicks do nothing.
- Restored bounds are applied after a visible flash, land wholly off-screen,
  ignore current display work areas, retain a native minimum larger than the
  selected work area, fail to persist after move/resize, or one failed write
  prevents later bounds from saving.
- Quit or sign-out clears auth or exits while a supervised helper remains alive,
  a profile logout bypasses the desktop logout orchestrator, or an On command
  can race between logout's helper stop and token clearing.
- Sign-out fails to send the helper unregister command, pre-empts it with a
  competing shutdown, skips the persisted-id fallback, loses the account-bound
  record across a GUI relaunch, submits one account's id with another
  account's token, blocks indefinitely on an offline auth server, or clears
  the record/auth state before deletion/teardown is ordered.
- A failed On/Off action presents or executes the opposite operation instead of
  retrying the failed action, or project recovery toggles desired On to Off,
  omits Start for either disconnected variant, fails to establish the desktop
  relay connection, or exposes mobile CLI commands.
- Window and tray disagree on desired state, status, or active-session count.
- Takeover, login-required, or crash give-up is rendered as healthy/connected,
  a takeover starts a restart war or approves a non-replacement prompt, crash
  diagnostics are inaccessible, Open Logs targets a nonexistent/bypassed file, or a
  supervised Full Disk Access warning tells the user to authorize only
  Terminal instead of the process running the bridge.
- The desktop theme lacks Prego colors, typography, or design-system extension;
  a saved appearance flashes the system theme at startup, changing it affects
  only one route, connection presentation shifts routed content or duplicates
  the cockpit pill,
  desktop exposes a dead mobile push-preference surface or registers a push
  token instead of using relay-derived local attention, a pushed settings
  child closes to Home, a standalone child cannot close, startup reconciliation
  leaves the window blank, Account leaves usage analytics stuck on Loading, or
  logout clears auth before analytics preparation and fails to resume analytics
  when token clearing fails. A desktop session row cannot reach its typed detail
  route, Back cannot return to the session list, a child-session link loses its
  typed route data, New task or file changes cannot reach their typed routes, or
  desktop renders unsupported voice/attachment controls, Enter inserts a newline
  instead of sending, Shift+Enter sends, an IME candidate-confirmation Enter
  submits the draft, Escape pops an ordinary cockpit page or steals a closer
  modal/editor handler, source text cannot be selected, copied source includes
  navigation/file/gutter chrome, or wide session navigation recreates or
  discards its project-scoped inventory. Desktop attention appears while the
  window is focused or its switch is disabled, includes prompt/request content,
  survives resolution/logout/account replacement, loses an initialization retry
  or Linux launch callback, blocks the first frame behind native authorization,
  reopens/routes after disposal, or opens without focusing and routing to its bound
  display session.

## Known Limitations

- A registration deletion that times out or otherwise fails is retained for a
  later explicitly-triggered logout retry; there is no background retry job.
- The helper's `unregister_and_exit` command has no acknowledgement. The GUI
  therefore always performs its own idempotent deletion attempt after bounded
  process teardown.
- Real Linux StatusNotifier and Windows tray/window appearance require host
  smoke coverage; automated tests prove translation and fallback behavior.
- Non-provisioned/ad-hoc macOS development builds may show one Keychain
  authorization prompt per existing credential item; this is macOS item ACL
  behavior and is separate from the entitlement workaround. Full Disk Access is
  likewise attributed to the process that accesses the protected folder; a
  Terminal grant is not transferred to a separately launched desktop/helper
  process. Stable signing for distributed builds belongs to the later
  desktop-distribution plan.
- Login registration is owned by the current desktop executable path. A
  development build moved or rebuilt at a different path must be re-enabled;
  the dev resolver can locate the repository helper from an executable inside
  the checkout even when launchd changes the working directory. Release helpers
  live at `Contents/Helpers/bridge/` on macOS and beside the GUI in `bridge/` on
  Windows/Linux, retaining the CLI `bin/`–`lib/` layout. Signed installation and
  real GUI/upgrade evidence remain distribution release gates.

## Sources

- `client/module_desktop_core/lib/src/cubits/bridge_control/`
- `client/module_desktop_core/lib/src/foundation/platform/bridge_process_environment.dart`
- `client/desktop/lib/core/platform/io_bridge_process_environment.dart`
- `client/desktop/lib/core/platform/desktop_bridge_executable_path_resolver.dart`
- `client/module_desktop_core/lib/src/orchestration/desktop_bridge_takeover_orchestrator.dart`
- `client/module_desktop_core/lib/src/orchestration/desktop_logout_orchestrator.dart`
- `client/module_desktop_core/lib/src/services/window_bounds_service.dart`
- `client/module_desktop_core/lib/src/services/desktop_attention_service.dart`
- `client/module_desktop_core/lib/src/api/bridge_id_storage.dart`
- `client/module_core/lib/src/api/bridge_api.dart`
- `client/module_core/lib/src/repositories/bridge_repository.dart`
- `client/desktop/lib/core/platform/flutter_window_host.dart`
- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart`
- `client/desktop/lib/core/widgets/desktop_bridge_popover.dart`
- `client/desktop/lib/features/home/desktop_home_pane.dart`
- `client/desktop/lib/features/sessions/desktop_session_list_screen.dart`
- `client/desktop/lib/features/sessions/desktop_session_detail_screen.dart`
- `client/desktop/lib/features/new_session/desktop_new_session_screen.dart`
- `client/desktop/lib/features/session_diffs/desktop_session_diffs_screen.dart`
- `client/desktop/lib/core/routing/desktop_router.dart`
- `client/module_app_ui/lib/src/features/project_list/`
- `client/module_app_ui/lib/src/features/session_list/`
- `client/module_app_ui/lib/src/features/session_detail/`
- `client/module_app_ui/lib/src/features/settings/`
- `.plan/active/desktop-app/PLAN.md`
