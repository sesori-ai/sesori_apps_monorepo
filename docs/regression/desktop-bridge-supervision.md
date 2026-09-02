# Desktop Bridge Supervision

## Capability

The desktop window and tray jointly supervise the local bridge: present live
status, control desired On/Off state, expose diagnostics, coordinate sign-out,
and keep native close/quit behavior safe.

## Required Behavior

- The desktop boots a visible Prego-themed window and eagerly initializes tray
  supervision even while signed out. Exactly one process owns the desktop
  instance lock and activation listener. The macOS tray uses the transparent
  monochrome Sesori mark as a template image so the system renders it legibly
  in both light and dark menu bars.
- A second launch signals the owner, exits without another tray/helper, and
  restores/focuses the owner's window. A killed owner releases the OS lock;
  stale activation metadata cannot block the next launch.
- Desired bridge On/Off state persists under desktop-owned application data.
  Startup restores last-On through the process service after the dispatcher is
  ready; signed-out restore reaches login-required without spawning a helper.
  Launch at login is an idempotent per-user registration that starts the app
  with `--hidden`; disabling it removes the registration rather than merely
  flipping an in-app flag. Development builds resolve the repository helper
  from the desktop executable path when a login service supplies `/` as the
  working directory; packaged-layout resolution remains a distribution-plan
  concern. The supervised helper receives a login-shell-derived executable
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
- Window position and size persist under desktop-owned application data. Startup reads and validates the last bounds,
  chooses the current display with greatest overlap (or nearest center), clamps size and position to usable work area,
  and applies the result before the first explicit show. Missing/invalid bounds or display discovery falls back to the
  centered 720×620 default. Move/resize events debounce persistence, while close/dispose flush the last observation;
  native/storage failures remain observable without preventing window use.
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
- The signed-in window shows account, process/control status, registration,
  relay state, plugin health, active-session count, takeover/login-required
  states, and recent output after crash give-up. Take Over is an explicit tray
  and window action for local bridge contention or relay displacement; it
  persists On, performs one stop-and-respawn, and accepts only replacement
  prompts from the fresh helper. A persistent desktop sidebar reaches Bridge,
  Projects, and Settings, while exceptional login-required, crash-give-up, and
  takeover recovery appears above every cockpit destination rather than only on
  the bridge dashboard. Recovery starts/retries the supervised helper or opens
  its logs and never offers mobile CLI-install instructions.
- The window routes from supervision into shared project/session inventory,
  settings, profile, and harness-management surfaces without creating another
  auth/session owner. Desktop injects account state, navigation, external-link/
  package metadata, and its coordinated logout workflow; it deliberately omits
  the mobile push-notification preference surface. It instead exposes one
  desktop-owned native attention switch; desktop derives permission/question
  alerts from relay SSE and never registers push. Project recovery never shows
  mobile CLI installation guidance: both never-registered and disconnected
  states offer supervised **Start the bridge**, which persists desired On,
  starts or retries rather than applying toggle semantics, and establishes the
  authenticated desktop relay connection. Session rows open a typed detail
  route that composes the shared transcript, pending interactions, child-session
  navigation, links, and image actions. Root active sessions open the shared
  diff view, and the session list opens shared session creation with plugin,
  model, command, attachment, and dedicated-workspace options. Desktop supplies
  text-first composition and omits voice rather than constructing a dead voice
  capability. A project-scoped nested route owns one session-list cubit: narrow
  windows show one destination, while wide windows keep the selectable session
  inventory beside new-session, transcript, and diff content. Desktop Enter
  sends from the inline composer, Shift+Enter inserts a newline, Escape first
  releases active text editing and otherwise dismisses only popup routes, and
  transcript/diff source text retains native selection/context-menu behavior.
  Profile and Harnesses pop back to Settings when pushed. The analytics service starts before the app, while authenticated
  preference reconciliation is scheduled after the first rendered frame, so a
  slow server cannot leave the window blank; Profile reflects synchronization
  progress until that bounded operation settles. The desktop's one app-wide
  connection banner remains the only banner
  around these routed views.
- Appearance and default-input preferences are read before the first desktop
  frame, provided above the router, and persisted through the same shared
  cubits as mobile. Changing appearance in Settings re-themes the whole window
  immediately rather than only the current route.
- Open Logs prepares the owner-only active log through Layer-1 storage, then
  resolves it through the desktop log repository and delegates it to the system
  default application, including before the helper emits its first line.
- Device-local sign-out locks every bridge lifecycle surface, asks the live
  helper to `unregister_and_exit`, waits for that command's expected exit
  without sending a competing shutdown, and independently deletes the GUI's
  persisted account-bound bridge registration (404 is already success). The
  delete attempt has a bounded timeout and is best-effort offline; a confirmed
  deletion clears the local record, while an unconfirmed deletion keeps it for
  a later retry. A different account never submits or clears the record. Local
  analytics preparation runs after that successful stop and before delivered
  desktop notifications and local tokens are cleared; notification cleanup is
  best effort but always precedes credential clear, and failed token clearing
  resumes analytics for the still-signed-in
  session. If stop fails, authentication and analytics remain intact. Other
  devices are never logged out.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated desktop startup proves eager tray initialization, Prego theme assembly, signed-out login rendering, signed-in cockpit/sidebar supervision rendering, shared desktop Settings with mobile push omitted and native attention exposed, and the typed session-detail route. No plugin. |
| L2 Routine | Automated cubit/adapter coverage for Open/focus, close-to-hide, no-tray close-to-Quit, ordered Quit, quit-preserved desired state, failed-stop/persistence refusal to exit, On/Off recovery, explicit idempotent Start, diagnostics launch, bounds restore/clamp/debounce/flush before first show, durable-Off-before-local-logout, notification cancel-all before credential clear, helper unregister command, no-competing-shutdown expected stop, account-bound persisted bridge-id restart, owner-mismatch protection, 404-idempotent deletion, offline deletion failure, explicit Take Over, cockpit-wide exceptional supervision, both project recovery variants omitting CLI copy, adaptive session split ownership, desktop Enter/Shift+Enter and safe Escape behavior, selectable transcript/diff content, SSE-derived attention gating/routing/cancellation/toggle, desktop transcript rendering and pending-question presentation without dead composer/diff controls, app-wide preference persistence, desktop settings/harness composition, profile logout delegation, analytics-before-auth logout ordering, and failed-logout analytics recovery; cross-process lock/activation, killed-owner recovery, persisted desired state, and auth-gated startup restoration. No plugin. |
| L3 Release | Client end to end on macOS with a dev-built helper and representative live plugin: browser login/relaunch restore, healthy handshake, phone session round-trip, helper crash/backoff, exit-86 restart, login-required behavior, Off/close/Quit orphan checks, and standalone CLI coexistence. |
| L4 Extended | Client end to end on Windows and Linux, including a Linux StatusNotifier host and a no-host windowed fallback; vary helper startup/stop failures, relay takeover, crash give-up output, and default log-file application availability. |
| L5 Full | Packaged desktop artifacts on every release target, including native tray/window appearance, signing/install behavior, and long-running supervision through repeated sleep, reconnect, restart, hide/show, and relaunch cycles. |

## Exploration Guidance

Vary signed-in versus signed-out startup, tray present versus absent, bridge On
versus Off, second launch while visible/hidden, owner crash with stale metadata,
and whether close occurs during a lifecycle transition. Exercise
both clean and failed helper teardown before Quit or sign-out. Exercise Take
Over from local contention and relay displacement, and verify one stop-and-
respawn rather than a restart war. Quit while desired On, relaunch, and verify
last-On restoration. Kill the helper at different handshake phases and inspect
the status and bounded recent output.

## Failure Signals

- No tray or command subscriptions until a signed-in screen reads the cubit.
- A second process creates another tray/helper, fails to focus the owner, or a
  killed owner leaves a lock that bricks future launches.
- Desired Off restores On, last-On never restores, startup bypasses auth gating,
  or bridge restore begins before the control dispatcher owns its event stream.
  Quit while desired On unexpectedly persists Off, or an explicit Take Over is
  missing when local or relay ownership is lost.
- Repeated launch-at-login enables create duplicate registrations, disabling
  leaves a stale login item, a login-launched development build cannot find its
  repository helper or its PATH-installed harnesses, `--hidden` startup hides
  the app without a usable tray,
  the macOS window flashes or remains visible during hidden startup, or a normal
  manual launch unexpectedly starts hidden.
- Close hides the only surface when no tray host exists, ignores a close during
  lifecycle work, Open shows without focusing, native close bypasses teardown,
  or the macOS tray icon has an opaque background/wrong light-dark treatment,
  the Dock still shows a hidden window, or secondary tray clicks do nothing.
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
- Restored bounds are applied after a visible flash, land wholly off-screen, ignore current display work areas, fail to
  persist after move/resize, or one failed write prevents later bounds from saving.
- Window and tray disagree on desired state, status, or active-session count.
- Takeover, login-required, or crash give-up is rendered as healthy/connected,
  a takeover starts a restart war or approves a non-replacement prompt, recent
  crash output is absent, Open Logs targets a nonexistent/bypassed file, or a
  supervised Full Disk Access warning tells the user to authorize only
  Terminal instead of the process running the bridge.
- The desktop theme lacks Prego colors, typography, or design-system extension;
  a saved appearance flashes the system theme at startup, changing it affects
  only one route, a routed settings view renders a second connection banner,
  desktop exposes a dead mobile-notification preference row, a pushed settings
  child closes to Home, a standalone child cannot close, startup reconciliation
  leaves the window blank, Profile leaves usage analytics stuck on Loading, or
  logout clears auth before analytics preparation and fails to resume analytics
  when token clearing fails. A desktop session row cannot reach its typed detail
  route, Back cannot return to the session list, a child-session link loses its
  typed route data, New task or file changes cannot reach their typed routes, or
  desktop renders unsupported voice/attachment controls, Enter inserts a newline instead of sending, Shift+Enter sends,
  Escape pops an ordinary cockpit page or steals a closer modal/editor handler, source text cannot be selected, or wide
  session navigation recreates/discards its project-scoped inventory.

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
  the checkout even when launchd changes the working directory. Packaged-path
  migration belongs to the later desktop-distribution plan.

## Sources

- `client/module_desktop_core/lib/src/cubits/bridge_control/`
- `client/module_desktop_core/lib/src/foundation/platform/bridge_process_environment.dart`
- `client/desktop/lib/core/platform/io_bridge_process_environment.dart`
- `client/module_desktop_core/lib/src/orchestration/desktop_bridge_takeover_orchestrator.dart`
- `client/module_desktop_core/lib/src/orchestration/desktop_logout_orchestrator.dart`
- `client/module_desktop_core/lib/src/services/window_bounds_service.dart`
- `client/module_desktop_core/lib/src/services/desktop_attention_service.dart`
- `client/module_desktop_core/lib/src/api/bridge_id_storage.dart`
- `client/module_core/lib/src/api/bridge_api.dart`
- `client/module_core/lib/src/repositories/bridge_repository.dart`
- `client/desktop/lib/core/platform/flutter_window_host.dart`
- `client/desktop/lib/features/home/desktop_home.dart`
- `client/desktop/lib/features/projects/desktop_project_list_screen.dart`
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
