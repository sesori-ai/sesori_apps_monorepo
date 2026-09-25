# Step 27 — Missing folders

## What changed

- `ProjectSummary` gains `directoryMissing`, which defaults to `false`. It has a
  `// COMPATIBILITY 2026-09-24 (v1.9.1)` marker. An older bridge omits the
  field, so its projects read as present, which is today's behaviour. An older
  app ignores the new key.
- On the bridge, `ProjectRepository.getProjects` probes each project's folder
  and passes the result through `ProjectCatalogMapper.mapSummary`. The check
  uses the same `_directoryMissing` helper as the open and rename paths.
- `module_core` `discoverProject` now passes the field through to the project
  it adds to the list.
- The phone project row shows "Folder not found" in amber in its status slot,
  with a folder-off icon. This outranks running and unread. A Remove button
  takes the chevron's place. The row's menu and its swipe action say Remove
  instead of Hide, and Remove hides the project.
- The desktop sidebar project row shows an amber folder-off icon in its status
  slot, ahead of running and unread. Its tooltip and screen-reader label say
  "Folder not found", and its menu says Remove.

## Deviations

- **The probe is asynchronous and time-limited.** The plan says "with the
  existing directory check", which was a synchronous `existsSync`. The list
  runs it for every project, and a folder on a stalled network or removable
  drive would block the bridge isolate. So `_directoryMissing` now uses
  `directoryExistsAsync` with a 2-second limit, the same pattern as step 25's
  drive probe. A probe that times out is logged and reads as present, and so
  does one that fails with a `FileSystemException`. The open and rename paths
  share the helper, so they gained the same limit.
- **`GET /projects` probes the filesystem again.** PR #907 made the list free
  of filesystem and Git probes. Its reason was Git processes exhausting file
  descriptors. This step brings back only a stat for each row, with no Git
  process, as the plan directs. The test that expected zero probes now
  expects one probe for each folder and still no Git calls.
- **The desktop row has an icon, not the phrase.** A sidebar row has no room
  for "Folder not found" beside a project name. In a test at the default
  width it overflowed by 80 px, and the name must keep priority. So the phrase
  goes in the row's tooltip and screen-reader label, the same way the sidebar
  already shows unread. The icon is amber.
- **Remove hides the project.** It uses the existing hide request. A missing
  folder has nothing to come back to, so the label changes and the behaviour
  stays the same.
- **No note on the project page.** D26 drops MS9's line above the session list.

## Verification

- Shared: `project_management_models_test`. The list carries
  `directoryMissing`, and an omitted field reads as present.
- Bridge: `test/bridge/repositories/`, `test/bridge/routing/` and
  `test/bridge/services/` pass. The repository test flags a missing folder and
  reads an unreadable one as present. The handler test checks that the
  `GET /projects` JSON carries `directoryMissing`.
- Phone: `client/app` `test/features/project_list/` passes (86 tests). They
  cover the amber "Folder not found" ahead of running, the row height kept at
  96, and a Remove button with its own semantics that hides the project.
- Desktop: `desktop_cockpit_shell_test` passes (64 tests). They cover the
  amber icon, the "Gone, Folder not found" tooltip, and Remove in the menu.
- `module_app_ui` project-list tests and the `module_core` project repository
  tests pass.
- `dart analyze --fatal-infos` is clean in bridge/app, sesori_shared,
  module_core, module_app_ui, desktop and app.
- The architecture implementation review approved the change with no
  findings. It noted that the switch to an asynchronous probe should be
  mentioned in the PR.
- Size: 373 changed lines before this evidence file, of which 47 are
  generated (freezed, json and l10n). About 45 lines in `project_tile.dart`
  only change indentation, from wrapping the row for the Remove button.
- Before and after renders use fixture data only.
