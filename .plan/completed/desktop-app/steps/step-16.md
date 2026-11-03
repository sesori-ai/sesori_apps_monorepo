# Step 16 — Project/session lists slice + desktop offline strategy

- **Status:** `done`
- **Complexity:** `🚧`
- **User value:** Meaningful app content appears in the desktop window.
- **Dependencies:** Steps 14–15

## Scope

- Move project/session-list and reusable `session_split` presentation into
  `client/module_app_ui`.
- Preserve mobile bridge installation/reconnect guidance through injected mobile
  strategy/widgets.
- Add desktop project/session-list routes and desktop-owned recovery widgets.
- Map desktop disconnected states to the supervised local bridge action.

## Implementation Summary

- Moved reusable project/session inventory, row actions, errors, rename flows,
  and adaptive `session_split` presentation from the mobile shell into
  `client/module_app_ui`.
- Kept shell-owned policy at the product boundary: mobile still injects CLI
  installation/share and relay reconnect surfaces, its archived-session
  artwork, connection banners, and navigation; desktop injects supervised
  bridge recovery, routes, and artwork-free empty presentation.
- Added authenticated desktop Projects and project-scoped Sessions routes. The
  desktop session list intentionally omits new-session and session-detail
  controls until their corresponding plan slices land.
- Added `BridgeControlCubit.startBridge()` as an explicit desired-On operation.
  It persists On and starts or retries the supervised helper without toggle
  semantics; desktop recovery runs that intent alongside the existing
  authenticated relay reconnect, so both disconnected variants can reload.
- Removed the empty-string session-title sentinel. Route composition now keeps a
  missing title nullable and lets canonical session data hydrate it.
- Moved shared project-dialog and session-presentation tests into
  `module_app_ui`; added focused mobile/desktop recovery tests and updated the
  project/session, connectivity, and desktop-supervision regression contracts.

## Architecture Review

- `architecture-implementation-review`: **APPROVED** with no findings.
- The reviewer confirmed that `module_app_ui` remains surface-neutral,
  product-shell routing/assets/offline policy stay shell-owned, desktop recovery
  enters through the existing Layer-4 supervision path, GUI logout authority is
  unchanged, and unsupported desktop session controls remain omitted.
- Review artifact: `/tmp/desktop-step16-architecture-review.md`.

## Verification

- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos`; 89 tests pass.
- `client/app`: `asdf exec dart analyze --fatal-infos`; 844 tests pass.
- `client/desktop`: `asdf exec dart analyze --fatal-infos`; 70 tests pass.
- `client/module_desktop_core`: `asdf exec dart analyze --fatal-infos`;
  `asdf exec dart test` passes 201 tests.
- Focused recovery coverage proves mobile keeps CLI guidance and omits desktop
  Start, while desktop never-registered and registered-but-disconnected states
  both invoke supervised Start and never render CLI copy.
- Dart LSP reports zero diagnostics across 101 relevant files.
- `git diff --check` passes.
- `asdf exec flutter build macos --release` succeeds (59.3 MB reported by
  Flutter; 57 MB on disk).

## Acceptance

- [x] Mobile keeps installation/reconnect guidance.
- [x] Desktop offers to start the supervised local bridge both when the account
  has no registered bridge and when a registered bridge is disconnected.
  Desktop does not show CLI installation instructions.
- [x] Shared presentation tests pass.
