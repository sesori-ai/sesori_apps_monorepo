# Multi-computer support tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch/base: `sesori/multi-computer-plan` from `origin/main` `6a4a42e7a5`, in the provided `brown-dingo` worktree.
- Current step: complete; retired 2026-10-15 in step 15.
- User decisions: D1–D16 in `PLAN.md`, agreed 2026-10-14 over two review rounds.
- Plan PR: #1959, merged 2026-10-14.
- Architecture plan review: rejected on 2026-10-14 (17 findings); all applied in the same revision. Per `AGENTS.md`
  the applied fixes are not re-reviewed.

## Delivery

The exact titles, scope, estimates, and dependency order are in `PLAN.md`.

| Step | Repository | Outcome | State | PR/evidence |
|---|---|---|---|---|
| 1/15 | monorepo | Publish reviewed plan | Done | #1959 (merged 2026-10-14) |
| 2/15 | relay | Phones routed to a named bridge | Done | sesori_relay_server#12 (merged 2026-10-14) |
| 3/15 | relay | Presence fan-out; ids in connect notices | Done | sesori_relay_server#13 (merged 2026-10-14) |
| 4/15 | auth | Status in summaries; host-key matching; named status pushes | Done | sesori_auth_server#95 (merged 2026-10-14) |
| 5/15 | monorepo | Bridge sends a stable host key | Done | #1961 (merged 2026-10-14) |
| 6/15 | monorepo | Shared contracts: registration status, platform, presence; list stream | Done | #1963 (merged 2026-10-14) |
| 7/15 | monorepo | Target owner in the connection; resets on retarget | Done | #1965 (merged 2026-10-14) |
| 8/15 | monorepo | Computer menu, switch dispatcher, and flow on Projects | Done | #1967 (merged 2026-10-14) |
| 9/15 | monorepo | Offline screen lists other online computers (shared body) | Done | #1968 (merged 2026-10-14) |
| 10/15 | monorepo | Settings restructured around the computer entry | Done | #1970 (merged 2026-10-14) |
| 11/15 | monorepo | Desktop views a remote computer | Done | #1972 (merged 2026-10-14) |
| 12/15 | monorepo | Presence handling and linked-computer alert | Done | #1973 (merged 2026-10-14) |
| 13/15 | monorepo | Computer id in session pushes; tap opens the right computer | Done | #1974 (merged 2026-10-14) |
| 14/15 | monorepo | Reconcile regression documents | Done | #1975 (merged 2026-10-14) |
| 15/15 | monorepo | Record the L4 outcome; retire; start the computer-management UX review | Done | this PR |

## Evidence and decisions

- 2026-10-14: inspected the relay account group and handler, the auth bridge registry, state tracker, push
  schemas and FCM flattening, the bridge registration and id storage, the client connection/relay/identity/
  registered-bridges code, the project list and offline views on phone and desktop, the shared settings view, and
  the Prego menu/alert components. Findings are in `PLAN.md` under “Current behavior”.
- 2026-10-14: UX agreed with the user over two review rounds; no open questions remain.
- 2026-10-14, step 2: the relay caps an account at 10 connected bridges with `4005`, which the bridge treats as
  “do not reconnect”, so an eleventh computer stays offline until restarted (accepted with the plan’s reuse of the
  account-full path). Connect/disconnect notices are written outside the group lock and can reorder when two
  bridges change at the same instant; the bridge only logs `phone_connected` (accepted). A phone’s
  `bridge_connection_observed` racing a default change can be attributed to the new default (declined: worst case is
  one skipped online push to an open app).
- 2026-10-14, step 3: offline presence is sent only when the closing connection is still current and no same-id
  bridge is live; overlapping target announcements can still reorder (Codex P2, declined as the accepted step 2
  ordering window).
- 2026-10-14, step 4: the FCM `collapseKey` stays shared (`connection_status`; FCM stores at most four collapse keys
  per offline device); only the tray replacement is per computer through the Android notification tag and the APNs
  collapse id `connection_status:<bridgeId>`. A rename inside the offline debounce keeps the old name in that push
  (declined, cosmetic).
- 2026-10-14, step 5: the misleading takeover wording was the orchestrator’s `4007` console warning, not
  `bridge_replace_prompt.dart` (a local-process prompt, already correct). `MachineIdApi` has no unsupported variant
  because `PlatformOs` covers only macOS, Linux, and Windows. The desktop string `desktopBridgeTakenOver` has the same
  wording problem and moves to step 11.
- 2026-10-14, step 7: `select` arrives in step 8 with its `source` and analytics event. A fresh desktop install or a
  new login connects before the supervised bridge registers, so it adopts the relay's default computer; step 11
  retargets to the local computer when the supervised id appears or changes. A `retarget` during the very first
  connect only stores the id (adoption no longer overwrites it), so that connect still lands on the relay's pick and
  the switch takes effect on the next connect (accepted: switching is offered only once connected). Late answers
  and mutations from the previous computer are fenced by detaching its socket, which fails its pending requests
  locally (a mutation already sent may still apply on that computer, which is correct for its own state);
  a failed local read of the stored target falls back to unpinned (declined: local preference reads do not fail in
  practice).
- 2026-10-14, step 9: the shared `OtherComputersCard` lands with the phone offline screen only. The desktop
  recovery view adopts it in step 11, which owns its local/remote branching (the card belongs only to the remote
  branch, and the desktop offers no switch before step 11). An account with a single
  computer shows no card (D6's "No other computers online" applies when other computers exist but none is online).
  Picks from the "+ n others" menu report `offline_screen`, where the switch started.
- 2026-10-14, step 11: `DesktopComputerTargetOrchestrator` (module_desktop_core, Layer 4) replaces the direct
  `ensureInitialTarget` call at desktop start-up and follows the supervised bridge id when it appears or changes;
  `SelectedComputerService.select` sets the only new state, a "picked another computer" flag (set only when the
  pick is not this computer) that makes `followLocalComputer` a no-op; the orchestrator clears it on sign-out
  (`AuthUnauthenticated`, since the tracker keeps the bridge id when the server unregister fails). Accepted: a
  stored remote pick from an earlier run gives way to this computer only when the local id itself changes.
  `ActiveBridgeLocality` gained `localBridgeIdStream`, and `ComputerSwitcherState` carries `localId` and
  `viewsAnotherComputer` (a missing target counts as this computer), which both the home header and body read.
  The home header is hidden while the account's only computer is this one. The offline heading moved to the
  shared `ComputerOfflineHeading` (module_app_ui) used by the phone and the desktop remote-offline body; the
  phone's CLI command box is not reused (app-shell widgets), a line asks to start the bridge on that computer.
- 2026-10-14, step 12: presence lands as a per-computer overlay in `RegisteredBridgesService` applied over every
  fetched list and cleared on a connection drop and on logout, so the menu, offline card, Settings and desktop header
  update live and `computer_switched` reports the freshest status with no further code; a notice beats a fetch that
  started before it. An unknown id refetches the list. The alert (success, 8 s, Switch with source `alert`) skips
  the first list after launch or sign-in, status-only changes and the desktop's own computer, and names only the
  most recently seen one when several arrive. Accepted: a notice for an unknown computer while a fetch is already in
  flight joins that older fetch, so the new computer can wait for the next fetch; an offline notice does not update
  "last seen" until the next fetch.
- 2026-10-14, step 13: the bridge reads its id from `BridgeIdProvider` at send time, so a re-registration after
  revocation names the new id. A push for another computer awaits `ComputerSwitchDispatcher.switchTo` (Projects root,
  then `select`, whose retarget detaches the old socket and moves the status to reconnecting) and only then replaces
  the stack with the session, so the session screen starts on the new computer's connection and waits for it. The id
  travels through the phone's local-notification payload for foreground pushes. Desktop attention alerts carry no id
  and open on the viewed computer (accepted: low damage, the desktop open path is separate).
- 2026-10-15, step 15: the user answered the retirement questions on a review page. Relay #12/#13 and auth #95
  are live (both servers deploy on merge). The follow-up starts with a UX review page; the
  `.plan/active/computer-management/` plan is written only after the user agrees its designs, so this step does not
  create it.

## Retirement matrix

Accepted reduction (user, 2026-10-15): the plan retires on automated coverage. Unit, widget and integration suites for
every step passed in CI, and the relay and auth suites passed in their repositories. The live L4 cells below were not
executed; the user runs them on the next build, and any failure becomes an ordinary bug PR.

| Boundary | Cell | State |
|---|---|---|
| Relay integration | Two bridges and two phones on one account; each phone stays on its pick | Accepted, not executed |
| Relay integration | An old app lands on the latest connected computer; a new app re-targets | Accepted, not executed |
| Client, iOS simulator | Menu lists both computers with status; Switch lands on Projects of the other one | Accepted, not executed |
| Client, iOS simulator | Stopping a computer shows the offline screen listing the other online one | Accepted, not executed |
| Client, iOS simulator | Settings names the current computer; linking a third shows “is now linked” | Accepted, not executed |
| Client, macOS desktop | Desktop views a remote computer while its own bridge keeps serving a phone | Accepted, not executed |
| Headless bridge | Wiping the data directory and restarting reuses the same computer entry | Accepted, not executed |
| Packaged | A real-device push names the computer; tapping it switches and opens the session | Accepted, not executed |

### Checklist for the next build

1. Sign in on two computers (for example laptop and workstation) with one account; both appear in the Projects
   computer menu with their status.
2. On phone A pick the laptop, on phone B pick the workstation; each keeps its pick across app restarts.
3. Switch on one phone: the screen returns to Projects of the new computer without a flash of the old one's projects.
4. Stop the bridge on the picked computer: the offline screen names it and lists the other online computer; Switch
   works from there.
5. Restart it: the menu and Settings flip back to online without a refresh.
6. Settings shows the current computer at the top and its per-computer settings beneath.
7. Link a third computer while the app is open: “<name> is now linked” appears with Switch; it does not appear on
   the next launch.
8. On the macOS desktop, view the workstation: the “Viewing:” header shows it, and phone A on the laptop keeps
   working; with the workstation off, the desktop shows the remote offline view.
9. Stop a bridge, delete its data directory, start it again: it reappears as the same computer entry, not a new one.
10. With the app in the background on a real phone, finish a session on the computer not being viewed: the push
    names that computer, and tapping it switches computers and opens the session.

## Review record

- 2026-10-14: `architecture-plan-review` rejected the first revision with 17 findings. Applied corrections:
  the connection capability owns the target id (Layer 0) and higher layers call `retarget`; the desktop local id
  reaches `module_core` through `ActiveBridgeLocality.localBridgeId`; resets key off the connection status’s target
  instead of a second stream; per-bridge room keys dropped (existing re-key path, logout cannot enumerate keys); relay
  default change uses the `bridge_connected`-only sequence with `phone_disconnected`/`phone_connected` to the bridges
  and a defined successor default; presence applies `online` locally and the registered list becomes a stream; the
  alert is a `module_core` cubit rendered by both shells; a single switch dispatcher owns select plus the Projects-root
  reset and the analytics source; the D6 body is shared in `module_app_ui`; the push builder receives the id as input;
  `MachineIdApi` sealed with blank-as-null and the cloned-image risk recorded; `BridgeRegistrationStatus` naming and a
  `BridgePlatform` enum; auth file list extended (FCM whitelist, index location, name from `recordStatusChange`,
  per-bridge collapse key, no id in status-push data); step 6 split into contracts (6) and target ownership (7); each
  step updates its own regression document; the “older relay” compatibility row corrected; settings file and
  route facts corrected. Evidence-table errors fixed: replacement sends only `bridge_connected`; the phone auth
  message already carries `bridgeId`; `recordStatusReport` lives in the service; the FCM whitelist is a third gate;
  the registered list is cleared, not refetched, on connect; settings sections live in the shared view.
