# Step 15 — 🚧 Settings + harness management slice

Date: 2026-09-01.

## Delivered

- Moved settings, profile, notification-preference, and harness-management
  presentation from the mobile shell into `client/module_app_ui`. Shared views
  receive cubits and product capabilities from their callers rather than
  resolving shell DI or owning product routes.
- Kept mobile as a thin composition shell. It still constructs the relevant
  cubits, injects notification preferences, renders legal documents in-app,
  supplies package metadata and the product logo, opens support links through
  its platform strategy, and owns post-logout navigation.
- Added authenticated desktop Home, Settings, Profile, and Harnesses routes
  under one `AuthGate` route shell. The desktop wrappers construct cubits from
  desktop DI, open public legal/support URLs externally, omit the mobile-only
  notification row, and reuse the shared harness setup/install/login/restart/
  idle-policy/catalog-rescan presentation.
- Preserved supervised logout ordering by routing profile logout through
  `AuthGateCubit` and `DesktopLogoutOrchestrator`. `AuthGateCubit.signOut()` now
  returns the typed `DesktopLogoutOutcome` so the shared profile view can keep
  the user on-screen and show a failure when coordinated logout is incomplete.
- Promoted appearance and chat-input-mode cubits to desktop app scope. Their
  persisted values are loaded before `runApp`, both are provided above the
  router, and appearance changes immediately rebuild the app-wide Prego theme.
- Kept connection presentation single-owned: mobile injects its scaffold-local
  banner while desktop omits a view-local banner because its root already owns
  the global connection banner.
- Moved shared legal/support link definitions, clipboard support, appearance
  presentation, and catalog-scan UI alongside the shared screens. Product
  shells retain package metadata, platform link policy, DI, routes, and product
  assets.
- Updated client architecture guidance and the desktop-supervision and plugin-
  lifecycle regression documents for the new shared ownership and desktop
  destinations.
- Review hardening keeps mobile package metadata behind its registered platform
  client, starts desktop analytics locally before launch and defers authenticated
  reconciliation until after the first frame, pops pushed Profile/Harnesses back
  to Settings with a standalone Home fallback, and serializes harness
  authentication presentation across rows while allowing dismissed and uncertain-
  cancellation challenges to be reopened. Desktop logout prepares analytics
  before token clearing and resumes it when token clearing fails.

No database schema, persisted-data format, bridge/client wire contract,
authentication token authority, or analytics event changed. Mobile behavior is
preserved; the user-visible change is that desktop now exposes real Settings,
Profile, and Harnesses destinations.

## Architecture implementation review

Approved with no findings. The reviewer checked the Step 15 working-tree scope,
including the shared-package dependency graph, shell-owned DI/routes/platform
strategies, app-wide preference lifecycle, desktop logout orchestration,
connection-banner ownership, and the direct `module_app_ui` dependency on
`sesori_shared`. The latter is an allowed foundation dependency under the
client architecture rules. A second bounded review approved the review-
hardening seams for desktop analytics startup, pushed-route ownership, mobile
package metadata, and shared authentication presentation with no findings.

## Verification

- `client/module_app_ui`: `dart analyze --fatal-infos` clean; all 35 Flutter
  tests passed.
- `client/app`: `dart analyze --fatal-infos` clean; all 895 Flutter tests passed.
  The 20 legal/catalog tests moved into `module_app_ui`, keeping the combined
  shared-plus-mobile count at 930.
- `client/desktop`: `dart analyze --fatal-infos` clean; all 67 Flutter tests
  passed, including desktop settings, preference persistence, logout
  delegation, omitted notifications/banner, and harness rendering coverage.
- `client/module_desktop_core`: `dart analyze --fatal-infos` clean; all 199 Dart
  tests passed, including typed logout-outcome behavior.
- Dart LSP diagnostics reported zero findings across 56 shared/mobile/desktop
  integration files.
- `asdf exec flutter build macos` completed successfully (`Sesori.app`,
  59.6 MB).
- First review follow-up: all three owning analyzers remained clean; 70 focused
  mobile settings/harness tests and 4 focused desktop smoke/settings tests
  passed; a fresh macOS release build succeeded (`Sesori.app`, 59.8 MB).
- Second review follow-up: all four owning analyzers remained clean; 42 focused
  harness tests, 14 desktop-logout/DI tests, and 4 desktop smoke/settings tests
  passed; a fresh macOS release build again succeeded (`Sesori.app`, 59.8 MB).
- `git diff --check` is clean. Windows and Linux desktop builds remain covered
  by the PR's native CI matrix.

## Handoff

Step 16 can move the project/session-list slice into `module_app_ui` and add the
desktop offline strategy while reusing the authenticated desktop route shell,
shared preferences, connection presentation, and product-shell injection seams
established here.
