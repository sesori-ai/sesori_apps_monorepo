# Step 25 — Windows drives

## What changed

- `FilesystemSuggestions` carries `driveRoots`, `@Default([])` with a
  `COMPATIBILITY 2026-09-24 (v1.9.1)` marker: a bridge older than the field
  omits it and the browser shows no drives, as before; an older app ignores
  it.
- `FilesystemApi` gains `directoryExistsAsync`, `isWindows` and an
  `environment` map, which replaces `environmentValue`.
- `FilesystemRepository.listDriveRoots` returns `[]` off Windows. On Windows
  it probes `A:\` to `Z:\` at once and returns the mounted roots in letter
  order.
- `FilesystemSuggestionsHandler` adds the roots only to a request without a
  prefix, which is the browser's opening request.
- `defaultBrowsePath` uses `resolveUserHomeDirectory`, so Windows now prefers
  `USERPROFILE` over `HOME`.
- The add-project browser keeps the roots from its first listing. When there
  are any, a row of chips (Home, `C:\`, `D:\`) sits above the breadcrumb, and
  each chip opens that place.

## Deviations

- **Probe timeout.** Each drive probe that has not answered within two
  seconds counts as unmounted. The plan only asks that the probe be
  asynchronous. Without the timeout, a disconnected mapped network drive
  (a common Windows state) would still hold up the browser's first listing
  for as long as Windows takes to give up on it.
- **Chips instead of breadcrumb entries.** The plan says "beside Home". The
  breadcrumb reaches only the drive being browsed, so Home and the drives
  share one row of chips above it. The row shows only when the bridge
  reports drives, so macOS and Linux hosts look the same as before.
- **No "update the bridge" notice.** An older bridge that sends no drives
  looks the same as a host that has none. It degrades to today's browser,
  where the breadcrumb root still reaches the current drive, so nothing
  breaks and there is no limitation to surface.

## Verification

- `bridge/app`: `filesystem_repository_test` (drives off Windows, mounted
  drives in letter order, a stalled probe skipped after the timeout under
  `fake_async`, home resolution) and `filesystem_suggestions_handler_test`
  (drives only on the prefix-less request), 33 tests.
- `shared/sesori_shared`: `project_management_models_test`, including a
  round-trip of the roots and a payload without the field decoding to no
  drives.
- `client/module_app_ui` `test/features/project_list/` (25 tests): a Windows
  bridge's drives appear beside Home and open their drive, and no chips
  appear without drives.
- `dart analyze --fatal-infos` is clean in bridge/app, sesori_shared and
  module_app_ui.
- `architecture-implementation-review`: approved on the first pass.
- Windows drive listing has not been checked on a real Windows host. The
  automated fakes are the only proof, as the plan expects.
- Before and after renders (phone and desktop, fixture data) are in the PR
  body.
