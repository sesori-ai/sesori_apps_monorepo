# Notifications

## Capability

The bridge turns session activity into push notifications so a user away from the app learns that an agent asked a
question, requested permission, finished a turn, or that a bridge update exists. The client registers its device,
honors per-category preferences, renders foreground messages, and opens the right session on tap. Delivery through
Apple and Google is external.

## Required Behavior

- Immediate notifications exist only for question-asked, permission-asked, and installation-update events. Completion
  fires after a debounced busy-to-idle transition, is blocked while a question or permission is pending, and is
  suppressed for a user abort until the group is busy again.
- A child prompt is attributed to its display (root) session. Rate limiting is per category plus session, so a
  throttled completion never suppresses a more urgent question, and every notification for a session collapses to one
  identity derived identically by bridge, server, and client.
- A send failure is logged well enough to separate auth from transport failure and never fails the session flow that
  produced it.
- The client registers when authenticated, re-registers on token refresh, unregisters before logout, restores
  registration if logout fails, and never re-registers while logout is in flight.
- Foreground rendering needs the category enabled plus title and body; an unknown category and a preference read
  failure both default to enabled. Preferences are per account and cleared on account switch.
- A notification opened while unauthenticated defers until authentication, then routes to its session; viewing a
  session cancels its notifications.
- Payloads carry only a bounded short preview plus category, event type, and session and project identity. Full code,
  prompts, questions, permission descriptions, and assistant responses never enter a payload.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because external notification delivery is not a product heartbeat. |
| L2 Routine | Automated and headless bridge, representative plugin, fake push client: event-to-payload mapping, collapse identity, project attribution, completion debounce, pending-interaction blocking, abort suppression, per-category rate limits, maintenance step isolation. |
| L3 Release | Client end to end on the release-target client platform with a fake messaging source: registration, token refresh, logout, preference-gated foreground rendering, per-account persistence, notification-open routing including deferral, cancellation on open. |
| L4 Extended | Packaged or external on the release-target client platform: real background or terminated-app delivery, completion from another production plugin, account switch and logout isolation, a child prompt opening its root. |
| L5 Full | Both mobile platforms end to end: OS permission denied then granted, collapse and replace across repeated notifications for one session, system-update notifications, and long-run maintenance pruning under many sessions. |

## Exploration Guidance

Vary which event arrives first and how tightly events cluster, since debounce, blocking, and rate limits interact: a
question mid-turn, an abort just before idle, two sessions completing together, a child prompt on a busy root. Vary
app state, per-category preferences, and auth transitions around the tap. Use a benign session title with a real
provider, since that preview leaves the encrypted channel.

## Failure Signals

- A completion arrives while a question or permission is pending, or after abort.
- Notifications for one session do not collapse, or a tap opens the wrong session or a child instead of its root.
- A question is suppressed by an unrelated completion cooldown.
- Delivery continues after logout, or a new account receives the prior account's notifications.
- A disabled category renders in the foreground, an unknown category is dropped, or a send failure surfaces as a
  failed session action.
- A payload contains prompt text, code, paths, or a full assistant response.

## Known Limitations

- Provider delivery is external and best effort; a missing notification may be throttling or OS policy. Never record
  unobserved delivery as pass or claim a delivery rate. The preview intentionally leaves the encrypted channel.
- Fakes cannot prove background or terminated-app handling, OS permission behavior, or collapse rendering.

## Sources

`bridge/app/test/push/`, `shared/sesori_shared/test/notifications/`, `client/module_core/test/services/`,
`client/module_core/test/routing/`, `client/app/test/core/platform/`; production code under `bridge/app/lib/src/push/`
and `client/module_core/lib/src/services/`; docs/SECURITY.md carries the push disclosure.
