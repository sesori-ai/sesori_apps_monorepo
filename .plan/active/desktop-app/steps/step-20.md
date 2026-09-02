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

- Added `DesktopCockpitShell`, which keeps Bridge, Projects, and Settings reachable through a persistent navigation rail and renders login-required, crash-give-up, and takeover recovery above every routed destination. Recovery retries/starts the supervised helper, opens logs, or performs the existing explicit takeover; it never offers mobile CLI-install guidance.
- Nested the project session routes beneath one project-scoped `DesktopSessionListCubitProvider`. Narrow windows preserve one-pane navigation, while wide windows keep the shared session inventory beside new-session, transcript, and diff content without recreating the inventory for each child route.
- Added a shared `ComposerSendKeyPolicy`: desktop Enter sends and Shift+Enter inserts a newline; mobile retains plain Enter as newline and Cmd/Ctrl+Enter as its hardware-keyboard send shortcut. Desktop Escape first releases active text editing, otherwise dismisses only popup routes, and does not replace page Back or a closer surface-specific handler. Diff source and transcript content retain native selection/context menus.
- Extended the pure-Dart `WindowHost` seam with typed state, bounds operations, move/resize events, display work areas, and a service-supplied minimum size. `DesktopInstanceStorage` and `DesktopInstanceRepository` persist bounds, `WindowBoundsService` validates/selects/clamps/restores and debounces writes, `DesktopStartupOrchestrator` restores before the first explicit show, and `FlutterWindowHost` alone adapts native window/display plugin types. Tray Quit awaits the bounds owner’s final flush before disposing the native host and terminating.
- Added shared disposable `LocalNotificationClient`, `NotificationCanceller.cancelAll()`, and typed `LocalNotificationPayload`; mobile now reuses the shared payload without changing its push-registration or foreground/open behavior.
- Added `DesktopAttentionService` in desktop-core. It listens directly to authenticated relay SSE, classifies permission/question asked and resolved events, resolves only session title/project metadata, suppresses alerts while focused/disabled/unauthenticated, queues an initial open until authentication, cancels resolved session alerts, and focuses/replaces the typed desktop route stack when an alert opens.
- Added the shell-owned `DesktopLocalNotificationClient` for macOS, Linux, and Windows, with deterministic session identities, typed payload encoding, launch/open handling, per-session/all cancellation, and DI-managed disposal. Desktop never registers a push token; notification bodies contain category-only copy and never prompt, transcript, question, permission-description, or tool payload.
- Added an enabled-by-default, desktop-local attention preference and Settings toggle. Disabling it clears delivered alerts. Desktop logout clears every delivered alert before credential removal; native cancellation remains best effort and cannot block logout.
- Native notification initialization and operations are failure-isolated and logged, so unavailable OS notification services cannot block desktop startup or session work.
- Considered analytics for the new controls and intentionally added no event: notification content and session identity are sensitive, while rail navigation, Escape, window movement, and preference taps do not provide a sufficiently actionable bounded product outcome beyond existing session/feature analytics.

## Architecture Review

- The first `architecture-implementation-review` rejected three architecture boundaries: the Layer-0 native window adapter read Layer-3 minimum-size constants, tray Quit disposed the native host without flushing the bounds owner, and the Layer-0 route adapter imported product route configuration.
- Fixed all three directly: `WindowBoundsService` now passes typed `WindowSize` policy through `WindowHost.initialize`; terminal Quit awaits service disposal/pending writes before `WindowHost.dispose`; and shell DI injects the `GoRouter` instance into `DesktopRouteDispatcher`. Added pending-resize → tray-Quit coverage.
- The permitted second review used the authoritative clean-worktree `origin/main...HEAD` artifact and returned **APPROVED — PASS** with no remaining blocker or non-blocking architectural finding. It confirmed restore-before-show, local/privacy-bounded attention, shell-owned routing/DI, and pure-Dart cubit ownership.

## Verification

- `client/module_core`: `asdf exec dart analyze --fatal-infos` passes; the complete pure-Dart suite passes 1,484 tests.
- `client/module_desktop_core`: `asdf exec dart analyze --fatal-infos` passes; the complete pure-Dart suite passes 235 tests, including bounds, attention, preference, persistence, terminal-flush, and logout ordering.
- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the complete Flutter suite passes 279 tests, including desktop/mobile key-policy and selectable diff coverage.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the complete Flutter suite passes 115 tests, including nested routes, adaptive cockpit composition, supervision notices, Escape handling, native notification adaptation, Settings composition, and window restoration.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the complete mobile Flutter suite passes 661 tests after adopting the shared notification payload and explicit mobile key policy.
- Dart LSP reports zero diagnostics across 20 unique architecture-bearing production files over the initial and post-review passes; `git diff --check` passes.
- A clean `asdf exec flutter build macos --release` succeeds (66.3 MB reported by Flutter), and `codesign --verify --deep --strict` accepts the resulting app bundle.
- Windows/Linux native compilation and real OS-notification interaction are delegated to CI and user-run Gate C. No real account, relay, plugin prompt, or persisted desktop state was changed during automated verification.

## Acceptance

- [x] Persistent cockpit navigation and project-scoped adaptive session composition are operational.
- [x] Exceptional supervision recovery remains visible across authenticated destinations without mobile CLI copy.
- [x] Desktop Enter / Shift+Enter, safe Escape dismissal, and native text selection are covered without changing mobile behavior.
- [x] Valid restored bounds are clamped to current display work areas and applied before the first explicit show; updates persist through the required layers.
- [x] Desktop attention is local, focus/preference/auth gated, session-scoped, privacy-safe, and never registers push.
- [x] Notification opens focus the desktop and route to the typed display session; resolve, disable, and logout clear delivered alerts.
- [x] Native notification failures remain observable but cannot block startup, logout, or session work.
- [x] Affected analyzers, complete suites, LSP diagnostics, clean macOS release build, and signing verification pass.
- [ ] MT Gate C remains user-run and is not marked passed by this implementation step.
