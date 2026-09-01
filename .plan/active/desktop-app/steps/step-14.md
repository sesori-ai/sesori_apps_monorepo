# Step 14 — ⚙️ Create `module_app_ui` + shared foundations

Date: 2026-09-01.

## Delivered

- Created the `client/module_app_ui` Flutter workspace package above
  `module_core`, with no dependency on either product shell or
  `module_desktop_core`.
- Moved ownership of the shared ARB resources, generated localization files,
  `l10n.yaml`, and `BuildContext` localization/date helpers from the mobile
  shell into `module_app_ui`. Mobile now consumes the package through its
  public entry point.
- Moved the surface-neutral GoRouter-backed `RouteSource` implementation into
  `module_app_ui`. Mobile and desktop retain thin shell lifecycle adapters and
  continue to own their own route tables.
- Added the desktop GoRouter skeleton over `AppRouteDef.splash`, preserving the
  existing `AuthGate` as the rooted destination until the shared feature
  slices land in steps 15–19. The desktop root now supplies shared localization
  delegates and supported locales.
- Moved the localized connection banner and SSE toast listener into
  `module_app_ui`, replacing the temporary desktop duplicates while preserving
  shell-owned cubit construction and navigator composition.
- Converged the mobile root onto `buildPregoThemeData`, the same terminal Prego
  theme-assembly helper used by desktop.
- Added `module_app_ui` to workspace tooling, mobile package-local analyze/test,
  desktop downstream path gating, and mobile release path gating. Updated the
  client architecture instructions and workspace documentation to reflect the
  live dependency graph.

No database schema, persisted-data format, wire contract, authentication,
bridge-supervision, or analytics event changed. The visible mobile UI remains
behaviorally unchanged; desktop now has the localization and route foundation
required by the upcoming shared cockpit screens.

## Architecture implementation review

Approved with no findings. The review covered the complete working-tree diff
against `origin/main`, including moved and untracked files, and verified package
dependency direction, thin-shell ownership, product-owned route tables,
GoRouter `RouteSource` lifecycle adapters, localization/theme ownership,
Cubit construction, and CI responsibility. The reviewer returned
`Merge verdict: OK — APPROVED`.

## Verification

- `client/`: `asdf exec dart pub get` completed successfully.
- `client/module_app_ui`: `dart analyze --fatal-infos` clean; all 15 Flutter
  tests passed.
- `client/app`: `dart analyze --fatal-infos` clean; all 915 Flutter tests
  passed.
- `client/desktop`: `dart analyze --fatal-infos` clean; all 64 Flutter tests
  passed.
- App and desktop Injectable outputs regenerated successfully; localization
  outputs regenerated from `client/module_app_ui/l10n.yaml`.
- Dart LSP diagnostics reported zero findings across the new shared package and
  both shell integration points.
- `asdf exec flutter build macos` completed successfully (`Sesori.app`,
  56.4 MB).
- `git diff --check` is clean. Windows and Linux desktop builds remain covered
  by the PR's native CI matrix.

## Handoff

Step 15 can now move the settings and harness-management slice into
`module_app_ui`, extend the desktop router, and inject surface-specific logout,
notification-preference, package-link, and navigation strategies without
recreating localization, route observation, connection presentation, or theme
assembly.
