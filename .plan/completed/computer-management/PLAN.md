# Computer management: see, rename, and remove computers

## Status and scope

- Date: 2026-10-15. Planning base: `origin/main` in the provided `brown-dingo` worktree.
- Source: the follow-up that the `multi-computer` plan (issue #947, `.plan/completed/multi-computer/`) deferred:
  remove and rename computers on phone and desktop, a “Manage computers…” menu footer, and a Computers page.
- Status: plan raised. UX agreed with the user on 2026-10-15 over two review rounds (D1–D9 below).
- Repositories: `sesori_auth_server` (Node, default branch `master`) and this monorepo. Every PR uses the
  `[computer-management]` slug and the shared step numbering below. No relay change. The bridge changes only in its
  `BridgeSummary` test fixtures; its behavior is unchanged.
- Vocabulary: the product says **computer**; code keeps `bridge`/`bridgeId`.

## Outcome

- One Computers page, shared by phone and desktop, lists every computer on the account with platform, status and
  last seen. A nicknamed computer shows its hostname beneath the nickname.
- Each row's “⋯” opens Switch, Rename… and Remove….
- A rename is stored on the server and replaces the hostname everywhere: the menu, Settings, the desktop
  “Viewing:” header, the offline screen, the linked-computer alert and the online/offline push titles. A bridge
  restart never undoes it.
- Removing an offline computer drops it from the account on every device.
- The Settings computer entry becomes a flat row under the kept “Bridge” caption.

## Decisions

| # | Decision (user, 2026-10-15) |
|---|---|
| D1 | The Computers page is a list with a “⋯” per row opening Switch / Rename… / Remove… (a Prego anchor menu). On desktop, a right-click on the row opens the same menu. There is no detail page and no swipe action. |
| D2 | Only offline computers can be removed. For an online computer, Remove is disabled, with the hint “Quit Sesori on <name> to remove it”. |
| D3 | On the phone, removing the computer you are viewing moves you to another computer, as a normal switch would. |
| D4 | On desktop, Remove stays in the menu for “This computer”. It opens an info modal instead of removing anything. The modal says the computer in use can't be removed, and that turning off its bridge makes it unreachable from every device, this one included. Its “Turn off bridge” button uses the existing bridge On/Off control and is hidden while the bridge is already off. |
| D5 | Rename is a dialog prefilled with the current name, with a “Use hostname” action. An empty field clears the nickname too. The Computers page shows the hostname under a nickname; every other surface shows only the name. |
| D6 | The Settings computer row keeps opening the computer menu. “Manage computers…” is the menu's footer wherever the menu opens: Projects, Settings and the desktop “Viewing:” header. |
| D7 | With only one computer, the Projects header still shows no menu, so management is reached from Settings only. |
| D8 | The Settings computer entry is a flat row (no card, no icon tile) under the kept “Bridge” caption. |
| D9 | Remove asks for confirmation: “Remove <name>? It disappears from every device. Starting Sesori on it signs it back in as a new computer.” There is no undo. |

## Current behavior (evidence, 2026-10-15)

- **Auth: the bridge document has no nickname.**
  - `name` (1–120 characters) is overwritten with the machine name on every bridge start. The bridge POSTs
    `resolveLocalMachineName` from `bridge_runtime_runner.dart`, and `bridge-repo.ts` `#updateRegistration` `$set`s it.
  - `toSummary` in `bridge-service.ts` returns `{id, name, addedAt, lastSeenAt, platform, status}`. It serves
    `GET /auth/bridges` and `/auth/me`.
- **Auth: push titles.** They use `recordStatusChange`'s `before.name`, passed through `recordStatusReport` to
  `bridge-state-tracker.ts`, which builds “<name> is online” and “<name> went offline”.
- **Auth: removal.** `DELETE /auth/bridges/:id` soft-revokes: `status: inactive` and `revokedAt`, with no relay call.
  - A running bridge learns of it on its next status report: a 404, then close `4006`. It then re-registers under a
    new id.
  - A removed offline computer also returns as a new entry when its bridge next starts, because host-key matching
    skips revoked entries.
  - The only client caller is the desktop logout orchestrator.
- **Client data.**
  - `BridgeSummary` lives in `sesori_shared`.
  - `BridgeApi` and `BridgeRepository` already have `deleteBridge`; a 404 counts as success.
  - `RegisteredBridgesService` publishes `bridges` as a `ValueStream`, memoised by `_bridgesCurrent`. Presence
    patches status in place, and an unknown id refetches. It has no remove or rename and no way to patch an entry.
- **Client switching.**
  - `SelectedComputerService.select` logs `computer_switched` and calls `ConnectionService.retarget`, which takes a
    non-null id.
  - `ComputerSwitchDispatcher.switchTo` resets to the Projects root, then selects.
  - Nothing reacts to a target vanishing from the list: `ComputerSwitcherState.currentId` keeps a removed target.
- **Client UI.**
  - `ComputerMenu` (`module_app_ui`) is a `PregoAnchorMenu(flat: true)` with one `PregoMenuItem` per computer.
    `PregoMenuItem` supports `isEnabled` and `isDestructive`. Callers:
    - phone Projects (`project_list_view.dart`);
    - `computer_settings_entry.dart`, inside `bridge_settings_section.dart`;
    - the desktop `_ViewingButton` (`desktop_home_pane.dart`);
    - `other_computers_card.dart`.
  - The Settings entry is a `PregoGroupedRows` card with a `PregoAvatarUser` tile, inside a `SettingsSection`. The
    caption is `settingsSectionBridge` on phone and `desktopSettingsConnectedBridge` on desktop.
- **Client routes.**
  - Phone settings subpages are `AppRouteDef` entries (`app_routes.dart`) mapped in `app_router.dart`.
  - The desktop settings modal has tabs; the harnesses tab nests a `Navigator`, which is the pattern for a subpage.
- **Desktop bridge control.**
  - `BridgeControlCubit.stopBridge` lives in `module_desktop_core`, and the desktop shell provides it.
  - `module_app_ui` cannot depend on it, so the shell passes callbacks; `onSwitchComputer` works the same way today.
- **Reusable dialogs.**
  - `RenameSheet` with `showPregoModal`, as in `showRenameProjectDialog`.
  - `PregoSheetActions` with `PregoButtonsSolid` (destructive type), as in `_confirmDelete` in
    `session_cleanup_alerts.dart`.

## Product behavior and feel

- **Opening the page.** The page opens as a normal push on phone (Settings → menu footer, or Projects → menu
  footer) and as a nested page in the desktop Settings “Bridge” tab. From the desktop “Viewing:” header, the footer
  opens Settings on that page.
- **Row order.** The same as the menu (most recently seen first). The current computer has a check, and the desktop
  marks its own computer “This computer”.
- **“⋯” menu.** It anchors to its row and closes in place; the list never moves.
- **Removing.** A removed row collapses with the list's standard removal animation. Content above it stays still.
- **Renaming.** A renamed row updates in place, and the Projects header, menu and desktop header pick the name up
  from the shared list stream with no reload.
- **After removing the viewed computer (D3).** The phone switches to the first remaining computer, preferring an
  online one, with the normal switch transition to Projects. It reports `computer_switched` with source
  `computers_page`. The same holds on desktop when the removed computer is the remote one being viewed: the desktop
  switches to the replacement. That is “This computer” whenever it is registered, because the pick prefers an
  online computer and the local one is usually online.
- **Analytics.**
  - Switch from the page: `computer_switched` with a new `computers_page` source.
  - One new closed event, `computer_managed {action: renamed | removed}`, answers whether people use management.
    It carries no names or ids.
- **Error copy.**
  - A failed rename or remove shows a short error alert and leaves the row unchanged.
  - A 404 on remove counts as success (already removed elsewhere).

## Ownership and contracts

### Auth server (`sesori_auth_server`)

- **Document.** Optional `nickname` in `bridgeSchema` (`models/documents.ts`): a string of 1–120 characters after
  trim, absent when unset. Absence is meaningful, so there is no backfill. Registration never writes it.
- **Rename chain.**
  - `renameBridgeBodySchema` in `models/api.ts`: `{nickname: string | null}`, trimmed; an empty string or `null`
    clears it.
  - The route is `PATCH /auth/bridges/:bridgeId` in `routes/bridges.ts`, which reuses `bridgeIdPathParamSchema` and
    the zod `safeParse` → `BadRequestError` pattern from `routes/settings/settings.ts`.
  - It calls `BridgeService.renameForUser`, which calls `BridgeRepository.setNicknameForUser`: a `findOneAndUpdate`
    on `{bridgeId, userId, revokedAt: null}` with `$set`/`$unset`.
  - A null result becomes `NotFoundError`. The route returns the updated summary.
- **One display-name owner.** `bridge-service.ts` defines `displayName(bridge)` as `nickname ?? name`.
  - `toSummary` returns `name: displayName(bridge)` and a new `hostname: name`. Every summary response gets both:
    `GET /auth/bridges`, `/auth/me`, and the `POST /auth/bridges` registration response.
  - `RecordBridgeStatusResult` returns the raw `name` plus `nickname: string | null`. `recordStatusReport` passes
    `bridgeName: displayName(...)` to the state tracker, so the push titles use the nickname. The repository applies
    no naming rule.
- **Accepted.** A rename inside the offline debounce keeps the old name in that one push, as in multi-computer
  step 4.

### Client (`sesori_shared`, `module_core`, `module_app_ui`, `app`, `desktop`)

- **`sesori_shared`.** `BridgeSummary` gains required `hostname`. The auth step deploys first: the server deploys on
  merge, so a released app never meets a server without it. The bridge also parses `BridgeSummary` from the
  registration response (`bridge/app/lib/src/auth/auth_api.dart`). It reads only `id`, so its behavior is
  unchanged, but its test fixtures (`test/helpers/test_helpers.dart`, `test/integration/supervised_e2e_test.dart`)
  gain `hostname`.
- **API and repository.** `BridgeApi` and `BridgeRepository` gain `renameBridge({bridgeId, nickname})`, which
  returns the updated summary.
- **`RegisteredBridgesService` owns the list after a mutation.**
  - `rename` replaces the entry with the returned summary.
  - `remove` calls `deleteBridge` and drops the entry.
  - Both re-publish `bridges`, with no new state beyond the existing list.
  - After a success, both log `computer_managed` through `ProductAnalyticsService`, the same way
    `SelectedComputerService` logs switches.
- **`SelectedComputerService` owns the replacement pick.**
  `String? replacementAfterRemoving({required String bridgeId})` returns the first other computer in the published
  list (most recently seen first), preferring an online one, or null when none remains.
- **`ComputerSwitcherCubit` stays the single owner of the list, the current computer and this computer.**
  `ComputerSwitcherState` gains pure getters:
  - `isThisComputer(id)`: `id == localId`.
  - `canRemove(id)`: offline and not `localId`.
  These rules hold on every surface: the phone has no local id, and the desktop's own computer is the local id (D4).
  The Computers page reuses the provided `ComputerSwitcherCubit` for its rows.
- **`ComputersCubit` (`module_core`, Layer 4) holds only the actions.**
  - `rename` and `remove`, with their in-flight and error state, call `RegisteredBridgesService`.
  - When the removed id was the current target, `remove` returns `SelectedComputerService.replacementAfterRemoving`.
  - It does not switch computers.
- **`ComputersView` (`module_app_ui`).**
  - Rows, the “⋯” `PregoAnchorMenu` (a desktop secondary click opens the same menu), the rename `RenameSheet` modal,
    the remove confirmation and the D4 info modal.
  - It takes `required ComputerSwitchCallback onSwitchComputer` from each shell, as every other switch entry point
    does. It uses that callback for Switch with source `computersPage`, and for the D3 replacement that `remove`
    returns. The desktop shell closes the settings modal before dispatching, as `desktop_settings_modal.dart`
    already does.
  - It takes one `required WidgetBuilder? localBridgeTurnOffActionBuilder` for the D4 button. The desktop builds it
    with `BlocBuilder<BridgeControlCubit, BridgeControlState>`: “Turn off bridge” wired to `stopBridge`, nothing
    while the bridge is off. The phone passes null.
- **`ComputerMenu`.** Gains a required nullable `onManageComputers`; a non-null value renders the footer. Projects,
  Settings and the desktop header pass it; `other_computers_card.dart` passes null.
- **Routes.**
  - Phone: `AppRouteDef.settingsComputers`, the `AppRoute.settingsComputers()` factory and its
    `AppRouteSettingsComputers` mapping in `app_router.dart`, as a settings child. From Projects, the footer pushes
    settings then computers, so Back returns to Settings.
  - Desktop: the “Bridge” settings tab gets a nested `Navigator` like the harnesses tab. A dedicated
    `showDesktopComputersSettings` opener shows the modal on the Bridge tab with the Computers page pushed, so the page
    can't pair with another tab. `desktop_router` passes `onManageComputers` into the “Viewing:” header the way it
    passes `onOpenBridgeSettings`.

## Compatibility

- The client↔bridge wire is unchanged.
- The auth summary only adds `hostname`, in every response that carries it (list, `/auth/me`, registration). Older
  apps and bridges ignore it, and older apps show the nickname as `name`. The bridge reads only `id` from the
  registration response.
- A pre-auth-deploy server cannot occur for a released app, because the auth step lands first and deploys on merge.

## Complexity budget

- **New persistent state:** one optional `nickname` field on the auth bridge document.
- **New in-memory state:** `ComputersCubit`'s in-flight and error state for one action. Rename and remove mutate
  the existing published list, and the rows come from the existing `ComputerSwitcherCubit`.
- **Deliberately not added:**
  - undo for remove;
  - remote disconnect of an online computer (declined option, needs relay, auth and bridge work);
  - relay unpinning on remove;
  - cross-device live removal (other devices see it on their next list fetch);
  - nickname uniqueness rules;
  - a per-computer detail page.

## Cleanup

- `computer_settings_entry.dart` loses its card and tile (D8); nothing else becomes obsolete.
- `deleteBridge` gains its second caller and stays.

## Steps

Series total: 8. Titles are exact. Every implementation step updates the regression documents it affects; step 7
only reconciles.

| Step | Repository | Title |
|---|---|---|
| 1 | monorepo | 🌱 [computer-management] Publish the computer-management plan [step 1/8] |
| 2 | auth | 🌿 [computer-management] Store computer nicknames and use them in summaries and pushes [step 2/8] |
| 3 | monorepo | 🌿 [computer-management] Flatten the Settings computer entry [step 3/8] |
| 4 | monorepo | 🌿 [computer-management] Add hostname, rename, and remove to the computer list [step 4/8] |
| 5 | monorepo | ⚙️ [computer-management] Add the Computers page with switch and rename [step 5/8] |
| 6 | monorepo | ⚙️ [computer-management] Remove offline computers from the Computers page [step 6/8] |
| 7 | monorepo | 🌱 [computer-management] Reconcile regression documents [step 7/8] |
| 8 | monorepo | 🌱 [computer-management] Run the L3 matrix and retire the plan [step 8/8] |

Dependencies:
- Steps 2 and 3 are independent of each other.
- Step 4 follows 2, because its client reads `hostname`.
- Step 5 follows 4, and step 6 follows 5.
- Step 7 follows every implementation step, and step 8 comes last.

### Step 1 — Publish the plan (🌱, monorepo)

This document and `TRACKER.md`. Verification: Markdown only.

### Step 2 — Nicknames on the auth server (🌿, auth)

- **Changes.** The `nickname` document field, the rename chain, `displayName` in the service, `hostname` in every
  summary, and push titles from the display name.
- **Verification.** Repository, service and route tests:
  - set, trim, clear with `null` and with an empty string;
  - 404 for a foreign or revoked bridge;
  - a re-registration keeps the nickname;
  - the list, `/auth/me` and the `POST` registration response carry both names;
  - tracker payload titles use the nickname.

### Step 3 — Flatten the Settings computer entry (🌿, monorepo)

- **Changes.** `computer_settings_entry.dart` becomes a flat row: platform icon without a tile, name, status line and
  selector chevron, on the page background under the kept caption, on phone and desktop. It keeps opening the menu.
- **Verification.** Widget test of the tap behavior (existing test updated). Light/dark before-and-after
  screenshots on the headless iOS simulator and desktop.

### Step 4 — List data: hostname, rename, remove (🌿, monorepo)

- **Changes.**
  - `BridgeSummary.hostname` (codegen), with the bridge test fixtures updated.
  - `renameBridge` in the API and repository.
  - `RegisteredBridgesService.rename` and `remove`, which update the published list and log `computer_managed`.
  - `SelectedComputerService.replacementAfterRemoving`.
  - The `computers_page` switch source and the `computer_managed` event.
- **Verification.**
  - Codec and repository tests.
  - Service tests: rename replaces the entry, remove drops it, a failure leaves the list unchanged and logs nothing;
    the replacement pick prefers an online computer and returns null when none remains.
  - `dart test` and `dart analyze --fatal-infos` in `sesori_shared`, `module_core` and `bridge/app`.

### Step 5 — Computers page, switch and rename (⚙️, monorepo)

- **Changes.**
  - `ComputerSwitcherState.isThisComputer`, `ComputersCubit` (rename), `ComputersView` and the rows with their
    “⋯” menu (Switch, Rename…; Remove… lands in step 6).
  - The rename modal (D5).
  - Desktop secondary click.
  - The `ComputerMenu` footer (D6) and its wiring on Projects, Settings and the desktop header.
  - The phone route and the desktop nested page with `showDesktopComputersSettings`.
- **Verification.**
  - Cubit and state tests: the this-computer flag, rename success and failure.
  - Widget tests: Switch calls `onSwitchComputer` with `computersPage`.
  - Widget tests for the footer, the menu and the rename dialog.
  - Before-and-after screenshots on the headless iOS simulator and desktop.

### Step 6 — Remove (⚙️, monorepo)

- **Changes.**
  - Remove… with the online-disabled hint (D2) and confirmation (D9).
  - `ComputerSwitcherState.canRemove` and `ComputersCubit.remove`.
  - Moving off a removed current target (D3) through `onSwitchComputer`.
  - The desktop's own-row info modal (D4) with `localBridgeTurnOffActionBuilder` wired to
    `BridgeControlCubit.stopBridge`.
- **Verification.**
  - State and cubit tests: `canRemove` (offline only, never the local id), remove returning the replacement only
    for the current target, failure, and 404 as success.
  - Widget tests for the disabled item, the confirmation and the D4 modal with and without the button.
  - Simulator and desktop screenshots.

### Step 7 — Reconcile regression documents (🌱, monorepo)

Update `docs/regression/multi-computer.md` with management entries; add none elsewhere unless a step touched them.

### Step 8 — Run the L3 matrix and retire (🌱, monorepo)

Run the matrix below, record the results in `TRACKER.md`, and move the plan to `.plan/completed/computer-management/`.

## Verification and regression matrix

- Highest level: **L3 Release**.
- **Auth server.** Automated route, service and tracker tests prove nickname storage, summary names and push titles.
- **Client end to end on the headless iOS simulator.** Check that:
  - Settings → menu footer → Computers opens;
  - a rename shows on the page with the hostname under it and in the Projects header;
  - Use hostname reverts;
  - an online computer's Remove is disabled;
  - removing an offline, non-viewed computer drops it;
  - removing the viewed offline computer switches to the next one.
- **Client end to end on macOS desktop.** Check that:
  - the “Viewing:” footer opens the Computers page in Settings;
  - Remove on “This computer” shows the D4 modal;
  - “Turn off bridge” stops the bridge and the button hides once it is off.
- **Platforms.** Headless iOS simulator plus macOS desktop. Android, Windows and Linux are covered by the shared
  widgets and unit tests.
- **Plugin scope.** None (bridge-neutral).
- **Reductions.** Any reduction needs explicit user acceptance recorded here before retirement. Accepted
  (user, 2026-10-15): the plan retires on automated coverage and fixture renders. The live iOS simulator and
  macOS desktop cells are not executed; the user runs the checklist in `TRACKER.md` on the next build.

## Risks and accepted behavior

- **Removed computers return as new entries.** A removed offline computer whose bridge later starts signs in as a
  new computer, and the D9 copy says so.
- **Other devices update late.** They keep showing a removed computer until their next list fetch (connect,
  foreground, or an unknown-id notice). Acting on it there fails with 404, which counts as success, and the entry
  drops locally.
- **A phone pinned to a computer removed elsewhere stays pinned.** It shows the offline screen for an id that is no
  longer in the list, and its other-computers card offers the switch.
- **Removing the account's last computer.** The phone stays on the offline screen until a computer signs in again.
  The card then offers it.
- **Stale push name.** A rename inside the offline debounce sends one push with the old name.

## Open questions

None. D1–D9 stand until the user overrides them.
