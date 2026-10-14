# Multi-computer support: one login, several computers

## Status and scope

- Date: 2026-10-14. Planning base: `origin/main` at `6a4a42e7a5` in the provided `brown-dingo` worktree.
- Source: [issue #947](https://github.com/sesori-ai/sesori_apps_monorepo/issues/947). One account, several computers
  (laptop, workstation, remote dev server, GPU box); the person chooses which computer the agent works on.
- Status: plan raised; implementation starts after the plan PR merges. The UX was agreed with the user on 2026-10-14
  over two review rounds (decisions D1–D16 below). The architecture plan review of 2026-10-14 rejected the first
  revision with 17 findings; all were applied in this revision (see `TRACKER.md`).
- Repositories: `sesori_relay_server` (Go, default branch `master`), `sesori_auth_server` (Node, default branch
  `master`), and this monorepo. Every PR in the series, in any repository, uses the `[multi-computer]` slug and the
  shared step numbering below.
- Vocabulary: the product says **computer** (“Computers”, “This computer”); code keeps the existing `bridge`/`bridgeId`
  names, since a computer is represented by the bridge it runs.

## Outcome

A person signs in once and runs a bridge on each computer they own. Every bridge stays connected at the same time.
The phone and the desktop app show one **active computer** at a time; the name under “Projects” opens an anchored
menu listing every computer with its online/offline state, and picking one switches the app to that computer’s
projects. The last pick survives app restarts. When the picked computer is offline, the screen says so by name and
lists the other online computers with a one-tap switch. A newly linked computer announces itself with a dismissible
alert while the app is open. Push notifications name the computer they concern and, when tapped, open the right one.
Reinstalling the bridge on a computer brings back the same entry rather than a duplicate.

Switching never stops anything: sessions keep running on the computer that hosts them; the app only views and controls.

## Decisions

Agreed with the user on 2026-10-14 (review rounds 1 and 2):

| # | Decision |
|---|---|
| D1 | One active computer per app instance; the menu shows the others with online/offline. No merged cross-computer lists. |
| D2 | Switching lives on the name under “Projects”: an anchored menu (not a sheet) whose tap area covers the subtitle row and the title above it. Items show platform icon, name, “Online” or “Offline · last seen”, and a check on the current one. A “Manage computers…” footer is added by the follow-up plan (D13), not now. |
| D3 | A switch reuses the existing project-list loading state (shimmering skeleton rows). No new “switching” state, no stale-list dimming. |
| D4 | Switching is offered on Projects, the offline screen, and Settings; after a switch the app is at the Projects root of the new computer. Deep screens never have the computer change under them. |
| D5 | Launch on the last picked computer, persisted per account on the device. No automatic jump to another computer. |
| D6 | Offline screen: heading names the computer (“dev-laptop is offline”, last seen), then an “Other computers” card with up to two online computers as one-tap switch rows and a “+ n others” row that opens the menu when more are online; “No other computers online” when none. The start-the-bridge command and the install disclosure keep their place below. |
| D7 | Desktop starts on “This computer”, can switch to a remote computer, and keeps its local bridge running; the Projects pane says which computer is being viewed. |
| D8 | Older app versions (no computer named at connect) are routed to the most recently connected computer, which is today’s newest-wins behavior. |
| D9 | Push notifications name the computer: status pushes say which computer connected or disconnected; session pushes carry the computer id, and tapping one switches to that computer before opening the session. |
| D10 | A one-time “<computer> is now linked” popup alert with a **Switch** action, only while the app is open. No handling for a closed app. |
| D11 | The phone learns about joins, connects, and disconnects from the relay: an account-wide presence notice goes to every phone of the account. This also keeps online/offline labels live. |
| D12 | Same computer after a reinstall: the bridge sends a salted hash of the operating system’s machine identifier at registration; the server reuses the account’s entry with the same key. Hostname matching was rejected (twin hostnames would collapse). |
| D13 | Computer management (remove, rename) for phone and desktop is a separate follow-up plan. The final step of this plan creates that plan and continues with it. |
| D14 | Settings: a “Computer” row at the top of the Bridge section opens the same menu now; the follow-up plan turns it into the Computers page. The Bridge section visually separates the computer entry from the settings that apply to that computer only. “Harnesses” moves from Sessions to Bridge, “Default input” moves from Sessions to Preferences, and the Sessions section is removed. |
| D15 | Approving new computers from the phone is explicitly out of scope and will be its own later effort. |
| D16 | No pairing code or QR: linking a computer stays “sign the bridge in with your account”. |

## Current behavior (evidence)

Checked against the code on 2026-10-14; relay and auth claims against each repository’s `origin/master`.

| Area | Evidence and implication |
|---|---|
| Auth registry | `sesori_auth_server` already keeps several bridges per user: `POST /auth/bridges` is idempotent on a stored `bridgeId` and otherwise mints a new `br_` id (cap 50); `GET /auth/bridges`; `DELETE /auth/bridges/:bridgeId`. `BridgeSummary` is `{id, name, addedAt, lastSeenAt, platform}`; the document also persists `status` (active/inactive) from relay reports but does not expose it. Indexes live in `src/db/mongo-db-accessor.ts`. |
| Relay slot | `AccountGroup` holds one `Bridge *Connection` and up to five phones. A second bridge displaces the first with close `4007 CloseBridgeReplaced`; phones receive only `bridge_connected` for the new bridge (`handler.go` ~271) and the displaced bridge’s cleanup skips `bridge_disconnected`. The client re-keys on a `bridge_connected` received while connected (`connection_service.dart` ~514–531). Both notices are `{type}` only, pre-marshalled. Phone→bridge frames carry a 2-byte connection id; bridge→phone connection id 0 broadcasts. The phone `auth` message already carries `bridgeId`, which the client sends as `null` and the relay ignores for phones (`messages.go` ~52, `relay_client.dart` ~211). |
| Status reporting | The relay posts `{userId, bridgeId, status, …}` to `POST /internal/bridge-status`. `BridgeService.recordStatusReport` loads the bridge document; `BridgeRepository.recordStatusChange` returns only `{found, updated, statusChanged}`. `BridgeStateTracker` debounces and sends “Bridge Online / Your bridge has reconnected.” and “Bridge Offline / Your bridge has disconnected. AI sessions are paused.” with one shared collapse key. Neither names the computer. |
| Session pushes | The bridge posts to `POST /notifications/send` with `NotificationData{category, eventType, sessionId, projectId}` (`shared/sesori_shared/.../notification_data.dart`, built by `bridge/app/lib/src/push/push_notification_content_builder.dart`). Three places gate a new field: the shared model, the auth `notificationDataSchema` (strips unknown keys), and the FCM flatten whitelist in `src/services/notification-service.ts` (~124–135). The client’s `NotificationOpenDispatcher` (`module_core/lib/src/routing/`) replaces the route stack with projects → sessions → session detail. |
| Bridge identity | `bridge/app/lib/src/auth/bridge_registration_service.dart` stores the server-issued id through `bridge_id_storage.dart` in the bridge data directory and re-sends it on every start. Losing that file creates a duplicate entry. No machine identifier exists anywhere in `bridge/`. The bridge→relay room key is re-established through resume → `rekey_required` → fresh key exchange whenever the stored key does not match (`relay_client.dart` ~222–235, ~310–316). |
| Client identity | `BridgeIdentityCubit` names the account’s most recently seen registered bridge (`firstOrNull`); `RegisteredBridgesService` caches the sorted list, clears the cache on `ConnectionConnected` (no refetch), and exposes no list stream. `ServerConnectionConfig{relayHost, authToken}` has no bridge; `relayHost` is the constant in `relay_config.dart`. `ConnectionService` is a Layer-0 capability; higher layers call `reconnect` on it. `ConnectionStatus` already has `bridgeOffline`. |
| Already per-bridge | `PluginPreferenceKey(bridgeId)`, the image cache, `NewSessionBackendScope`, `CatalogRescanService`, `PluginManagementService`, and `ActiveBridgeLocality.isLocalBridge({bridgeId})` (callers pass the id of the bridge that answered; desktop compares to the supervised bridge). |
| Not per-bridge | `ProjectInventoryService`, `RecentSessionInventoryService`, `SseEventTracker`, `McpService` cache what the current bridge said and already react to `ConnectionService.status`. `ProjectListCubit` mirrors `ProjectInventoryService.stateStream`. `SessionUnseenTracker` and `ComposerDraftRepository` are keyed by session id and may stay as they are (low damage). The Drift database has key-value tables only. |
| UI building blocks | `PregoAnchorMenu` with `PregoMenuItem`/`PregoMenuLabel`/`PregoMenuDivider` already exists (used by the onboarding “Need help?” menu). `PregoNavSubtitle` has no tap handler. `PregoPopupAlertsNotifications` supports a primary and secondary action. The project list’s loading state is already `PregoShimmer` over `ProjectTileSkeleton` rows. Unknown relay text-frame types are logged and ignored by the client. The desktop disconnected body is `DesktopBridgeRecoveryView` (`client/desktop/lib/features/home/desktop_home_pane.dart`); the phone’s is `bridge_offline_view.dart`. |
| Settings today | The shared `module_app_ui/.../settings/settings_view.dart` (~114–165) builds the sections: Account, Bridge, Sessions (Harnesses, Default input), Preferences, Appearance, Support, Legal. Harnesses and Default input keep their own routes. Desktop Settings has a Bridge tab with “Connected bridge” and “This computer”. |

## Product behavior and feel

- **Projects header.** The subtitle under “Projects” stays the single line it is today (icon, name, status dot) and
  becomes the switch control with a chevron. The whole subtitle row and the title above it are the tap target. The
  anchored menu opens below the row, lists computers most recently seen first, and dismisses on outside tap. The
  subtitle names the **target** computer in every state (loading, loaded, offline), not the most recently seen one.
- **Switch.** Tapping another computer closes the menu, pops to the Projects root, puts the list into the existing
  shimmer loading state with the new name in the header, reconnects to that computer, and fades the new list in
  exactly as a first load does. Nothing under the finger jumps; no stale rows from the previous computer are shown.
  Tapping the current computer just closes the menu.
- **Offline screen.** As D6. Rows switch on tap; the “+ n others” row opens the same menu. Pull-to-refresh keeps its
  current meaning (retry the picked computer; on desktop, start the supervised bridge only when the picked computer
  is this computer).
- **Settings.** As D14. The Bridge section opens with the computer entry (icon, name, state) in a visually distinct
  row, followed by the settings that apply to that computer. Tapping the entry opens the anchored menu.
- **Desktop.** The Projects pane header shows “Viewing: <computer> ▾” with the same menu; the Bridge settings tab
  shows the same computer entry. The “This computer” section keeps describing the local supervised bridge, which keeps
  running while a remote computer is viewed. Locality-dependent features keep calling `isLocalBridge` with the id of
  the bridge that answered, unchanged.
- **Alerts.** “<computer> is now linked” popup alert with **Switch** and a close button, on phone and desktop, shown
  when the computer list gains an id it did not have and the account already had at least one computer (the very
  first bridge arrives through onboarding, which already reacts). No sound.
- **Pushes.** “workstation is online” / “workstation went offline. AI sessions there are paused.”, one collapse key per
  computer so one computer’s status push never replaces another’s. Tapping a session push for another computer
  switches first, then opens the session through the existing route replacement.
- **Older apps.** Keep working with the new relay through D8.

## Ownership and contracts

### Relay (`sesori_relay_server`)

- `AccountGroup` replaces `Bridge *Connection` with `Bridges map[string]*Connection` keyed by `bridgeId`, plus a
  per-connection `ConnectedAt`. Phones gain a pin: `Connection.BridgeID` set from the phone `auth.bridgeId` when
  non-empty (same `^br_[A-Za-z0-9_-]{8,32}$` shape). The **default bridge** is the connected bridge with the latest
  `ConnectedAt`. A phone’s **effective target** is its pin, else the default.
- Every per-bridge interaction uses the effective target: phone→bridge frames; connection-0 broadcasts and targeted
  frames from a bridge reach only phones whose effective target is that bridge; `phone_connected`/`phone_disconnected`
  go to the phone’s effective target; `bridge_connection_observed` and `bridge_connection_notification_policy` apply to
  the effective target.
- `bridge_connected`/`bridge_disconnected` are per-bridge marshalled and carry `bridgeId` (additive). A pinned phone
  receives them for its pinned bridge only.
- Default change (a newer bridge connects, or the default disconnects and another bridge remains): for each unpinned
  phone, send `phone_disconnected` to the old default bridge, send the phone `bridge_connected{bridgeId: new}` only
  (no `bridge_disconnected`; this is today’s replacement sequence and drives the re-key in older and newer apps),
  and send `phone_connected` to the new default. When no bridge remains, unpinned phones receive `bridge_disconnected`
  as today.
- Same-id reconnect keeps `4007 CloseBridgeReplaced` for the previous connection with that id; a different id never
  displaces anyone. Bound connected bridges per account with a small constant (10) using the existing
  `4005 CloseAccountFull` path.
- New account-wide control message `bridge_presence {type, bridgeId, online}` fanned out to every phone in the group
  whenever a bridge connects or disconnects (the auth server keeps owning push debouncing). The offline notice is sent
  only when the closing connection is still the current entry for its id, the same rule that already skips
  `bridge_disconnected` for a displaced connection, so a quick same-id reconnect never reads as offline. Older apps log
  an unknown type and continue.
- Status reports to the auth server are unchanged in shape and already per `bridgeId`.
- Tests: extend `account_group_test.go`, `handler_test.go`, and `control_reports_test.go` for two bridges and two
  phones: pinning, default selection and change, presence fan-out, same-id replacement, cap, frames never crossing
  bridges, and the unpinned re-target sequence.

### Auth server (`sesori_auth_server`)

- `BridgeSummary` gains `status: "active" | "inactive"` from the persisted document field (no new state).
- `registerBridgeBodySchema` gains optional `hostKey` (64 hex characters). `registerForUser`: an id match behaves as
  today and additionally stores a supplied non-null `hostKey` (absent or null leaves the stored key unchanged, so a
  one-off failure to read the machine identifier cannot break later reinstall matching); without an id match and with a supplied non-null `hostKey`, a
  non-revoked bridge of the same user with the same `hostKey` is updated in place and returned with 200 (most recently
  seen first if duplicates exist); otherwise a new bridge is minted, with the key when one was supplied. An absent or
  null key never matches anything. Non-unique partial index `{userId, hostKey}` (only documents with a key) in
  `src/db/mongo-db-accessor.ts`; a unique index would turn the accepted cloned-image case into failed registrations.
- Status pushes name the bridge: `recordStatusChange` returns the bridge name alongside its flags, `recordStatusReport`
  passes it to the tracker’s pending entry, and the texts become “<name> is online” and “<name> went offline. AI
  sessions there are paused.” The collapse key becomes per bridge. Status-push data stays as it is (no consumer needs
  an id there).
- `notificationDataSchema` gains optional `bridgeId`, and `notification-service.ts` forwards it in the flattened FCM
  data, so session pushes can carry the computer id (step 13 fills it from the bridge).

### Bridge (`bridge/app`)

- `MachineIdApi` (sealed, `auth/machine_id_api.dart`, Layer 1) with a `forPlatform` factory: macOS `IOPlatformUUID`
  via `ioreg -rd1 -c IOPlatformExpertDevice`, Linux `/etc/machine-id` (fallback `/var/lib/dbus/machine-id`), Windows
  `MachineGuid` from `HKLM\SOFTWARE\Microsoft\Cryptography`, and an unsupported variant returning `null`. A blank
  identifier is `null`.
- `BridgeRegistrationRepository` hashes it, `sha256("sesori-bridge-host-key-v1" + id)`, and sends `hostKey` in
  `RegisterBridgeRequest` (`required String? hostKey`). The raw identifier never leaves the machine. Registration
  remains the one place that talks to the registry.
- The “another bridge took over” prompt and takeover back-off in the orchestrator remain only for the same-id case.
  Their wording is checked and narrowed; no new bridge behavior.
- The orchestrator passes the registered bridge id into the push dispatcher, which hands it to
  `PushNotificationContentBuilder` as a required input; the builder stays pure and never reads the auth subsystem.

### Client (`sesori_shared`, `module_core`, `module_app_ui`, `app`, `desktop`, `module_desktop_core`)

- **Shared models.** `BridgeSummary` gains required `BridgeRegistrationStatus status` (`active`/`inactive`; named to
  avoid the existing relay `BridgeStatus` enum) and parses `platform` into a `BridgePlatform` enum at the boundary with
  an `unknown` value for unparsed strings; both drive the D2 row. New `BridgePresenceMessage{bridgeId, online}`;
  `bridge_connected`/`bridge_disconnected` parse an optional `bridgeId`. The auth server deploys before the app ships,
  so `status` is required, not defaulted. `NotificationData` gains `required String? bridgeId` (step 13).
- **Target ownership (Layer 0).** `ConnectionService` owns the target bridge id in a `TargetBridgeStorage` beside
  `RoomKeyStorage`, backed by `StringPreferenceKey.targetBridgeId` and cleared on logout with the room key. The id is
  read into `ServerConnectionConfig.bridgeId` and sent in `auth`. `retarget({required String bridgeId})` stores the id
  and reconnects, the same way higher layers already call `reconnect`. A `bridgeId` reported by `bridge_connected` is
  adopted into storage without a reconnect when no target is stored. The connection status exposes the effective
  target id so consumers can observe a change without a second stream. The single `relayRoomKey` stays: a different
  bridge is handled by the existing resume → `rekey_required` → fresh exchange path.
- **Selection (Layer 3).** `SelectedComputerService` holds only whether the user picked another computer in this
  sign-in: `select({required String bridgeId, required ComputerSwitchSource source})` emits the analytics event and
  calls `retarget`; `ensureInitialTarget({required String? localBridgeId})` resolves stored target → the supervised
  bridge id (`ActiveBridgeLocality.localBridgeId`, a nullable getter on the existing interface; the desktop
  implementation reads the supervised bridge id, the phone returns `null`) → no pin. The registered list is
  used only to name computers, never to choose the target.
- **Resets.** The bridge-scoped caches above already react to `ConnectionService.status`; they clear when the status’s
  target id changes, in the same subscription, so no second trigger races the teardown of the old connection.
  `ProjectInventoryService` emits its loading state on that change and `ProjectListCubit` mirrors it as today.
  `BridgeIdentityCubit` names the target computer from the registered list by id, with `pending`/`unnamed` unchanged.
- **Registered list.** `RegisteredBridgesService` gains `ValueStream<List<BridgeSummary>> bridges`, applies `online`
  from `bridge_presence` locally (avoiding the race with the relay’s asynchronous status POST), and refetches only for
  unknown ids and explicit refreshes. It keeps the latest presence per id seen on the current connection and applies
  it over every fetched list, so a fetch that started before a notice, or the refetch a notice itself triggered, never
  overwrites it; the map clears when the connection is re-established.
- **Cubits (Layer 4).** `ComputerSwitcherCubit` exposes `{computers, targetId}` for the menu, the offline card, the
  Settings row, and the desktop header. `LinkedComputerAlertCubit` watches the list stream and emits a typed
  `LinkedComputerAlert{bridgeId, name}` when the list gains an id while the previous list was non-empty.
- **Navigation owner.** `ComputerSwitchDispatcher` (`module_core/lib/src/routing/`) is the single entry point for every
  switch: `switchTo({bridgeId, source})` calls `select` and then `RouteDispatcher.replaceStack` to the Projects root
  (D4). The menu, offline rows, Settings row, desktop header, and the alert’s Switch action all go through it.
  `NotificationOpenDispatcher` calls `select` when the push names another computer, then performs its existing stack
  replacement, which already starts at Projects; the session detail screen loads once the new connection is up, as
  after a cold launch.
- **UI (`module_app_ui` shared, shells thin).** `ComputerMenu` built on `PregoAnchorMenu`; `PregoNavSubtitle` gains
  an optional tap handler and chevron; the D6 offline body is built in `module_app_ui` and adopted by the phone
  `bridge_offline_view.dart` and `DesktopBridgeRecoveryView` (remote target) alike; `settings_view.dart` gains the
  computer row and the D14 hierarchy; the shells render the alert with `PregoPopupAlertsNotifications`.
- **Analytics.** One closed event `computer_switched {source: menu | offline_screen | settings | alert |
  notification, target_online: bool}` through `ProductAnalyticsService`, registered in the closed event source of
  truth and emitted by `select`. No names or ids leave the device. Load `.opencode/skills/add-analytics/SKILL.md` in
  step 8.

## Compatibility

| Contract | Older peer | Newer peer | Behavior |
|---|---|---|---|
| Phone `auth.bridgeId` | Older app sends `null` | Newer relay | D8 default (most recently connected) with the existing `bridge_connected`-only re-target sequence. |
| Updated app, older relay | — | — | Cannot occur: the relay host is a constant and the relay deploys before the app release. |
| `bridge_connected.bridgeId`, `bridge_presence` | Older app | Newer relay | Additive field ignored; unknown type logged and ignored (verified in `relay_client.dart`). |
| `POST /auth/bridges.hostKey` | Older bridge omits | Newer server | Registration behaves as today; keys backfill on the next start of an updated bridge. |
| `BridgeSummary.status` | — | Newer server deployed first | Required in the updated client; single production server. |
| Push `data.bridgeId` | Older app | Newer bridge/server | Unknown JSON key ignored by generated decoders. |
| Bridge ↔ relay | — | — | Unchanged; `4007` only for the same id. |

Deployment order: relay (steps 2–3) and auth server (step 4) before the app release that contains step 7.

## Complexity budget

New persistent or mutable parts, each justified:

- Relay: `Bridges` map (replaces one pointer), phone pin string, bridge `ConnectedAt`. No new goroutines, timers, or
  registries.
- Auth server: persisted `hostKey`; the bridge name on the tracker’s pending entry. No new services.
- Client: one persisted `targetBridgeId` (Layer 0); `ServerConnectionConfig.bridgeId`; the registered list becomes a
  stream (replacing the cached list); two cubits as UI-state owners. No new services with state, no second trigger
  stream for resets.
- Bridge: none persisted; the host key is computed at start.

Deliberately not added: aggregated multi-computer lists or parallel relay connections, an auto-switch policy, pending
approval state, per-screen switch guards (D4 makes them unnecessary), per-bridge room keys (dropped after review: the
existing re-key path covers a bridge change and secure storage cannot enumerate keys on logout), presence persistence,
closed-app join handling, hostname matching, and a nickname field (follow-up plan).

## Cleanup

- Relay: the single-slot replacement logic (`isCurrent`, `HasLiveBridgeWithID` juggling for a different id) is
  superseded by the map; keep only same-id replacement. Done inside step 2.
- Client: the “account runs one bridge at a time” rule and comments in `BridgeIdentityCubit`/`RegisteredBridgesService`
  are replaced by target naming and the list stream. Done inside steps 6–7.
- Bridge: narrow the replace-prompt wording to the same-id case in step 5.
- Settings: the Sessions section is removed in step 10; Harnesses and Default input keep their routes and move.
- Docs: `docs/regression/bridge-connectivity.md` loses “one live bridge per account holds the slot” in step 2’s
  companion doc update and step 14 reconciles.

## Steps

Series total: 15. Titles are exact; `[step x/15]` is part of each title. Every implementation step updates the
regression document(s) it affects; step 14 only reconciles.

| Step | Repository | Title |
|---|---|---|
| 1 | monorepo | 🌱 [multi-computer] Publish the multi-computer plan [step 1/15] |
| 2 | relay | 🚧 [multi-computer] Route each phone to a named bridge [step 2/15] |
| 3 | relay | ⚙️ [multi-computer] Fan out bridge presence and name bridges in connect notices [step 3/15] |
| 4 | auth | ⚙️ [multi-computer] Expose bridge status, match host keys, and name status pushes [step 4/15] |
| 5 | monorepo | 🌿 [multi-computer] Send a stable host key at bridge registration [step 5/15] |
| 6 | monorepo | 🌿 [multi-computer] Model registration status, platform, and presence in shared contracts [step 6/15] |
| 7 | monorepo | 🚧 [multi-computer] Own the target computer and reset bridge-scoped state on retarget [step 7/15] |
| 8 | monorepo | ⚙️ [multi-computer] Add the computer menu and switch flow to Projects [step 8/15] |
| 9 | monorepo | ⚙️ [multi-computer] Show other online computers on the offline screen [step 9/15] |
| 10 | monorepo | 🌿 [multi-computer] Restructure Settings around the computer entry [step 10/15] |
| 11 | monorepo | ⚙️ [multi-computer] Let the desktop view a remote computer [step 11/15] |
| 12 | monorepo | 🌿 [multi-computer] React to presence notices and announce linked computers [step 12/15] |
| 13 | monorepo | ⚙️ [multi-computer] Carry the computer id in session pushes and open the right computer [step 13/15] |
| 14 | monorepo | 🌱 [multi-computer] Reconcile regression documents [step 14/15] |
| 15 | monorepo | 🌱 [multi-computer] Run the L4 matrix, retire the plan, and open the computer-management plan [step 15/15] |

Dependencies: 2 → 3; 4 is independent; 5 after 4 (the older server silently strips the key, so order is for
behavior, not safety); 6 after 3 and 4 for the contracts it models; 7 after 2 and 6; 8, 9, 10 after 7; 11 after 8
and 9; 12 after 3 and 7; 13 after 4 and 7; 14 after every implementation step; 15 last. Steps 2–5 are invisible to
users; the relay pair (2, 3) and the auth/bridge pair (4, 5) proceed in parallel, each pair in its own order.

### Step 1 — Publish the plan (🌱, monorepo)

This document and `TRACKER.md`. Verification: Markdown only.

### Step 2 — Route each phone to a named bridge (🚧, relay)

- Files: `internal/relay/account_group.go`, `internal/relay/handler.go`, `internal/protocol/messages.go`,
  `internal/protocol/closecodes.go` (comment only), tests.
- Replace the single bridge slot with the keyed map and `ConnectedAt`; add the phone pin from `auth.bridgeId`;
  implement default-bridge resolution, default change with the `phone_disconnected` / `bridge_connected` /
  `phone_connected` sequence, and effective-target routing for every frame and notice kind; keep `4007` for same-id
  replacement; cap connected bridges with `4005`.
- Estimate: ~250 production lines, ~400 test lines. Concurrency-heavy; keep it alone in its PR.
- Verification: `go test ./...`; new tests for two bridges and two phones (pin, default, default change, same-id
  replace, cap, phone frames never cross bridges, observed/policy notices reach the effective target).
- Docs: update `docs/regression/bridge-connectivity.md` in the monorepo as part of step 6 (first monorepo client step
  after the relay lands) to describe several live bridges per account.

### Step 3 — Fan out bridge presence and name bridges in connect notices (⚙️, relay)

- Add `bridge_presence {bridgeId, online}` to every phone in the group on bridge connect/disconnect; add `bridgeId`
  to `bridge_connected`/`bridge_disconnected` (per-bridge marshalled instead of the pre-marshalled constants).
- Estimate: ~80 production lines, ~150 test lines.
- Verification: `go test ./...`; presence received by phones on other bridges and by unpinned phones; connect notices
  carry the id; no offline presence when a same-id reconnect displaces the previous connection.

### Step 4 — Expose bridge status, match host keys, and name status pushes (⚙️, auth)

- Files: `src/models/api.ts` (`BridgeSummary.status`, `hostKey`, `notificationDataSchema.bridgeId`),
  `src/models/documents.ts`, `src/db/mongo-db-accessor.ts` (index), `src/repositories/bridge-repo.ts` (host-key
  lookup, update, name on `recordStatusChange`), `src/services/bridge-service.ts` (matching rule, name pass-through),
  `src/services/bridge-state-tracker.ts` (named texts, per-bridge collapse key), `src/services/notification-service.ts`
  (forward `bridgeId`), tests.
- Estimate: ~170 production lines, ~220 test lines.
- Verification: repository/service tests for id match, host-key match, mint, duplicate pre-existing keys, named push
  texts with per-bridge collapse keys, and `bridgeId` forwarding; existing route tests.

### Step 5 — Send a stable host key at bridge registration (🌿, monorepo)

- Files: `bridge/app/lib/src/auth/machine_id_api.dart` (new, sealed), `bridge_registration_repository.dart` (hashing,
  blank → `null`), `auth_api.dart` and the request model, `bridge/app/lib/src/server/foundation/
  bridge_replace_prompt.dart` (wording), tests; `docs/regression/account-and-onboarding.md`.
- Estimate: ~120 production lines, ~120 test lines.
- Verification: `dart test` in `bridge/app` with fake process/file readers for the three platforms, blank and missing
  identifiers; analyzer with `--fatal-infos`.

### Step 6 — Model registration status, platform, and presence in shared contracts (🌿, monorepo)

- Files: `shared/sesori_shared/lib/src/protocol/messages.dart` (`bridge_presence`, optional `bridgeId` on connect
  notices), the `BridgeSummary` model (`BridgeRegistrationStatus`, `BridgePlatform`), generated code,
  `client/module_core/lib/src/services/registered_bridges_service.dart` (list stream, status), consumers of
  `platform`/`status`, tests; `docs/regression/bridge-connectivity.md`.
- Estimate: ~200 authored lines plus generated code, ~150 test lines.
- Verification: codec tests; `dart test` in `sesori_shared` and `module_core`; analyzer.

### Step 7 — Own the target computer and reset bridge-scoped state on retarget (🚧, monorepo)

- Files: `client/module_core/lib/src/foundation/persistence/persistence_keys.dart`,
  `capabilities/relay/target_bridge_storage.dart` (new, beside `room_key_storage.dart`),
  `capabilities/server_connection/server_connection_config.dart`,
  `connection_service.dart` (`retarget`, adopt, target on status), `capabilities/relay/relay_client.dart`,
  `foundation/platform/active_bridge_locality.dart` (`localBridgeId`), `client/desktop/lib/core/platform/
  desktop_active_bridge_locality.dart` and `client/app/lib/core/platform/mobile_active_bridge_locality.dart`
  (implement the getter only), `services/selected_computer_service.dart` (new),
  the four bridge-scoped caches, `cubits/bridge_identity/*`, tests; `docs/regression/client-persistence.md`.
- Estimate: ~450 production lines, ~400 test lines. Lifecycle-bearing; no UI in this PR.
- Verification: `dart test` in `module_core` (target persistence and precedence, retarget reconnects, adoption without
  reconnect, cache clearing on target change with a late event from the old connection, identity naming by id);
  analyzer.

### Step 8 — Add the computer menu and switch flow to Projects (⚙️, monorepo)

- Files: `client/module_core/lib/src/cubits/computer_switcher/*` (new), `routing/computer_switch_dispatcher.dart`
  (new), the analytics event registry, `client/module_prego/lib/components/navigation/prego_nav_subtitle.dart` (tap
  handler, chevron), `client/module_app_ui/lib/src/widgets/computer_menu.dart` (new, on `PregoAnchorMenu`),
  `features/project_list/project_list_view.dart`, `client/app/lib/features/project_list/project_list_screen.dart`,
  l10n, design catalog scenario, tests; `docs/regression/projects-and-sessions.md`, `analytics.md`.
- Estimate: ~450 lines.
- Verification: cubit and dispatcher tests (select, root reset, event source); widget tests for the menu; headless iOS
  simulator recording of a switch for the PR body (fixture names only).

### Step 9 — Show other online computers on the offline screen (⚙️, monorepo)

- Files: `client/module_app_ui/lib/src/widgets/other_computers_card.dart` (new, D6 body parts), the phone
  `bridge_offline_view.dart` and `DesktopBridgeRecoveryView` adopt it (desktop: remote target only), l10n, tests;
  `docs/regression/projects-and-sessions.md`.
- Estimate: ~280 lines.
- Verification: widget tests for zero, one, two, and many online computers; simulator screenshots before/after.

### Step 10 — Restructure Settings around the computer entry (🌿, monorepo)

- Files: `client/module_app_ui/lib/src/features/settings/settings_view.dart`, the desktop Bridge settings tab, l10n,
  tests; `docs/regression/account-and-onboarding.md` (settings sections).
- Estimate: ~200 lines. No routes change.
- Verification: widget tests for section membership; screenshots before/after on phone and desktop.

### Step 11 — Let the desktop view a remote computer (⚙️, monorepo)

- Files: the desktop projects pane header (`desktop_home_pane.dart`), `SelectedComputerService.ensureInitialTarget`
  wiring at desktop start-up (landed in step 7) plus a retarget to the local computer when the supervised bridge id
  appears or changes (fresh install, a new login, or a re-registration: the connection otherwise adopts the relay's
  default or keeps a stale id), skipped when the user has picked another computer in this sign-in, the recovery view branching (phone-style offline body for a remote target, supervised
  start only for the local one), the `desktopBridgeTakenOver` copy (“Another bridge currently owns this account
  connection.” now only happens for the same bridge id, e.g. a cloned machine), tests;
  `docs/regression/desktop-cockpit-shell.md`.
- Estimate: ~250 lines.
- Verification: `dart test` in `module_desktop_core`; desktop screenshots; manual check that the local bridge keeps
  serving a phone while the desktop views a remote computer.

### Step 12 — React to presence notices and announce linked computers (🌿, monorepo)

- Files: `relay_client.dart`/`connection_service.dart` surface `bridge_presence`; `registered_bridges_service.dart`
  applies `online` locally and refetches for unknown ids; `cubits/linked_computer_alert/*` (new); phone and desktop
  shells render `PregoPopupAlertsNotifications` with Switch through the dispatcher; tests;
  `docs/regression/popup-alerts.md`.
- Estimate: ~250 lines.
- Verification: unit tests for local status application, unknown-id refetch, and alert emission rules; simulator check
  of the alert and live menu status.

### Step 13 — Carry the computer id in session pushes and open the right computer (⚙️, monorepo)

- Files: `shared/.../notification_data.dart`, `bridge/app/lib/src/orchestrator.dart` and `push/push_dispatcher.dart`
  (inject the id), `push/push_notification_content_builder.dart` (required input),
  `client/module_core/lib/src/routing/notification_open_dispatcher.dart`, tests; `docs/regression/notifications.md`.
- Estimate: ~250 lines.
- Verification: codec tests; builder tests; dispatcher tests for same/different/absent computer; one real-device push
  check is part of the retirement matrix.

### Step 14 — Reconcile regression documents (🌱, monorepo)

Add `docs/regression/multi-computer.md` for the capability as a whole, reconcile the documents touched by steps 2–13,
and update the README index. Record `docs/HARNESS_CAPABILITIES.md` only if a harness-specific gap appears (none
expected: the feature is bridge-neutral).

### Step 15 — Run the L4 matrix, retire, and open the follow-up plan (🌱, monorepo)

Run the matrix below, record results in `TRACKER.md`, move the plan to `.plan/completed/multi-computer/`, and in the
same step create `.plan/active/computer-management/` (remove and rename computers on phone and desktop, the
“Manage computers…” menu footer, the Settings Computers page) and continue with its first step.

## Verification and regression matrix

- Highest level: **L4 Extended** (multi-client, recovery, alternate platform).
- Boundaries: Relay integration (two bridges, two phones, old-app default and re-target, presence); Client end to end
  on the release-target mobile platform (headless iOS simulator) for the menu, switch, offline screen, Settings, and
  alert; Client end to end on macOS desktop for viewing a remote computer while the local bridge serves a phone;
  Headless bridge for host-key registration and re-registration after a wiped data directory; Packaged or external for
  one real-device push naming the computer and one tap that switches computers.
- Plugin scope: Representative (bridge-neutral behavior).
- Platforms: release-target mobile platform plus macOS desktop; Linux/Windows machine identifiers proven by unit tests
  with recorded fixtures.
- Any reduction (for example no real-device push) requires explicit user acceptance recorded here before retirement.

## Later phases (rough intent only)

- **Computer management** (follow-up plan created in step 15): remove, rename (nickname that wins over the hostname),
  the menu footer, and a Settings Computers page on phone and desktop.
- **Approve new computers** from the phone before they can connect (D15); needs pending state, relay gating, and a
  recovery path for headless hosts.
- **Cross-computer views**, if ever wanted: a merged recent-sessions list across computers; explicitly not planned.

## Risks and accepted behavior

- A phone parked on an offline computer stays there until the person switches (D5); no auto-jump.
- Online/offline labels come from the auth server’s stored status plus local presence notices; a relay crash can leave
  a stale “online” until the bridge reconnects. Accepted; self-corrects.
- Cloned machine images that share a machine identifier produce the same host key: a fresh install on such a clone
  would take over another computer’s entry and the two would displace each other with `4007`. Containers without an
  identifier fall back to today’s behavior. Accepted and recorded; the follow-up plan’s Remove plus a bridge restart
  recovers it, and a dedicated escape (ignore the host key) is not planned without evidence.
- Two bridges on one computer (a CLI bridge and the desktop’s supervised bridge) would share a host key. The desktop
  supervises the same bridge binary and id storage, so this does not occur in supported setups; recorded, not guarded.
- Pre-existing duplicate entries from past reinstalls are not merged; the follow-up plan’s Remove handles them.

## Open questions

None. D1–D16 stand until the user overrides them.
