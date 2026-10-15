# Multi-Computer

## Capability

One login across several computers. A person signs in once and runs a bridge on each computer they own (laptop,
workstation, remote server); every bridge stays connected at the same time. Each phone or desktop app works on one
computer at a time, its target, and can switch to any other. Switching never stops anything: sessions keep running on
the computer that hosts them. The product says "computer"; code and wire contracts keep the `bridge`/`bridgeId`
names, since a computer is represented by the bridge it runs. This document covers the capability end to end; the
area documents linked below own the detail.

## Required Behavior

- **Target and default.** The connection owns one target computer id per device, stored as a preference and cleared
  at logout ([client persistence](client-persistence.md)). The app names it in its relay `auth`, so reconnects and
  relaunches stay on the last pick; an offline target stays the target until the person switches, with no automatic
  jump. With nothing stored, the relay serves the account's default computer, the most recently connected one, and
  the app adopts the id the relay reports without reconnecting. Older apps that name no computer get that default
  ([bridge connectivity](bridge-connectivity.md)).
- **Switch flow.** Every switch goes through one dispatcher: it replaces the route stack with the Projects root, then
  records the pick and retargets the connection, so no deeper screen ever has its computer change underneath it. The
  previous computer's socket is detached first, its late answers are dropped, and its bridge-scoped caches reset. The
  list shows the existing shimmer loading state under the new name and fades in as a first load does, with no rows
  from the previous computer. Each switch reports `computer_switched` with its `source` (`menu`, `offline_screen`,
  `settings`, `computers_page`, `alert`, `notification`) and whether the target was online, never a name or id
  ([analytics](analytics.md)). Picking the current computer in a menu only closes the menu.
- **Computer menu.** The Projects status row names the target computer, ends in a chevron, and opens an anchored
  menu listing every computer of the account, most recently seen first, with platform icon, name, online or
  last-seen state, and a check on the current one ([projects and sessions](projects-and-sessions.md)). From
  Projects, the Settings entry and the desktop header, the menu ends in "Manage computers…" after a divider, which
  closes the menu and opens the Computers page; the offline card's menu has no such footer.
- **Computers page.** Lists every computer in menu order: platform icon, name, the hostname under a name of the
  user's own, presence, a check on the current one, and "This computer" on the desktop's own. Each row's "⋯" (or a
  desktop secondary click on the row) opens Switch, absent on the current computer, Rename… and Remove…. Switch goes
  through the dispatcher with source `computers_page`; on desktop the Settings window closes first. Rename… prefills
  the name; a blank field, exactly the hostname, or "Use hostname" (offered only under a name of the user's own)
  clears it. The row shows a spinner in place of its "⋯" while a rename or removal runs; a renamed row changes in
  place, and a failure shows a short error alert and leaves the row as it was. On the phone the page sits under
  Settings (from Projects, Settings is pushed under it, so Back lands there); on desktop it is pushed inside the
  Settings Bridge tab, with a Back button that stays in the window.
- **Removing a computer.** Only an offline computer can be removed: an online one other than this computer shows
  Remove… disabled with "Quit Sesori on <name> to remove it". Remove… asks first ("Remove <name>? It disappears
  from every device. Starting Sesori on it signs it back in as a new computer.") with Cancel and a destructive
  Remove; there is no undo. The removal revokes it on the auth server (one the server no longer knows counts as
  removed), drops it from the shared list so its row closes with the list's removal animation while the rows above
  stay still, and reports `computer_managed` with `removed` ([analytics](analytics.md)). Removing the computer the
  app works on then switches to the most recently seen other computer, preferring an online one, through the same
  dispatcher with source `computers_page`; on desktop the Settings window closes first. On desktop, Remove… on
  "This computer" removes nothing: a dialog explains that the computer in use can't be removed and that turning off
  its bridge makes it unreachable from every device, this one included, with "Turn off bridge" (the bridge's own
  off control, hidden while the bridge is off or stopping) above Close.
- **Offline view.** With the target offline, the screen names it ("<name> is offline", last seen), then an "Other
  computers" card with up to two online computers as one-tap switches, a "+ n others" row that opens the menu, or
  "No other computers online"; an account with one computer shows no card. The start command and help keep their
  place below ([projects and sessions](projects-and-sessions.md),
  [account and onboarding](account-and-onboarding.md)).
- **Settings.** The Bridge section opens with the current computer's entry, which opens the same menu; the rows
  below it apply to that computer only. The desktop Bridge tab shows the same entry and closes Settings before it
  switches ([account and onboarding](account-and-onboarding.md)).
- **Desktop.** Home shows "Viewing: <computer> ▾" with the same menu, hidden while this computer is the account's
  only one. The desktop starts on the stored pick, else on this computer once its supervised bridge id is known, and
  follows that id when it appears or changes unless the user picked another computer in this sign-in. Viewing
  another computer leaves the local bridge running and serving other apps; that computer's offline body never offers
  Start ([desktop cockpit shell](desktop-cockpit-shell.md)).
- **Presence and linking.** The relay sends every app of the account `bridge_presence {bridgeId, online}` whenever
  any of its bridges connects or disconnects. The app applies it to the computer list at once, so the menu, the
  offline card, Settings and the desktop header update live, and refetches the list for a computer it does not know.
  A notice never changes the app's own connection state ([bridge connectivity](bridge-connectivity.md)). A computer
  that newly joins the list while the app is open is announced once as "<name> is now linked" with a Switch action
  ([popup alerts](popup-alerts.md)).
- **Pushes.** Session pushes carry the id of the computer they came from; tapping one for another computer switches
  first, lands on Projects, then opens the session on that computer. A push without an id opens on the current
  computer. Connection-status pushes from the auth server name the computer ("<name> is online", "<name> went
  offline"), and one computer's status push never replaces another's in the tray ([notifications](notifications.md)).
- **Relay pinning.** The relay keeps up to 10 bridges of an account connected at once. Each app reaches only the
  bridge it names (its pin), else the default; frames, broadcasts, and phone connect notices never cross to another
  bridge. A bridge with a different id never displaces another; a reconnect with the same id replaces the previous
  connection, which closes with `4007`. When the default changes, unpinned apps receive `bridge_connected` for the
  new default and re-key. `bridge_connected` and `bridge_disconnected` name the bridge.
- **Stable identity.** Registration sends a host key, a salted SHA-256 of the operating system's machine identifier
  that never leaves the machine raw. The auth server first matches the stored bridge id, then the account's entry
  with the same host key, and only otherwise adds a computer, so a reinstall that lost its stored id brings back the
  same entry. A missing key matches nothing. The registered list carries each computer's platform and last reported
  status ([account and onboarding](account-and-onboarding.md)).

## Regression Levels

Plugin scope: Representative; one plugin supplies the projects that show which computer answered. Platforms: the
release-target client platform and macOS desktop; Linux and Windows machine identifiers are proven by unit tests.

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated, no plugin: the owning suites for the stored target in relay `auth`, adoption without reconnect, retarget, bridge-scoped cache resets, the switch dispatcher returning to Projects before it retargets, the computer list's presence overlay, the Computers page and its rename rules, and a push for another computer switching before it opens the session. |
| L2 Routine | Relay integration with two bridges and one app on one account: the app reaches only the computer it targets and its projects; with no target it reaches the most recently connected bridge; a presence notice for the other computer arrives and updates its status; a same-id restart replaces only its own connection. Headless bridge: deleting the stored bridge id and restarting registers into the same entry. |
| L3 Release | Client end to end on the release-target client platform with two computers: a switch from the menu, the offline card, Settings, and the linked-computer alert, each landing on the new computer's Projects root with no rows from the previous one; a relaunch staying on the last pick; the target stopping and starting with the offline screen and menu following live; the Computers page opened from "Manage computers…", switching from it, renaming a computer and clearing the name back to its hostname, and Back returning to Settings; Remove… disabled on an online computer, removing an offline one closing its row, and removing the viewed offline one moving to the next. macOS desktop: the "Viewing:" header, viewing the other computer while the local bridge keeps serving a phone, that computer's offline body without Start, the Computers page inside the Settings window with its in-window Back, and Remove… on "This computer" showing the explanation whose "Turn off bridge" stops the bridge and then hides. |
| L4 Extended | Relay integration with two apps pinned to different computers at once, an older app following the default and re-keying when a newer bridge connects, logout then sign-in starting without a stored target, a desktop fresh install moving to this computer once its helper registers, a relay drop during a switch, and the alternate client platform. Packaged or external: one real-device session push from the other computer opening that computer and the session, and status pushes naming each computer without replacing one another. |
| L5 Full | Store builds against the production relay and auth server; the 10-bridge cap with the eleventh refused; real Linux and Windows hosts re-registering into their entries after the bridge id file is deleted; a cloned machine image sharing a host key. Packaged or external. |

## Exploration Guidance

Vary how many computers the account has (one, two, more than three online), which are online, whether the target
is stored, local or remote, and where the switch starts. Switch while the list is loading, while a session is open,
while the target is offline, and just after a computer joins. Restart a bridge with the same id, delete its id file,
and stop the default bridge while an unpinned app is connected. On desktop, alternate between viewing this computer
and another while a phone works on the local bridge.

## Failure Signals

- An app reaching a computer other than its target, a reconnect or relaunch landing elsewhere, or one app's traffic,
  broadcasts or live events reaching a bridge or app on another computer.
- A switch leaving the previous computer's projects, sessions, activity or a pushed page on screen, the header
  keeping the old name, or a late answer from the previous computer repopulating the new one.
- A bridge with a different id displacing another, a same-id restart reading as offline to the other apps, or the
  app jumping to another computer on its own.
- The menu, offline card, Settings entry or desktop header disagreeing about which computer is current or whether
  it is online, or a presence notice changing the app's own connection state.
- A linked-computer alert at launch or sign-in, for the desktop's own computer, or for a status change.
- A tap on another computer's push opening the session on the current computer, or a push without a computer id
  switching computers.
- The desktop offering Start for another computer, stopping its local bridge while viewing another, or jumping back
  to this computer after the user picked another one.
- A reinstall on the same computer adding a duplicate entry, a raw machine identifier leaving the computer, or
  `computer_switched` carrying a computer name or id.
- Remove… removing an online computer or the desktop's own, removing without confirmation, the list jumping or
  rows above a removed one moving, a failed removal dropping the row, or the app staying on a computer it just
  removed while another remains.

## Known Limitations

- One computer at a time per app; there is no merged cross-computer list. Approving new computers from the phone is
  not part of this capability yet.
- A removed computer stays listed on the account's other devices until their next list fetch; removing it there
  again succeeds and drops it. Its bridge, once started again, signs in as a new computer. An online computer cannot be
  removed remotely.
- Online status comes from the auth server's last stored report plus the relay's presence notices. After a relay
  crash a computer can show online until its bridge reconnects, and an offline notice does not update "last seen"
  until the next fetch.
- An eleventh connected computer is refused with the account-full close, which the bridge treats as final; it stays
  offline until restarted after another computer disconnects.
- Cloned machine images share a machine identifier, so a fresh install on a clone joins the original's entry and
  the two displace each other. Hosts without a readable identifier keep one entry per install, and duplicates from
  installs before host keys existed are not merged.
- Desktop attention alerts carry no computer id and open on the computer being viewed.
- Connect and disconnect notices for two bridges changing at the same instant can reorder; a renamed computer keeps
  its old name in a status push sent within the offline debounce.

## Sources

- Client: `client/module_core/lib/src/capabilities/server_connection/connection_service.dart`,
  `capabilities/relay/target_bridge_storage.dart`, `services/selected_computer_service.dart`,
  `services/registered_bridges_service.dart`, `routing/computer_switch_dispatcher.dart`,
  `routing/notification_open_dispatcher.dart`, `cubits/computer_switcher/`, `cubits/bridge_identity/`,
  `cubits/linked_computer_alert/`, `cubits/computers/`; `client/module_app_ui/lib/src/widgets/computer_menu.dart`,
  `other_computers_card.dart`, `linked_computer_alerts.dart`, `features/settings/widgets/computer_settings_entry.dart`,
  `features/settings/computers_view.dart`; `client/desktop/lib/features/settings/desktop_settings_modal.dart`;
  `client/module_desktop_core/lib/src/orchestration/desktop_computer_target_orchestrator.dart`;
  `client/desktop/lib/features/home/desktop_home_pane.dart`; and their tests.
- Bridge: `bridge/app/lib/src/auth/machine_id_api.dart`, `bridge_registration_repository.dart`, and the push
  dispatcher and content builder with their tests.
- Shared contracts: `bridge_summary_test.dart`, `relay_notice_message_test.dart`, `notification_data_test.dart`.
- Relay (`sesori_relay_server`): `internal/relay/account_group.go`, `handler.go`, and their tests. Auth server
  (`sesori_auth_server`): `src/services/bridge-service.ts`, `src/services/bridge-state-tracker.ts`, and their tests.
- Plan: `.plan/completed/multi-computer/PLAN.md` (decisions D1–D16 and the regression matrix).
