# Multi-computer support tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch/base: `sesori/multi-computer-plan` from `origin/main` `6a4a42e7a5`, in the provided `brown-dingo` worktree.
- Current step: 5/15, PR pending.
- User decisions: D1–D16 in `PLAN.md`, agreed 2026-10-14 over two review rounds.
- Plan PR: #1959, merged 2026-10-14.
- Architecture plan review: rejected on 2026-10-14 (17 findings); all applied in the same revision. Per `AGENTS.md`
  the applied fixes are not re-reviewed.

## Delivery

The exact titles, scope, estimates, and dependency order are in `PLAN.md`.

| Step | Repository | Outcome | State | PR/evidence |
|---|---|---|---|---|
| 1/15 | monorepo | Publish reviewed plan | Done | #1959 (merged 2026-10-14) |
| 2/15 | relay | Phones routed to a named bridge | Not started | — |
| 3/15 | relay | Presence fan-out; ids in connect notices | Not started | — |
| 4/15 | auth | Status in summaries; host-key matching; named status pushes | Not started | — |
| 5/15 | monorepo | Bridge sends a stable host key | In PR | — |
| 6/15 | monorepo | Shared contracts: registration status, platform, presence; list stream | Not started | — |
| 7/15 | monorepo | Target owner in the connection; resets on retarget | Not started | — |
| 8/15 | monorepo | Computer menu, switch dispatcher, and flow on Projects | Not started | — |
| 9/15 | monorepo | Offline screen lists other online computers (shared body) | Not started | — |
| 10/15 | monorepo | Settings restructured around the computer entry | Not started | — |
| 11/15 | monorepo | Desktop views a remote computer | Not started | — |
| 12/15 | monorepo | Presence handling and linked-computer alert | Not started | — |
| 13/15 | monorepo | Computer id in session pushes; tap opens the right computer | Not started | — |
| 14/15 | monorepo | Reconcile regression documents | Not started | — |
| 15/15 | monorepo | Run L4 matrix; retire; open computer-management plan | Not started | — |

## Evidence and decisions

- 2026-10-14: inspected the relay account group and handler, the auth bridge registry, state tracker, push
  schemas and FCM flattening, the bridge registration and id storage, the client connection/relay/identity/
  registered-bridges code, the project list and offline views on phone and desktop, the shared settings view, and
  the Prego menu/alert components. Findings are in `PLAN.md` under “Current behavior”.
- 2026-10-14: UX agreed with the user over two review rounds; no open questions remain.
- No reduction of the retirement matrix has been requested or accepted.

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
