# Step 20 — Desktop cockpit composition + attention notifications

- **Status:** `done`
- **Complexity:** `🚧`
- **User value:** Desktop users have a persistent cockpit with adaptive session navigation, desktop-native keyboard behavior, remembered window placement, integrated bridge recovery, and privacy-safe local alerts when a background session needs attention.
- **Dependencies:** Steps 1–19

## Scope

- Compose the slice-built desktop routes into a persistent Bridge / Projects / Settings cockpit with project-scoped adaptive session navigation.
- Integrate exceptional supervised-helper recovery around every authenticated destination.
- Add desktop keyboard, dismissal, and text-selection behavior without changing mobile policy.
- Restore and persist window bounds through the established desktop architecture layers.
- Derive local permission/question attention from authenticated relay events without registering desktop push or exposing request content.

## Implementation Summary

- Added `DesktopCockpitShell`, which keeps Bridge, Projects, and Settings reachable through a persistent navigation rail and renders login-required, crash-give-up, and takeover recovery above every routed destination. Recovery retries/starts the supervised helper and reconnects the authenticated relay client, opens logs, or performs the existing explicit takeover; it never offers mobile CLI-install guidance.
- Nested the project session routes beneath one project-scoped `DesktopSessionListCubitProvider`. Narrow windows preserve one-pane navigation, while wide windows keep the shared session inventory beside new-session, transcript, and diff content without recreating the inventory for each child route.
- Added a shared `ComposerSendKeyPolicy`: desktop Enter sends and Shift+Enter inserts a newline while active IME composition retains Enter for candidate confirmation; mobile retains plain Enter as newline and Cmd/Ctrl+Enter as its hardware-keyboard send shortcut. Desktop Escape first releases active text editing, otherwise dismisses any typed popup route, and does not replace page Back or a closer surface-specific handler. Child-session Back pops to its parent, and diff source shares one readable selection region across lines while excluding navigation/file-header chrome and line-number/prefix gutters; transcript content retains native selection/context menus.
- Extended the pure-Dart `WindowHost` seam with typed state, bounds operations, move/resize events, display work areas, and a service-supplied minimum size. `DesktopInstanceStorage` and `DesktopInstanceRepository` persist bounds, `WindowBoundsService` validates/selects/clamps/restores and debounces writes, `DesktopStartupOrchestrator` restores before the first explicit show, and `FlutterWindowHost` alone adapts native window/display plugin types. Tray Quit awaits the bounds owner’s final flush before disposing the native host and terminating.
- Added shared disposable `LocalNotificationClient`, `NotificationCanceller.cancelAll()`, and typed `LocalNotificationPayload`; desktop payloads include a non-rendered account binding while mobile reuses the shared payload without changing its push-registration or foreground/open behavior.
- Added `DesktopAttentionService` in desktop-core. It listens directly to authenticated relay SSE, classifies permission/question asked and resolved events, tracks each outstanding request beneath its display session, resolves only session title/project metadata, suppresses alerts while focused/disabled/unauthenticated, and reconsiders pending attention when those gates open. Per-session writes are serialized, generation checks prevent resolved requests from reappearing after lookup, and cancellation occurs only after the last request settles. Initial opens defer only for a locally restorable session, require a matching account binding, and wait for an app-level router-mounted fence before focusing/replacing the typed desktop route stack.
- Added the shell-owned `DesktopLocalNotificationClient` for macOS, Linux, and Windows, with deterministic session identities, typed payload encoding, launch/open handling, per-session/all cancellation, and DI-managed disposal. Desktop never registers a push token; notification bodies contain category-only copy and never prompt, transcript, question, permission-description, or tool payload.
- Added an enabled-by-default, desktop-local attention preference and Settings toggle. Disabling it clears delivered alerts. The attention service owns logout's fence, started-write settlement, and cancel-all operation before credential removal; failed logout also awaits that cleanup before resuming alerts. Account-ending auth transitions outside logout clear alerts, reject stale opens, and hold a newly authenticated account's alerts until prior-account cleanup finishes.
- Native notification initialization and operations are failure-isolated and logged, so unavailable OS notification services cannot block desktop startup or session work. The open listener is attached before Linux initialization can emit its callback, and a transient initialization failure retries on the next eligible attention request.
- Considered analytics for the new controls and intentionally added no event: notification content and session identity are sensitive, while rail navigation, Escape, window movement, and preference taps do not provide a sufficiently actionable bounded product outcome beyond existing session/feature analytics.

## Architecture Review

- The first `architecture-implementation-review` rejected three architecture boundaries: the Layer-0 native window adapter read Layer-3 minimum-size constants, tray Quit disposed the native host without flushing the bounds owner, and the Layer-0 route adapter imported product route configuration.
- Fixed all three directly: `WindowBoundsService` now passes typed `WindowSize` policy through `WindowHost.initialize`; terminal Quit awaits service disposal/pending writes before `WindowHost.dispose`; and shell DI injects the `GoRouter` instance into `DesktopRouteDispatcher`. Added pending-resize → tray-Quit coverage.
- The permitted second review used the authoritative clean-worktree `origin/main...HEAD` artifact and returned **APPROVED — PASS** with no remaining blocker or non-blocking architectural finding. It confirmed restore-before-show, local/privacy-bounded attention, shell-owned routing/DI, and pure-Dart cubit ownership.

## Verification

- `client/module_core`: `asdf exec dart analyze --fatal-infos` passes; the complete pure-Dart suite passes 1,484 tests.
- `client/module_desktop_core`: `asdf exec dart analyze --fatal-infos` passes; the complete pure-Dart suite passes 250 tests, including bounds, attention gate/resume and request-generation races, serialized native writes, initialization retry/Linux callback ordering, account-bound opens, cross-account cleanup fencing, preference, persistence, terminal-flush, and service-owned logout settle-before-cancel ordering.
- `client/module_prego`: `asdf exec dart analyze --fatal-infos` passes; the complete Flutter suite passes 267 tests after excluding navigation chrome from enclosing selection regions.
- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the complete Flutter suite passes 281 tests, including desktop/mobile key-policy, active-IME preservation, and source-only multi-line diff-selection coverage.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the complete Flutter suite passes 116 tests, including nested routes, adaptive cockpit composition, coordinated recovery, mounted route dispatch, typed-popup Escape handling, retryable native notification initialization, Settings composition, and window restoration.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the complete mobile Flutter suite passes 661 tests after adopting the shared notification payload and explicit mobile key policy.
- Dart LSP reports zero diagnostics across the architecture-bearing implementation and the review-fix scope; `git diff --check` passes.
- A clean `asdf exec flutter build macos --release` succeeds (66.3 MB reported by Flutter), and `codesign --verify --deep --strict` accepts the resulting app bundle.
- Windows/Linux native compilation and real OS-notification interaction are delegated to CI and user-run Gate C. No real account, relay, plugin prompt, or persisted desktop state was changed during automated verification.

## Acceptance

- [x] Persistent cockpit navigation and project-scoped adaptive session composition are operational.
- [x] Exceptional supervision recovery remains visible across authenticated destinations, starts the helper plus relay recovery, and never shows mobile CLI copy.
- [x] Desktop Enter / Shift+Enter with IME preservation, safe Escape dismissal, and source-only native text selection are covered without changing mobile behavior.
- [x] Valid restored bounds are clamped to current display work areas and applied before the first explicit show; updates persist through the required layers.
- [x] Desktop attention is local, focus/preference/auth gated, session-scoped, privacy-safe, and never registers push.
- [x] Account-bound notification opens wait for router mount, focus the desktop, and route to the typed display session; final resolve, disable, logout, and account-ending auth loss clear delivered alerts.
- [x] Native notification failures remain observable but cannot block startup, logout, or session work.
- [x] Affected analyzers, complete suites, LSP diagnostics, clean macOS release build, and signing verification pass.
- [ ] MT Gate C remains user-run and is not marked passed by this implementation step.
